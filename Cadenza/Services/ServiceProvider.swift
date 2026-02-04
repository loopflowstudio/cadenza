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

            // Determine which user to authenticate as based on scenario
            let token = Self.tokenForScenario()
            if let tokenData = token.data(using: .utf8) {
                _ = KeychainHelper.save(key: "jwt_token", data: tokenData)
            }
        } else {
            // Use real client for production
            apiClient = APIClient.shared
        }
    }

    /// Map scenario name to user token
    private static func tokenForScenario() -> String {
        let args = ProcessInfo.processInfo.arguments

        // Find --scenario argument
        if let scenarioIndex = args.firstIndex(of: "--scenario"),
           scenarioIndex + 1 < args.count {
            let scenario = args[scenarioIndex + 1]

            switch scenario {
            case "student-starts-practice":
                return "dev_token_user_2"  // student1
            case "self-taught-creates-routine":
                return "dev_token_user_4"  // self-taught user
            default:
                return "dev_token_user_1"  // teacher (default)
            }
        }

        return "dev_token_user_1"  // teacher by default
    }

    /// Override the API client (for testing purposes)
    func setAPIClient(_ client: any APIClientProtocol) {
        self.apiClient = client
    }
}
