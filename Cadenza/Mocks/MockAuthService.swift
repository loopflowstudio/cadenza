#if DEBUG
import Foundation

@MainActor
@Observable
class MockAuthService {
    var currentUser: User?
    var isAuthenticated: Bool = false
    var errorMessage: String?

    init(user: User? = nil, isAuthenticated: Bool = false) {
        self.currentUser = user
        self.isAuthenticated = isAuthenticated
    }

    func signIn() async throws {
        // Simulate successful sign-in
        currentUser = User(
            id: 1,
            appleUserId: "test_apple_id",
            email: "test@example.com",
            fullName: "Test User",
            userType: .teacher,
            teacherId: nil,
            createdAt: Date()
        )
        isAuthenticated = true
    }

    func signOut() {
        currentUser = nil
        isAuthenticated = false
    }
}
#endif
