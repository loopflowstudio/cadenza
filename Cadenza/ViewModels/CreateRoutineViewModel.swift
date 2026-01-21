import Foundation
import Observation

@MainActor
@Observable
class CreateRoutineViewModel {
    var title = ""
    var description = ""
    var isCreating = false
    var errorMessage: String?

    private let apiClient: any APIClientProtocol

    var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }

    init(apiClient: (any APIClientProtocol)? = nil) {
        self.apiClient = apiClient ?? ServiceProvider.shared.apiClient
    }

    func createRoutine(token: String) async throws -> RoutineDTO {
        guard canCreate else {
            throw ValidationError.invalidInput
        }

        isCreating = true
        errorMessage = nil

        defer { isCreating = false }

        do {
            return try await apiClient.createRoutine(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                token: token
            )
        } catch {
            errorMessage = "Failed to create routine: \(error.localizedDescription)"
            throw error
        }
    }

    enum ValidationError: LocalizedError {
        case invalidInput

        var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Please enter a routine name"
            }
        }
    }
}
