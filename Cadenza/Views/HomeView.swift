import SwiftUI

struct HomeView: View {
    @Bindable var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    Section {
                        if let fullName = user.fullName {
                            LabeledContent("Name", value: fullName)
                        }
                        LabeledContent("Email", value: user.email)
                    } header: {
                        Text("Account")
                    }

                    Section {
                        NavigationLink {
                            RoutineListView(authService: authService)
                        } label: {
                            Label("Practice", systemImage: "play.circle")
                        }
                        .accessibilityIdentifier("nav-practice")

                        NavigationLink {
                            PiecesView(authService: authService)
                        } label: {
                            Label("Sheet Music", systemImage: "music.note.list")
                        }
                        .accessibilityIdentifier("nav-sheet-music")

                        NavigationLink {
                            TeacherStudentView(authService: authService)
                        } label: {
                            Label("Teacher & Students", systemImage: "person.2")
                        }
                        .accessibilityIdentifier("nav-teacher-students")
                    }

                    Section {
                        Button("Sign Out") {
                            authService.signOut()
                        }
                    }

                    #if DEBUG
                    Section {
                        NavigationLink {
                            DeveloperMenu(authService: authService)
                        } label: {
                            Label("Developer Menu", systemImage: "hammer.fill")
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Development")
                    } footer: {
                        Text("Switch between mock users to test teacher/student workflows")
                            .font(.caption)
                    }
                    #endif
                }
            }
            .navigationTitle("Cadenza")
        }
    }
}

#Preview {
    let authService = AuthService()
    authService.currentUser = User(
        id: 1,
        appleUserId: "test",
        email: "test@example.com",
        fullName: "Test User",
        userType: nil,
        teacherId: nil,
        createdAt: Date()
    )
    authService.isAuthenticated = true
    return HomeView(authService: authService)
}
