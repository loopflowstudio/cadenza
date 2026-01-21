import SwiftUI

#if DEBUG
struct DevSignInView: View {
    @Bindable var authService: AuthService
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App branding
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(.primary)

                Text("Cadenza")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Development Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Simple email login
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                    .padding(.horizontal, 40)

                Button {
                    Task {
                        await signIn()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .disabled(email.isEmpty || isLoading)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            // Quick fill suggestions
            VStack(spacing: 8) {
                Text("Quick Fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    quickFillButton("teacher@example.com")
                    quickFillButton("student1@example.com")
                    quickFillButton("student2@example.com")
                }
            }
            .padding(.top, 16)

            Spacer()

            Text("Enter any email to bypass authentication.\nUsers are created in the real database.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Subviews

    private func quickFillButton(_ emailAddress: String) -> some View {
        Button {
            email = emailAddress
            Task {
                await signIn()
            }
        } label: {
            Text(emailAddress.components(separatedBy: "@").first ?? emailAddress)
                .font(.caption2)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func signIn() async {
        isLoading = true
        errorMessage = nil

        do {
            // Use APIClient directly for dev login (not available in protocol)
            guard let apiClient = ServiceProvider.shared.apiClient as? APIClient else {
                throw APIError.requestFailed
            }
            let authResponse = try await apiClient.devLogin(email: email)

            // Store token in keychain
            if let tokenData = authResponse.accessToken.data(using: String.Encoding.utf8) {
                _ = KeychainHelper.save(key: "jwt_token", data: tokenData)
            }

            // Update auth service
            authService.currentUser = authResponse.user
            authService.isAuthenticated = true
        } catch {
            errorMessage = "Failed to sign in: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

#Preview {
    DevSignInView(authService: AuthService())
}
#endif
