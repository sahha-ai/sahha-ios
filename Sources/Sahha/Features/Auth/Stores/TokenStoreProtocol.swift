import Foundation

protocol TokenStoreProtocol: Actor, Disposable {
    func saveToken(_ token: TokenResponse) throws
    func token() -> TokenResponse?
    func profileToken() -> String?
    func refreshToken() -> String?
}
