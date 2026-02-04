import SwiftUI
import SwiftData

@main
struct CadenzaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Piece.self,
            Routine.self,
            Exercise.self,
            RoutineAssignment.self,
            PracticeSession.self,
            ExerciseSession.self
        ])
    }
}
