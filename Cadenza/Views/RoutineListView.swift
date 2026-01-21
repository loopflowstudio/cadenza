import SwiftUI

struct RoutineListView: View {
    @Bindable var authService: AuthService

    @State private var routines: [RoutineDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateRoutine = false
    @State private var selectedRoutineForPractice: RoutineDTO?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if routines.isEmpty {
                ContentUnavailableView {
                    Label("No Routines", systemImage: "music.note.list")
                } description: {
                    Text("Create a routine or ask your teacher to assign one")
                }
            } else {
                if !routines.isEmpty {
                    Section("My Routines") {
                        ForEach($routines, id: \.id) { $routine in
                            NavigationLink {
                                RoutineDetailView(
                                    authService: authService,
                                    routine: $routine,
                                    onUpdate: { Task { await loadRoutines() } }
                                )
                            } label: {
                                RoutineRowContent(
                                    title: routine.title,
                                    exerciseCount: routine.exercises.count,
                                    isAssigned: routine.assignedById != nil
                                )
                            }
                            .accessibilityIdentifier("routine-\(routine.id.uuidString)")
                            .swipeActions(edge: .trailing) {
                                Button("Practice", systemImage: "play.fill") {
                                    selectedRoutineForPractice = routine
                                }
                                .accessibilityIdentifier("practice-routine-\(routine.id.uuidString)")
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: deleteRoutine)
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
        .navigationTitle("Practice")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    PracticeCalendarView(authService: authService)
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityIdentifier("nav-calendar")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateRoutine = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateRoutine) {
            CreateRoutineView(authService: authService) {
                Task { await loadRoutines() }
            }
        }
        .fullScreenCover(item: $selectedRoutineForPractice) { routine in
            PracticeSessionView(routine: routine, authService: authService)
        }
        .task {
            await loadRoutines()
        }
        .refreshable {
            await loadRoutines()
        }
    }

    // MARK: - Data Loading

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
            errorMessage = "Failed to load routines: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func deleteRoutine(at offsets: IndexSet) {
        guard let token = getToken() else { return }

        for index in offsets {
            let routine = routines[index]
            Task {
                do {
                    let apiClient = ServiceProvider.shared.apiClient
                    try await apiClient.deleteRoutine(id: routine.id, token: token)
                    routines.remove(at: index)
                } catch {
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
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

// MARK: - Routine Row

private struct RoutineRowContent: View {
    let title: String
    let exerciseCount: Int
    let isAssigned: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAssigned {
                Image(systemName: "person.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoutineListView(authService: AuthService())
    }
}
