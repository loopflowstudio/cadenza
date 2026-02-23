import SwiftUI
import PDFKit

struct PracticeSessionView: View {
    let routine: RoutineDTO
    @Bindable var authService: AuthService

    @State private var pieces: [PieceDTO] = []
    @State private var currentExerciseIndex = 0
    @State private var showTimer = true
    @State private var showTuner = false
    @State private var showMetronome = false
    @State private var showReflections = false
    @State private var reflectionText = ""
    @State private var isLoadingPieces = true
    @State private var currentSession: PracticeSessionDTO?
    @State private var exerciseStartTime: Date = Date()
    @State private var showExerciseCompletion = false
    @State private var completedExercise: ExerciseDTO?
    @State private var completedPieceId: UUID?
    @State private var completedSessionId: UUID?
    @State private var pendingFinish = false

    @Environment(\.dismiss) private var dismiss

    private var exercises: [ExerciseDTO] {
        routine.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var currentExercise: ExerciseDTO? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var currentPiece: PieceDTO? {
        guard let exercise = currentExercise else { return nil }
        return pieces.first { $0.id == exercise.pieceId }
    }

    private var token: String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }

    var body: some View {
        ZStack {
            if let piece = currentPiece, let token = token {
                PDFViewer(piece: piece, token: token)
                    .ignoresSafeArea()
            } else if exercises.isEmpty {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No exercises in this routine")
                        .font(.title2)
                        .padding()
                    Text("Add exercises to your routine first")
                        .foregroundColor(.secondary)
                }
            } else {
                Color(.systemBackground)
                Text("Loading pieces...")
                    .foregroundColor(.secondary)
            }

            VStack {
                HStack(alignment: .top, spacing: 12) {
                    if showTimer {
                        PracticeTimerOverlay(recommendedTime: currentExercise?.recommendedTimeSeconds)
                            .frame(width: 220)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        if showTuner {
                            PracticeTunerOverlay()
                                .frame(width: 220)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        if showMetronome {
                            PracticeMetronomeOverlay()
                                .frame(width: 220)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
                .padding()

                Spacer()

                if let exercise = currentExercise, let intentions = exercise.intentions, !intentions.isEmpty {
                    Text(intentions)
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Exercise \(currentExerciseIndex + 1) of \(exercises.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("practice-session-done")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showTimer.toggle()
                        }
                    } label: {
                        Image(systemName: "timer")
                            .foregroundColor(showTimer ? .accentColor : .primary)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showTuner.toggle()
                        }
                    } label: {
                        Image(systemName: "tuningfork")
                            .foregroundColor(showTuner ? .accentColor : .primary)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showMetronome.toggle()
                        }
                    } label: {
                        Image(systemName: "metronome")
                            .foregroundColor(showMetronome ? .accentColor : .primary)
                    }
                }
            }

            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        if currentExerciseIndex > 0 {
                            currentExerciseIndex -= 1
                            exerciseStartTime = Date()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentExerciseIndex == 0)

                    Spacer()

                    Button("Add Reflection") {
                        showReflections = true
                    }
                    .accessibilityIdentifier("practice-session-add-reflection")

                    Spacer()

                    if currentExerciseIndex < exercises.count - 1 {
                        Button {
                            Task {
                                await completeCurrentExercise()
                                currentExerciseIndex += 1
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    } else {
                        Button("Finish") {
                            Task {
                                pendingFinish = true
                                await completeCurrentExercise()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showReflections) {
            ReflectionsSheet(text: $reflectionText) {
                showReflections = false
            }
        }
        .sheet(isPresented: $showExerciseCompletion) {
            if let completedExercise {
                ExerciseCompletionView(
                    exerciseTitle: completedExercise.intentions ?? "Exercise",
                    exerciseId: completedExercise.id,
                    pieceId: completedPieceId,
                    sessionId: completedSessionId
                ) {
                    showExerciseCompletion = false
                    if pendingFinish {
                        pendingFinish = false
                        Task {
                            await finishSession()
                        }
                    }
                }
            }
        }
        .task {
            await loadPieces()
            await startSession()
        }
    }

    // MARK: - Data Loading

    private func loadPieces() async {
        guard let token = token else {
            isLoadingPieces = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            pieces = try await apiClient.getPieces(token: token)
        } catch {
            print("Failed to load pieces: \(error)")
        }

        isLoadingPieces = false
    }

    private func startSession() async {
        guard let token = token else { return }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            currentSession = try await apiClient.startPracticeSession(routineId: routine.id, token: token)
            exerciseStartTime = Date()
        } catch {
            print("Failed to start session: \(error)")
        }
    }

    private func completeCurrentExercise() async {
        guard let token = token,
              let session = currentSession,
              let exercise = currentExercise else { return }

        let elapsed = Int(Date().timeIntervalSince(exerciseStartTime))

        do {
            let apiClient = ServiceProvider.shared.apiClient
            _ = try await apiClient.completeExerciseInSession(
                sessionId: session.id,
                exerciseId: exercise.id,
                actualTimeSeconds: elapsed,
                reflections: reflectionText.isEmpty ? nil : reflectionText,
                token: token
            )
            reflectionText = ""
            exerciseStartTime = Date()
            completedExercise = exercise
            completedPieceId = exercise.pieceId
            completedSessionId = session.id
            showExerciseCompletion = true
        } catch {
            print("Failed to complete exercise: \(error)")
        }
    }

    private func finishSession() async {
        guard let token = token,
              let session = currentSession else {
            dismiss()
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            _ = try await apiClient.completePracticeSession(sessionId: session.id, token: token)
        } catch {
            print("Failed to complete session: \(error)")
        }

        dismiss()
    }
}

// MARK: - PDF Viewer

struct PDFViewer: View {
    let piece: PieceDTO
    let token: String

    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading PDF...")
            } else if let document = pdfDocument {
                PDFKitView(document: document)
            } else {
                VStack {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text(piece.title)
                        .font(.title2)
                        .padding()
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .task {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        isLoading = true
        errorMessage = nil

        do {
            let apiClient = ServiceProvider.shared.apiClient
            let urlResponse = try await apiClient.getPieceDownloadUrl(pieceId: piece.id, token: token)

            guard let downloadURL = URL(string: urlResponse.downloadUrl) else {
                errorMessage = "Invalid download URL"
                isLoading = false
                return
            }

            let (data, _) = try await URLSession.shared.data(from: downloadURL)

            if let document = PDFDocument(data: data) {
                pdfDocument = document
            } else {
                errorMessage = "Failed to parse PDF"
            }
        } catch {
            errorMessage = "Failed to load PDF: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// MARK: - Reflections Sheet

struct ReflectionsSheet: View {
    @Binding var text: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .padding()
            }
            .navigationTitle("Reflections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }
}

#Preview {
    let routineDTO = RoutineDTO(
        id: UUID(),
        ownerId: 1,
        title: "Morning Practice",
        description: "Daily warm-up",
        createdAt: Date(),
        updatedAt: Date(),
        exercises: []
    )

    NavigationStack {
        PracticeSessionView(
            routine: routineDTO,
            authService: AuthService()
        )
    }
}
