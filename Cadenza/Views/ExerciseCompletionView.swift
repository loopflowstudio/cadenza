import SwiftUI

struct ExerciseCompletionView: View {
    let exerciseTitle: String
    let exerciseId: UUID?
    let pieceId: UUID?
    let sessionId: UUID?
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Exercise Complete")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(exerciseTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Record Video") {
                    showRecording = true
                }
                .buttonStyle(.borderedProminent)

                Button("Continue") {
                    onDone()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Nice work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onDone()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showRecording) {
                VideoRecordingSheet(
                    exerciseId: exerciseId,
                    pieceId: pieceId,
                    sessionId: sessionId
                ) { _ in
                    onDone()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ExerciseCompletionView(
        exerciseTitle: "Scale Practice",
        exerciseId: UUID(),
        pieceId: UUID(),
        sessionId: UUID()
    ) {}
}
