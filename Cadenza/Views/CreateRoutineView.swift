import SwiftUI

struct CreateRoutineView: View {
    @Bindable var authService: AuthService
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreateRoutineViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Routine Name", text: $viewModel.title)
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createRoutine() }
                    }
                    .disabled(!viewModel.canCreate)
                }
            }
        }
    }

    private func createRoutine() async {
        guard let token = getToken() else {
            viewModel.errorMessage = "Not authenticated"
            return
        }

        do {
            _ = try await viewModel.createRoutine(token: token)
            onCreated()
            dismiss()
        } catch {
            // Error already set by viewModel
        }
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}
