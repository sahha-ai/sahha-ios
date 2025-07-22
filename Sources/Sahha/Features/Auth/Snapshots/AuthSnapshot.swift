final class AuthSnapshot: @unchecked Sendable {
    private var _isAuthenticated: Bool = false
    private var _profileToken: String? = nil

    var isAuthenticated: Bool {
        _isAuthenticated
    }

    var profileToken: String? {
        _profileToken
    }

    func update(isAuthenticated: Bool, profileToken: String?) {
        self._isAuthenticated = isAuthenticated
        self._profileToken = profileToken
    }

    func clear() {
        self._isAuthenticated = false
        self._profileToken = nil
    }
}
