import Foundation

/// Global service provider for dependency injection
/// Allows swapping real API client with mock for UI tests
@MainActor
class ServiceProvider {
    static let shared = ServiceProvider()

    private(set) var apiClient: any APIClientProtocol

    private init() {
        // Check if we're running UI tests with mock API
        if ProcessInfo.processInfo.arguments.contains("--mock-api") {
            // Use mock client for UI tests
            apiClient = MockAPIClientImpl.shared
            // Seed mock token so AuthService can auto-authenticate
            if let tokenData = "dev_token_user_1".data(using: .utf8) {
                _ = KeychainHelper.save(key: "jwt_token", data: tokenData)
            }
        } else {
            // Use real client for production
            apiClient = APIClient.shared
        }
    }

    /// Override the API client (for testing purposes)
    func setAPIClient(_ client: any APIClientProtocol) {
        self.apiClient = client
    }
}
