import AuthenticationServices
import Foundation

@MainActor
@Observable
class AuthService: NSObject {
    var currentUser: User?
    var isAuthenticated: Bool = false
    var errorMessage: String?

    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private let apiClient: any APIClientProtocol
    private weak var window: UIWindow?

    init(apiClient: (any APIClientProtocol)? = nil) {
        self.apiClient = apiClient ?? ServiceProvider.shared.apiClient
        super.init()
        checkStoredAuth()
    }


    func signIn() async throws {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            throw AuthError.signInFailed
        }
        self.window = window

        // Check if user has existing credentials - this uses the system keychain
        // and won't prompt for password if already signed in
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()

        // Only request scopes if this is first time sign-in
        // After first sign-in, Apple won't provide these anyway
        // Requesting them forces password re-entry
        let hasExistingAuth = KeychainHelper.load(key: "apple_user_id") != nil
        if !hasExistingAuth {
            request.requestedScopes = [.fullName, .email]
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()

        let authorization = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.signInFailed
        }

        // Store Apple user ID to track if this is a returning user
        if let userIdData = appleIDCredential.user.data(using: .utf8) {
            _ = KeychainHelper.save(key: "apple_user_id", data: userIdData)
        }

        let authResponse = try await apiClient.authenticateWithApple(idToken: tokenString)

        if let tokenData = authResponse.accessToken.data(using: .utf8) {
            _ = KeychainHelper.save(key: "jwt_token", data: tokenData)
        }

        self.currentUser = authResponse.user
        self.isAuthenticated = true
    }

    func signOut() {
        _ = KeychainHelper.delete(key: "jwt_token")
        _ = KeychainHelper.delete(key: "apple_user_id")
        currentUser = nil
        isAuthenticated = false
    }

    func checkStoredAuth() {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return
        }

        Task {
            do {
                let user = try await apiClient.getCurrentUser(token: token)
                self.currentUser = user
                self.isAuthenticated = true
            } catch {
                _ = KeychainHelper.delete(key: "jwt_token")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            guard let window = window else {
                fatalError("No window available")
            }
            return window
        }
    }
}
