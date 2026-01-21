import Foundation

/// Shared networking configuration for both real and mock API clients
/// Ensures decoding, encoding, and error handling are consistent
enum NetworkingConfig {
    /// Shared JSON decoder with consistent strategies
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Shared JSON encoder with consistent strategies
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Decode response data using shared decoder
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    /// Check HTTP response for errors and throw appropriate APIError
    static func validateHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(response.statusCode) else {
            // Could parse error body here if backend sends structured errors
            throw APIError.httpError(statusCode: response.statusCode)
        }
    }
}

/// Errors that can occur during API operations
/// Both real and mock clients should throw these
enum APIError: LocalizedError {
    case requestFailed
    case decodingFailed
    case httpError(statusCode: Int)
    case notFound
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "API request failed"
        case .decodingFailed:
            return "Failed to decode response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized"
        case .serverError(let message):
            return message
        }
    }
}
