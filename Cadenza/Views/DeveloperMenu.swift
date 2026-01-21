import SwiftUI

#if DEBUG
struct DeveloperMenu: View {
    @Bindable var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var devEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Enter any email to sign in without Apple authentication. Users are created/updated in the real database.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Developer Login")
                }

                Section {
                    TextField("Email", text: $devEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isLoading)

                    Button("Sign In") {
                        Task {
                            await signInWithEmail()
                        }
                    }
                    .disabled(devEmail.isEmpty || isLoading)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Custom Email")
                }

                Section {
                    Button("teacher@example.com") { devEmail = "teacher@example.com" }
                    Button("student1@example.com") { devEmail = "student1@example.com" }
                    Button("student2@example.com") { devEmail = "student2@example.com" }
                } header: {
                    Text("Quick Fill")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Developer Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func signInWithEmail() async {
        isLoading = true
        errorMessage = nil

        do {
            // Use APIClient directly for dev login (not available in protocol)
            guard let apiClient = ServiceProvider.shared.apiClient as? APIClient else {
                throw APIError.requestFailed
            }
            let authResponse = try await apiClient.devLogin(email: devEmail)

            // Store token in keychain
            if let tokenData = authResponse.accessToken.data(using: String.Encoding.utf8) {
                _ = KeychainHelper.save(key: "jwt_token", data: tokenData)
            }

            // Update auth service
            authService.currentUser = authResponse.user
            authService.isAuthenticated = true

            dismiss()
        } catch {
            errorMessage = "Failed to sign in: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

#Preview {
    DeveloperMenu(authService: AuthService())
}
#endif
