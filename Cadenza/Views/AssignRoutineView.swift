import SwiftUI

struct AssignRoutineView: View {
    let student: User
    let onAssigned: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var routines: [RoutineDTO] = []
    @State private var selectedRoutine: RoutineDTO?
    @State private var isLoading = false
    @State private var isAssigning = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No Routines", systemImage: "music.note.list")
                    } description: {
                        Text("Create a routine first before assigning to students")
                    }
                } else {
                    Section("Select Routine") {
                        ForEach(routines, id: \.id) { routine in
                            Button {
                                selectedRoutine = routine
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(routine.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        if let desc = routine.description {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    if selectedRoutine?.id == routine.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                if let successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(successMessage)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Assign Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        Task { await assignRoutine() }
                    }
                    .disabled(selectedRoutine == nil || isAssigning)
                }
            }
            .task {
                await loadRoutines()
            }
        }
    }

    // MARK: - Data Operations

    private func loadRoutines() async {
        isLoading = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            routines = try await apiClient.getRoutines(token: token)
        } catch {
            errorMessage = "Failed to load routines"
        }

        isLoading = false
    }

    private func assignRoutine() async {
        guard let routine = selectedRoutine else { return }
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isAssigning = true
        errorMessage = nil

        do {
            let apiClient = ServiceProvider.shared.apiClient
            let response = try await apiClient.assignRoutineToStudent(
                studentId: student.id,
                routineId: routine.id,
                token: token
            )

            successMessage = "\(response.routine.title) assigned. \(response.piecesShared) pieces shared."
            onAssigned()

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = "Failed to assign routine: \(error.localizedDescription)"
        }

        isAssigning = false
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}
