import SwiftUI

struct StudentDetailView: View {
    let student: User
    @Bindable var authService: AuthService

    @State private var pieces: [PieceDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSharePicker = false
    @State private var showingAssignRoutine = false

    var body: some View {
        List {
            // Student Info
            Section {
                if let fullName = student.fullName {
                    LabeledContent("Name", value: fullName)
                }
                LabeledContent("Email", value: student.email)
            } header: {
                Text("Student Info")
            }

            // Student's Pieces
            Section {
                if isLoading {
                    ProgressView()
                } else if pieces.isEmpty {
                    ContentUnavailableView {
                        Label("No Sheet Music", systemImage: "music.note")
                    } description: {
                        Text("This student hasn't added any pieces yet")
                    }
                } else {
                    ForEach(pieces, id: \.id) { piece in
                        VStack(alignment: .leading) {
                            Text(piece.title)
                                .font(.headline)
                            if let sharedFrom = piece.sharedFromPieceId {
                                Text("Shared from you")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Sheet Music (\(pieces.count))")
            }

            // Error Display
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Student Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingSharePicker = true
                    } label: {
                        Label("Share Piece", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingAssignRoutine = true
                    } label: {
                        Label("Assign Routine", systemImage: "list.bullet.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSharePicker) {
            SharePiecePicker(student: student, authService: authService, onShared: {
                Task {
                    await loadPieces()
                }
            })
        }
        .sheet(isPresented: $showingAssignRoutine) {
            AssignRoutineView(student: student) {
                // Routine assigned - could show confirmation
            }
        }
        .task {
            await loadPieces()
        }
        .refreshable {
            await loadPieces()
        }
    }

    // MARK: - Data Loading

    private func loadPieces() async {
        isLoading = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            pieces = try await apiClient.getStudentPieces(studentId: student.id, token: token)
        } catch {
            errorMessage = "Failed to load pieces: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}

