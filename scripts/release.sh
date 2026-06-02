#!/usr/bin/env bash
set -euo pipefail

VERSION=""
PRERELEASE=false
DRY_RUN=false
PUBLISH_ONLY=false

usage() {
    cat <<EOF
Usage: $0 <version> [--prerelease] [--publish-only] [--dry-run]

  <version>       Semver version, e.g. 1.4.0 or 1.4.0-beta.1
  --prerelease    Mark as prerelease and skip the production round-trip
  --publish-only  Skip bump/commit/tag/push; only lint, pod trunk push and
                  gh release for a version that is already committed and tagged
  --dry-run       Print actions without executing

Test the SDK locally with the React Native and Flutter sample apps before
running this script.

Stable release flow:
  development -> bump versions -> tag -> push -> ff-merge into production
  -> pod trunk push -> gh release -> ff-merge production back to development

Prerelease flow:
  development -> bump versions -> tag -> push -> pod trunk push -> gh release
  (production branch is left alone)

Publish-only flow (--publish-only):
  verify version + existing tag -> lint -> pod trunk push -> gh release
  (no commit, tag, push or production round-trip; the tag must already point
  at the development tip)
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prerelease) PRERELEASE=true; shift ;;
        --publish-only) PUBLISH_ONLY=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown flag: $1" >&2; usage ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
            fi
            ;;
    esac
done

[[ -z "$VERSION" ]] && usage

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "Error: '$VERSION' is not a valid semver version" >&2
    exit 1
fi

if [[ "$VERSION" == *-* ]] && [[ "$PRERELEASE" == false ]]; then
    echo "Note: '$VERSION' contains a prerelease suffix; enabling --prerelease automatically"
    PRERELEASE=true
fi

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $*"
    else
        echo "+ $*"
        "$@"
    fi
}

echo "==> Sanity checks"

for cmd in git gh pod perl; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: required command '$cmd' not found in PATH" >&2
        exit 1
    fi
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree has uncommitted changes" >&2
    git status --short
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "development" ]]; then
    echo "Error: must be on 'development' branch (currently on '$CURRENT_BRANCH')" >&2
    exit 1
fi

git fetch origin --tags

if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/development)" ]]; then
    echo "Error: local 'development' is not in sync with origin/development" >&2
    echo "       Pull or push to align before releasing." >&2
    exit 1
fi

if [[ "$PUBLISH_ONLY" == true ]]; then
    if ! git rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
        echo "Error: --publish-only requires tag '$VERSION' to exist locally" >&2
        exit 1
    fi
    if ! git ls-remote --tags origin "refs/tags/$VERSION" | grep -q "refs/tags/$VERSION"; then
        echo "Error: --publish-only requires tag '$VERSION' to exist on origin" >&2
        echo "       Push it first: git push origin $VERSION" >&2
        exit 1
    fi
    TAG_COMMIT="$(git rev-parse "refs/tags/$VERSION^{commit}")"
    if [[ "$TAG_COMMIT" != "$(git rev-parse HEAD)" ]]; then
        echo "Error: tag '$VERSION' points at $TAG_COMMIT, not the development tip $(git rev-parse HEAD)" >&2
        echo "       Move it: git tag -f $VERSION HEAD && git push origin --force $VERSION" >&2
        exit 1
    fi
else
    if git rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
        echo "Error: tag '$VERSION' already exists locally" >&2
        exit 1
    fi
    if git ls-remote --tags origin "refs/tags/$VERSION" | grep -q "refs/tags/$VERSION"; then
        echo "Error: tag '$VERSION' already exists on origin" >&2
        exit 1
    fi
fi

echo "==> Releasing version: $VERSION (prerelease: $PRERELEASE, publish-only: $PUBLISH_ONLY)"

SDK_FILE="Sources/Sahha/Core/Constants/SDK.swift"
PODSPEC_FILE="Sahha.podspec"

if [[ "$PUBLISH_ONLY" == true ]]; then
    echo "==> Verifying $SDK_FILE and $PODSPEC_FILE already declare $VERSION"
    if ! grep -q "static let version = \"$VERSION\"" "$SDK_FILE"; then
        echo "Error: $SDK_FILE does not declare version $VERSION" >&2
        echo "       --publish-only does not bump; commit the version first." >&2
        exit 1
    fi
    if ! grep -q "s.version.* = '$VERSION'" "$PODSPEC_FILE"; then
        echo "Error: $PODSPEC_FILE does not declare version $VERSION" >&2
        echo "       --publish-only does not bump; commit the version first." >&2
        exit 1
    fi
else
    echo "==> Bumping version in $SDK_FILE and $PODSPEC_FILE"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] would set version=$VERSION in $SDK_FILE and $PODSPEC_FILE"
    else
        perl -i -pe "s/static let version = \"[^\"]+\"/static let version = \"$VERSION\"/" "$SDK_FILE"
        perl -i -pe "s/s\.version(\s+)= '[^']+'/s.version\1= '$VERSION'/" "$PODSPEC_FILE"

        if ! grep -q "static let version = \"$VERSION\"" "$SDK_FILE"; then
            echo "Error: failed to update $SDK_FILE" >&2
            exit 1
        fi
        if ! grep -q "s.version.* = '$VERSION'" "$PODSPEC_FILE"; then
            echo "Error: failed to update $PODSPEC_FILE" >&2
            exit 1
        fi
    fi
fi

echo "==> Linting podspec"
run pod lib lint "$PODSPEC_FILE"

if [[ "$PUBLISH_ONLY" == false ]]; then
    echo "==> Committing version bump"
    run git add "$SDK_FILE" "$PODSPEC_FILE"
    run git commit -m "chore: release $VERSION"
    run git tag "$VERSION"
    run git push origin development
    run git push origin "$VERSION"
fi

if [[ "$PRERELEASE" == false && "$PUBLISH_ONLY" == false ]]; then
    echo "==> Fast-forwarding production to development"
    run git checkout production
    run git pull --ff-only origin production
    if [[ "$DRY_RUN" == false ]]; then
        if ! git merge --ff-only development; then
            echo "Error: cannot fast-forward 'development' into 'production'." >&2
            echo "       'production' has commits not present in 'development'." >&2
            echo "       Resolve manually before retrying." >&2
            exit 1
        fi
    else
        echo "[dry-run] git merge --ff-only development"
    fi
    run git push origin production
    run git checkout development
fi

echo "==> Publishing to CocoaPods trunk"
run pod trunk push "$PODSPEC_FILE"

echo "==> Creating GitHub release"
GH_FLAGS=(--generate-notes --title "$VERSION")
if [[ "$PRERELEASE" == true ]]; then
    GH_FLAGS+=(--prerelease)
fi
run gh release create "$VERSION" "${GH_FLAGS[@]}"

if [[ "$PRERELEASE" == false && "$PUBLISH_ONLY" == false ]]; then
    echo "==> Fast-forwarding development to production (handles any hotfixes)"
    run git pull --ff-only origin development
    if [[ "$DRY_RUN" == false ]]; then
        if ! git merge --ff-only origin/production; then
            echo "Warning: cannot fast-forward 'production' into 'development'." >&2
            echo "         The release succeeded but the back-merge needs manual resolution." >&2
            exit 1
        fi
    else
        echo "[dry-run] git merge --ff-only origin/production"
    fi
    run git push origin development
fi

echo
echo "==> Release $VERSION complete"
echo "    CocoaPods:     https://cocoapods.org/pods/Sahha"
echo "    GitHub:        https://github.com/sahha-ai/sahha-ios/releases/tag/$VERSION"
