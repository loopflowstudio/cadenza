"""
Routine assignment and sharing tests.

These tests verify:
- Teachers can assign routines to students
- Assignment copies the routine to student's account
- Assignment shares all referenced pieces with student
- Students can see their current assigned routine
- Only teachers can assign routines to their students
"""
import io


def create_piece(client, token, title, filename="test.pdf"):
    """Helper to create a piece with file upload"""
    pdf_content = b"%PDF-1.4 fake pdf content"
    pdf_file = io.BytesIO(pdf_content)

    response = client.post(
        "/pieces",
        data={"title": title},
        files={"pdf_file": (filename, pdf_file, "application/pdf")},
        headers={"Authorization": f"Bearer {token}"}
    )
    return response


def create_routine_with_exercises(client, token, title, piece_titles):
    """Helper to create a routine with exercises"""
    routine_response = client.post(
        "/routines",
        json={"title": title},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine = routine_response.json()

    exercises = []
    for i, piece_title in enumerate(piece_titles):
        piece = create_piece(client, token, piece_title, f"{piece_title.lower().replace(' ', '_')}.pdf").json()
        exercise_response = client.post(
            f"/routines/{routine['id']}/exercises",
            json={
                "piece_id": piece["id"],
                "order_index": i,
                "recommended_time_seconds": 300 * (i + 1),
                "intentions": f"Focus on {piece_title}"
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        exercises.append(exercise_response.json())

    return routine, exercises


def test_teacher_can_assign_routine_to_student(authenticated_client):
    """Teacher can assign a routine to their student"""
    # Setup teacher
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    # Create routine with exercises
    routine, _ = create_routine_with_exercises(
        client, teacher_token, "Weekly Practice",
        ["Scales", "Bach Prelude", "Cello Suite"]
    )

    # Setup student
    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Teacher assigns routine
    response = client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Routine assigned successfully"
    assert data["routine"]["title"] == "Weekly Practice"
    assert data["routine"]["owner_id"] == student_id
    assert data["routine"]["assigned_by_id"] == teacher_data["user"]["id"]
    assert data["routine"]["assigned_at"] is not None
    assert data["routine"]["shared_from_routine_id"] == routine["id"]
    assert data["pieces_shared"] == 3


def test_assignment_copies_routine_to_student(authenticated_client):
    """When assigned, the routine is copied to student's account"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    routine, _ = create_routine_with_exercises(
        client, teacher_token, "Original Routine", ["Scales"]
    )

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Assign
    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Verify student has their own copy of the routine
    student_routines = client.get(
        "/routines",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()

    assert len(student_routines) == 1
    assert student_routines[0]["title"] == "Original Routine"
    assert student_routines[0]["owner_id"] == student_id
    assert student_routines[0]["assigned_by_id"] == teacher_data["user"]["id"]

    # Teacher still has the original
    teacher_routines = client.get(
        "/routines",
        headers={"Authorization": f"Bearer {teacher_token}"}
    ).json()

    assert len(teacher_routines) == 1
    assert teacher_routines[0]["id"] != student_routines[0]["id"]


def test_assignment_shares_all_pieces(authenticated_client):
    """Assignment automatically shares all referenced pieces with student"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    routine, _ = create_routine_with_exercises(
        client, teacher_token, "Routine",
        ["Piece 1", "Piece 2", "Piece 3"]
    )

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Verify student has no pieces initially
    student_pieces_before = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()
    assert len(student_pieces_before) == 0

    # Assign routine
    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Verify student now has all pieces
    student_pieces_after = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()

    assert len(student_pieces_after) == 3
    titles = {p["title"] for p in student_pieces_after}
    assert "Piece 1" in titles
    assert "Piece 2" in titles
    assert "Piece 3" in titles

    # All pieces should be marked as shared
    for piece in student_pieces_after:
        assert piece["shared_from_piece_id"] is not None


def test_student_sees_current_routine(authenticated_client):
    """Student can view their currently assigned routine"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    routine, _ = create_routine_with_exercises(
        client, teacher_token, "Student Routine",
        ["Scales", "Etude"]
    )

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Assign
    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Student views current routine
    response = client.get(
        "/my-current-routine",
        headers={"Authorization": f"Bearer {student_token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["routine"]["title"] == "Student Routine"
    assert len(data["exercises"]) == 2
    assert data["assignment"]["student_id"] == student_id


def test_only_teacher_can_assign_routine(authenticated_client):
    """Only the student's teacher can assign routines"""
    # Setup non-teacher with routine
    client, other_user_data = authenticated_client(user_id="other", email="other@example.com")
    other_token = other_user_data["access_token"]

    routine_response = client.post(
        "/routines",
        json={"title": "Routine"},
        headers={"Authorization": f"Bearer {other_token}"}
    )
    routine_id = routine_response.json()["id"]

    # Setup student with different teacher
    _, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Try to assign as non-teacher
    response = client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine_id},
        headers={"Authorization": f"Bearer {other_token}"}
    )

    assert response.status_code == 403


def test_teacher_can_view_student_current_routine(authenticated_client):
    """Teacher can see their student's current routine"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    routine, _ = create_routine_with_exercises(
        client, teacher_token, "Assigned Routine", ["Scales"]
    )

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Teacher views student's routine
    response = client.get(
        f"/students/{student_id}/current-routine",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["routine"]["title"] == "Assigned Routine"


def test_new_assignment_replaces_old(authenticated_client):
    """Assigning a new routine replaces the previous assignment"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    routine1, _ = create_routine_with_exercises(
        client, teacher_token, "First Routine", ["Scales"]
    )
    routine2, _ = create_routine_with_exercises(
        client, teacher_token, "Second Routine", ["Etude"]
    )

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # First assignment
    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine1["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Second assignment
    client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine2["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Student should see second routine
    current = client.get(
        "/my-current-routine",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()

    assert current["routine"]["title"] == "Second Routine"


def test_shared_pieces_are_not_duplicated(authenticated_client):
    """If student already has a shared piece, it's not duplicated"""
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    # Create a piece and share it directly first
    piece = create_piece(client, teacher_token, "Already Shared", "shared.pdf").json()

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Manually share piece
    client.post(
        f"/pieces/{piece['id']}/share/{student_id}",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Create routine using same piece
    routine_response = client.post(
        "/routines",
        json={"title": "Routine"},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )
    routine = routine_response.json()

    client.post(
        f"/routines/{routine['id']}/exercises",
        json={"piece_id": piece["id"], "order_index": 0},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Assign routine
    response = client.post(
        f"/students/{student_id}/assign-routine",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    # Should report 0 new pieces shared (already had it)
    assert response.json()["pieces_shared"] == 0

    # Student should still have only 1 copy
    student_pieces = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()

    assert len(student_pieces) == 1
