import Foundation

protocol TokenStoring: Actor, Disposable {
    func saveToken(_ response: TokenResponse) async throws
    func loadToken() async throws -> TokenResponse?
    func deleteToken() async throws
    func isProfileTokenExpired() async throws -> Bool
    func profileToken() async throws -> String?
    func refreshToken() async throws -> String?
    func profileTokenExpiryDate() async throws -> Date?
}
