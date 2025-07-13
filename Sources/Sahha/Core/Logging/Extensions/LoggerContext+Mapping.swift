import Foundation

extension LoggerContext {
    var sourceString: String {
        switch self {
        case .sdk: return "sdk"
        case .api: return "api"
        }
    }

    var errorCode: Int? {
        if case let .api(code, _, _) = self { return code }
        return nil
    }

    var errorLocation: String? {
        if case let .api(_, location, _) = self { return location }
        return nil
    }

    var errorBody: String? {
        if case let .api(_, _, body) = self { return body }
        return nil
    }

    var codePath: String? {
        if case let .sdk(file, _, _, _) = self { return String(describing: file) }
        return nil
    }

    var codeMethod: String? {
        if case let .sdk(_, _, function, _) = self { return String(describing: function) }
        return nil
    }

    var codeBody: String? {
        if case let .sdk(_, _, _, body) = self { return body }
        return nil
    }
}
