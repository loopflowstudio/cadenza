"""
Teacher/Student relationship behavior tests.

These tests verify the teacher-student workflow:
- Students can add one teacher
- Teachers can view their students
- Proper authorization and validation
"""


def test_student_can_add_teacher_by_email(authenticated_client):
    """Student can set a teacher using their email address"""
    # Create teacher
    teacher_client, teacher_data = authenticated_client(
        user_id="teacher_123", email="teacher@example.com"
    )

    # Create student
    student_client, student_data = authenticated_client(
        user_id="student_123", email="student@example.com"
    )
    student_token = student_data["access_token"]

    # Student sets teacher
    response = student_client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["teacher"]["email"] == "teacher@example.com"


def test_student_can_only_have_one_teacher(authenticated_client):
    """Setting a new teacher replaces the previous one"""
    # Create two teachers
    _, teacher1_data = authenticated_client(user_id="t1", email="teacher1@example.com")
    _, teacher2_data = authenticated_client(user_id="t2", email="teacher2@example.com")

    # Create student
    client, student_data = authenticated_client(
        user_id="s1", email="student@example.com"
    )
    token = student_data["access_token"]

    # Set first teacher
    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher1@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )

    # Set second teacher (should replace first)
    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher2@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )

    # Verify current teacher
    response = client.get(
        "/users/my-teacher", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    assert response.json()["email"] == "teacher2@example.com", (
        "Should only have one teacher (the most recent one)"
    )


def test_teacher_can_see_their_students(authenticated_client):
    """Teacher can view list of students who added them"""
    # Create teacher
    client, teacher_data = authenticated_client(
        user_id="t1", email="teacher@example.com"
    )
    teacher_token = teacher_data["access_token"]

    # Create students who add this teacher
    for i in range(3):
        _, student_data = authenticated_client(
            user_id=f"student_{i}", email=f"student{i}@example.com"
        )
        client.post(
            "/users/set-teacher",
            params={"teacher_email": "teacher@example.com"},
            headers={"Authorization": f"Bearer {student_data['access_token']}"},
        )

    # Teacher gets student list
    response = client.get(
        "/users/my-students", headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 200
    students = response.json()
    assert len(students) == 3, "Teacher should see all 3 students"
    student_emails = {s["email"] for s in students}
    assert "student0@example.com" in student_emails
    assert "student1@example.com" in student_emails
    assert "student2@example.com" in student_emails


def test_student_can_remove_their_teacher(authenticated_client):
    """Student can remove their teacher relationship"""
    # Setup teacher and student
    _, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    client, student_data = authenticated_client(
        user_id="s1", email="student@example.com"
    )
    token = student_data["access_token"]

    # Set teacher
    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )

    # Remove teacher
    response = client.delete(
        "/users/remove-teacher", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200

    # Verify no teacher
    response = client.get(
        "/users/my-teacher", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.json() is None, "Should have no teacher after removal"


def test_cannot_set_self_as_teacher(authenticated_client):
    """User cannot set themselves as their own teacher"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    response = client.post(
        "/users/set-teacher",
        params={"teacher_email": "user@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 400
    assert "yourself" in response.json()["detail"].lower()


def test_can_set_unregistered_teacher(authenticated_client):
    """Setting a teacher email that doesn't exist creates a stub user"""
    client, student_data = authenticated_client(email="student@example.com")
    token = student_data["access_token"]

    response = client.post(
        "/users/set-teacher",
        params={"teacher_email": "nonexistent@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    teacher = response.json()["teacher"]
    assert teacher["email"] == "nonexistent@example.com"
    assert teacher["apple_user_id"] is None, "Should be a stub user without Apple ID"
