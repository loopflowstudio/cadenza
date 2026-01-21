import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let user: User
}

enum AuthError: LocalizedError {
    case signInFailed
    case tokenExchangeFailed
    case networkError
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Apple Sign-In failed"
        case .tokenExchangeFailed:
            return "Failed to exchange token with server"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
