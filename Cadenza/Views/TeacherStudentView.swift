import SwiftUI

struct TeacherStudentView: View {
    @Bindable var authService: AuthService

    @State private var showingAddTeacher = false
    @State private var teacherEmail = ""
    @State private var teacher: User?
    @State private var students: [User] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            // Teacher Section (if user is a student)
            Section {
                if let teacher = teacher {
                    teacherRow(teacher)
                } else if let user = authService.currentUser, user.teacherId == nil {
                    Button("Add Teacher") {
                        showingAddTeacher = true
                    }
                }
            } header: {
                Text("My Teacher")
            }

            // Students Section (if user has students)
            if !students.isEmpty {
                Section {
                    ForEach(students) { student in
                        NavigationLink {
                            StudentDetailView(student: student, authService: authService)
                        } label: {
                            studentRow(student)
                        }
                        .accessibilityIdentifier("student-\(student.id)")
                    }
                } header: {
                    Text("My Students (\(students.count))")
                }
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
        .navigationTitle("Teacher & Students")
        .sheet(isPresented: $showingAddTeacher) {
            addTeacherSheet
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Subviews

    private func teacherRow(_ teacher: User) -> some View {
        HStack {
            VStack(alignment: .leading) {
                if let fullName = teacher.fullName {
                    Text(fullName)
                        .font(.headline)
                }
                Text(teacher.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                Task {
                    await removeTeacher()
                }
            } label: {
                Text("Remove")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }

    private func studentRow(_ student: User) -> some View {
        HStack {
            VStack(alignment: .leading) {
                if let fullName = student.fullName {
                    Text(fullName)
                        .font(.headline)
                } else {
                    Text(student.email)
                        .font(.headline)
                }
                Text(student.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var addTeacherSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Teacher's Email", text: $teacherEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter your teacher's email address")
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Teacher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddTeacher = false
                        teacherEmail = ""
                        errorMessage = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addTeacher()
                        }
                    }
                    .disabled(teacherEmail.isEmpty || isLoading)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        async let teacherTask = loadTeacher(token: token)
        async let studentsTask = loadStudents(token: token)

        _ = await (teacherTask, studentsTask)

        isLoading = false
    }

    private func loadTeacher(token: String) async {
        do {
            let apiClient = ServiceProvider.shared.apiClient
            teacher = try await apiClient.getMyTeacher(token: token)
        } catch {
            print("Failed to load teacher: \(error)")
        }
    }

    private func loadStudents(token: String) async {
        do {
            let apiClient = ServiceProvider.shared.apiClient
            students = try await apiClient.getMyStudents(token: token)
        } catch {
            print("Failed to load students: \(error)")
        }
    }

    // MARK: - Actions

    private func addTeacher() async {
        isLoading = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            teacher = try await apiClient.setTeacher(email: teacherEmail, token: token)
            showingAddTeacher = false
            teacherEmail = ""
        } catch {
            errorMessage = "Failed to add teacher: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func removeTeacher() async {
        isLoading = true
        errorMessage = nil

        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let apiClient = ServiceProvider.shared.apiClient
            try await apiClient.removeTeacher(token: token)
            teacher = nil
        } catch {
            errorMessage = "Failed to remove teacher: \(error.localizedDescription)"
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

