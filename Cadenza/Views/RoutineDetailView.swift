import SwiftUI

struct RoutineDetailView: View {
    @Bindable var authService: AuthService
    @Binding var routine: RoutineDTO
    let onUpdate: () -> Void

    @State private var pieces: [PieceDTO] = []
    @State private var showingAddExercise = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Exercises") {
                if routine.exercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises", systemImage: "music.note")
                    } description: {
                        Text("Add pieces from your library to practice")
                    }
                } else {
                    ForEach(routine.exercises.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { exercise in
                        ExerciseRow(exercise: exercise, pieces: pieces)
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
        .navigationTitle(routine.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(routine: $routine, pieces: pieces) { newExercise in
                routine.exercises.append(newExercise)
                onUpdate()
            }
        }
        .task {
            await loadPieces()
        }
    }

    private func loadPieces() async {
        guard let token = getToken() else { return }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            pieces = try await apiClient.getPieces(token: token)
        } catch {
            errorMessage = "Failed to load pieces"
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

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let exercise: ExerciseDTO
    let pieces: [PieceDTO]

    private var piece: PieceDTO? {
        pieces.first { $0.id == exercise.pieceId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(piece?.title ?? "Unknown Piece")
                .font(.headline)

            HStack {
                if let time = exercise.recommendedTimeSeconds {
                    Label("\(time / 60) min", systemImage: "clock")
                        .font(.caption)
                }

                if let intentions = exercise.intentions, !intentions.isEmpty {
                    Text(intentions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Exercise View

struct AddExerciseView: View {
    @Binding var routine: RoutineDTO
    let pieces: [PieceDTO]
    let onAdded: (ExerciseDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPiece: PieceDTO?
    @State private var recommendedMinutes = 10
    @State private var intentions = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Piece") {
                    if pieces.isEmpty {
                        Text("No pieces in your library")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pieces, id: \.id) { piece in
                            Button {
                                selectedPiece = piece
                            } label: {
                                HStack {
                                    Text(piece.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedPiece?.id == piece.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Practice Time") {
                    Stepper("\(recommendedMinutes) minutes", value: $recommendedMinutes, in: 1...120)
                }

                Section("Intentions (optional)") {
                    TextField("Focus on tone quality...", text: $intentions, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addExercise() }
                    }
                    .disabled(selectedPiece == nil || isAdding)
                }
            }
        }
    }

    private func addExercise() async {
        guard let piece = selectedPiece else { return }
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isAdding = true
        errorMessage = nil

        do {
            let apiClient = ServiceProvider.shared.apiClient
            let exercise = try await apiClient.addExerciseToRoutine(
                routineId: routine.id,
                pieceId: piece.id,
                orderIndex: routine.exercises.count,
                recommendedTimeSeconds: recommendedMinutes * 60,
                intentions: intentions.isEmpty ? nil : intentions,
                startPage: nil,
                token: token
            )
            onAdded(exercise)
            dismiss()
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
        }

        isAdding = false
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}
