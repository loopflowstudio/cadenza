import SwiftUI
import SwiftData

struct SharePiecePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Piece.createdAt, order: .reverse) private var pieces: [Piece]

    let student: User
    @Bindable var authService: AuthService
    let onShared: () -> Void

    @State private var isSharing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if pieces.isEmpty {
                    ContentUnavailableView {
                        Label("No Sheet Music", systemImage: "music.note")
                    } description: {
                        Text("Add pieces to your library first to share them")
                    }
                } else {
                    ForEach(pieces) { piece in
                        Button {
                            Task {
                                await sharePiece(piece)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(piece.title)
                                        .font(.headline)
                                    if let filename = piece.pdfFilename {
                                        Text(filename)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .disabled(isSharing)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Share Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if isSharing {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func sharePiece(_ piece: Piece) async {
        isSharing = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isSharing = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            _ = try await apiClient.sharePiece(
                pieceId: piece.id,
                studentId: student.id,
                token: token
            )

            // Success - dismiss and notify parent
            dismiss()
            onShared()
        } catch {
            errorMessage = "Failed to share: \(error.localizedDescription)"
        }

        isSharing = false
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}

