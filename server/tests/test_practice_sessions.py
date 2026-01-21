"""
Practice session and exercise session tests.

These tests verify:
- Students can start and complete practice sessions
- Exercise completions are tracked with reflections
- Session duration is calculated
- Calendar data shows practice history
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


def create_routine_with_exercises(client, token, title, piece_count=2):
    """Helper to create a routine with exercises"""
    routine_response = client.post(
        "/routines",
        json={"title": title},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine = routine_response.json()

    exercises = []
    for i in range(piece_count):
        piece = create_piece(client, token, f"Piece {i}", f"piece{i}.pdf").json()
        exercise_response = client.post(
            f"/routines/{routine['id']}/exercises",
            json={
                "piece_id": piece["id"],
                "order_index": i,
                "recommended_time_seconds": 300
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        exercises.append(exercise_response.json())

    return routine, exercises


def test_student_can_start_session(authenticated_client):
    """Student can start a practice session from their routine"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, _ = create_routine_with_exercises(client, token, "My Routine")

    response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    session = response.json()
    assert session["routine_id"] == routine["id"]
    assert session["user_id"] == user_data["user"]["id"]
    assert "started_at" in session
    assert session["completed_at"] is None


def test_student_can_complete_exercise(authenticated_client):
    """Student can mark an exercise as complete with reflections"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, exercises = create_routine_with_exercises(client, token, "My Routine")

    # Start session
    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]

    # Complete first exercise
    response = client.post(
        f"/sessions/{session_id}/exercises/{exercises[0]['id']}/complete",
        json={
            "actual_time_seconds": 320,
            "reflections": "Good progress on tone quality"
        },
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    exercise_session = response.json()
    assert exercise_session["exercise_id"] == exercises[0]["id"]
    assert exercise_session["actual_time_seconds"] == 320
    assert exercise_session["reflections"] == "Good progress on tone quality"
    assert exercise_session["completed_at"] is not None


def test_student_can_complete_session(authenticated_client):
    """Student can mark entire session as complete"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, _ = create_routine_with_exercises(client, token, "My Routine")

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]

    response = client.put(
        f"/sessions/{session_id}/complete",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    session = response.json()
    assert session["completed_at"] is not None
    assert session["duration_seconds"] is not None
    assert session["duration_seconds"] >= 0


def test_session_tracks_duration(authenticated_client):
    """Session calculates duration from start to completion"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, _ = create_routine_with_exercises(client, token, "My Routine")

    # Start session
    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]
    started_at = session_response.json()["started_at"]

    # Complete session
    response = client.put(
        f"/sessions/{session_id}/complete",
        headers={"Authorization": f"Bearer {token}"}
    )

    # Duration should be calculated
    session = response.json()
    assert session["duration_seconds"] >= 0


def test_session_history_is_recorded(authenticated_client):
    """All practice sessions are recorded in history"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, _ = create_routine_with_exercises(client, token, "My Routine")

    # Create multiple sessions
    for i in range(3):
        session_response = client.post(
            "/sessions",
            params={"routine_id": routine["id"]},
            headers={"Authorization": f"Bearer {token}"}
        )
        session_id = session_response.json()["id"]
        client.put(f"/sessions/{session_id}/complete", headers={"Authorization": f"Bearer {token}"})

    # Get session history
    response = client.get(
        "/sessions",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    sessions = response.json()
    assert len(sessions) == 3


def test_exercise_session_stores_reflections(authenticated_client):
    """Student reflections are preserved in exercise sessions"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, exercises = create_routine_with_exercises(client, token, "My Routine", 3)

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]

    # Complete exercises with different reflections
    reflections = [
        "Need more work on intonation",
        "Bow control improving",
        "Tempo was consistent today"
    ]

    for i, exercise in enumerate(exercises):
        client.post(
            f"/sessions/{session_id}/exercises/{exercise['id']}/complete",
            json={"reflections": reflections[i]},
            headers={"Authorization": f"Bearer {token}"}
        )

    # Get session details
    response = client.get(
        f"/sessions/{session_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    exercise_sessions = response.json()["exercise_sessions"]
    assert len(exercise_sessions) == 3

    saved_reflections = {es["reflections"] for es in exercise_sessions}
    for reflection in reflections:
        assert reflection in saved_reflections


def test_completion_upsert_is_idempotent(authenticated_client):
    """Completing an exercise updates a single exercise session record"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, exercises = create_routine_with_exercises(client, token, "My Routine", 1)

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]
    exercise_id = exercises[0]["id"]

    first = client.post(
        f"/sessions/{session_id}/exercises/{exercise_id}/complete",
        json={"reflections": "First pass"},
        headers={"Authorization": f"Bearer {token}"}
    ).json()

    second = client.post(
        f"/sessions/{session_id}/exercises/{exercise_id}/complete",
        json={"reflections": "Second pass"},
        headers={"Authorization": f"Bearer {token}"}
    ).json()

    session_detail = client.get(
        f"/sessions/{session_id}",
        headers={"Authorization": f"Bearer {token}"}
    ).json()

    assert first["id"] == second["id"]
    assert len(session_detail["exercise_sessions"]) == 1
    assert session_detail["exercise_sessions"][0]["reflections"] == "Second pass"


def test_exercise_completion_can_be_reversed(authenticated_client):
    """Exercise completion can be toggled to incomplete"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, exercises = create_routine_with_exercises(client, token, "My Routine", 1)

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]
    exercise_id = exercises[0]["id"]

    client.post(
        f"/sessions/{session_id}/exercises/{exercise_id}/complete",
        json={"reflections": "Initial"},
        headers={"Authorization": f"Bearer {token}"}
    )

    response = client.patch(
        f"/sessions/{session_id}/exercises/{exercise_id}",
        json={"is_complete": False},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    exercise_session = response.json()
    assert exercise_session["completed_at"] is None
    assert exercise_session["reflections"] is None


def test_completions_endpoint_returns_timestamps(authenticated_client):
    """Completions endpoint returns timestamps for local bucketing"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, _ = create_routine_with_exercises(client, token, "My Routine")

    # Create and complete sessions
    for _ in range(2):
        session_response = client.post(
            "/sessions",
            params={"routine_id": routine["id"]},
            headers={"Authorization": f"Bearer {token}"}
        )
        session_id = session_response.json()["id"]
        client.put(f"/sessions/{session_id}/complete", headers={"Authorization": f"Bearer {token}"})

    # Get completions
    response = client.get(
        "/sessions/completions",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    completions = response.json()
    assert len(completions) == 2
    assert all(entry["completed_at"] is not None for entry in completions)


def test_cannot_start_session_for_others_routine(authenticated_client):
    """User cannot start session for routine they don't own"""
    # User 1 creates routine
    client, user1_data = authenticated_client(user_id="u1", email="user1@example.com")
    routine, _ = create_routine_with_exercises(client, user1_data["access_token"], "User1 Routine")

    # User 2 tries to start session
    _, user2_data = authenticated_client(user_id="u2", email="user2@example.com")

    response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {user2_data['access_token']}"}
    )

    assert response.status_code == 403


def test_cannot_complete_others_session(authenticated_client):
    """User cannot complete someone else's session"""
    # User 1 creates and starts session
    client, user1_data = authenticated_client(user_id="u1", email="user1@example.com")
    routine, _ = create_routine_with_exercises(client, user1_data["access_token"], "User1 Routine")

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {user1_data['access_token']}"}
    )
    session_id = session_response.json()["id"]

    # User 2 tries to complete it
    _, user2_data = authenticated_client(user_id="u2", email="user2@example.com")

    response = client.put(
        f"/sessions/{session_id}/complete",
        headers={"Authorization": f"Bearer {user2_data['access_token']}"}
    )

    assert response.status_code == 403


def test_get_session_with_exercise_details(authenticated_client):
    """Can retrieve full session details including all exercise sessions"""
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    routine, exercises = create_routine_with_exercises(client, token, "My Routine", 2)

    session_response = client.post(
        "/sessions",
        params={"routine_id": routine["id"]},
        headers={"Authorization": f"Bearer {token}"}
    )
    session_id = session_response.json()["id"]

    # Complete both exercises
    for exercise in exercises:
        client.post(
            f"/sessions/{session_id}/exercises/{exercise['id']}/complete",
            json={"actual_time_seconds": 300},
            headers={"Authorization": f"Bearer {token}"}
        )

    # Get session details
    response = client.get(
        f"/sessions/{session_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert "session" in data
    assert "exercise_sessions" in data
    assert len(data["exercise_sessions"]) == 2
