import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Bindable var authService: AuthService
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 32) {
            Text("Cadenza")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Music practice made simple")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    Task {
                        await signIn()
                    }
                }) {
                    SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                        .frame(height: 50)
                        .allowsHitTesting(false)
                }
                .frame(height: 50)
            }

            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(40)
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signIn()
        } catch {
            authService.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SignInView(authService: AuthService())
}
