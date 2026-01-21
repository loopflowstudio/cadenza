"""
Routine management and exercise workflow tests.

These tests verify:
- Users can create, read, update, delete their routines
- Users can add, update, reorder, and remove exercises from routines
- Proper authorization and ownership validation
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


def test_user_can_create_routine(authenticated_client):
    """User can create a new routine"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    response = client.post(
        "/routines",
        json={"title": "Morning Practice", "description": "Daily warm-up routine"},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    routine = response.json()
    assert routine["title"] == "Morning Practice"
    assert routine["description"] == "Daily warm-up routine"
    assert "id" in routine
    assert "created_at" in routine


def test_user_can_list_their_routines(authenticated_client):
    """User can retrieve all their routines"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create multiple routines
    for i in range(3):
        client.post(
            "/routines",
            json={"title": f"Routine {i}"},
            headers={"Authorization": f"Bearer {token}"}
        )

    response = client.get(
        "/routines",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    routines = response.json()
    assert len(routines) == 3


def test_user_can_get_routine_with_exercises(authenticated_client):
    """User can get a routine with its exercises"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create routine
    routine_response = client.post(
        "/routines",
        json={"title": "Practice Routine"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    # Create pieces and add as exercises
    piece1 = create_piece(client, token, "Scales", "scales.pdf").json()
    piece2 = create_piece(client, token, "Etude", "etude.pdf").json()

    client.post(
        f"/routines/{routine_id}/exercises",
        json={
            "piece_id": piece1["id"],
            "order_index": 0,
            "recommended_time_seconds": 300,
            "intentions": "Focus on even tone"
        },
        headers={"Authorization": f"Bearer {token}"}
    )

    client.post(
        f"/routines/{routine_id}/exercises",
        json={
            "piece_id": piece2["id"],
            "order_index": 1,
            "recommended_time_seconds": 600
        },
        headers={"Authorization": f"Bearer {token}"}
    )

    # Get routine with exercises
    response = client.get(
        f"/routines/{routine_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["routine"]["title"] == "Practice Routine"
    assert len(data["exercises"]) == 2
    assert data["exercises"][0]["order_index"] == 0
    assert data["exercises"][0]["intentions"] == "Focus on even tone"
    assert data["exercises"][1]["order_index"] == 1


def test_user_can_update_routine_metadata(authenticated_client):
    """User can update a routine's title and description"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    routine_response = client.post(
        "/routines",
        json={"title": "Old Title", "description": "Old description"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    response = client.put(
        f"/routines/{routine_id}",
        json={"title": "New Title", "description": "New description"},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    assert response.json()["title"] == "New Title"
    assert response.json()["description"] == "New description"


def test_user_can_delete_routine(authenticated_client):
    """User can delete a routine and its exercises"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    routine_response = client.post(
        "/routines",
        json={"title": "To Delete"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    response = client.delete(
        f"/routines/{routine_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200

    # Verify it's gone
    routines = client.get("/routines", headers={"Authorization": f"Bearer {token}"}).json()
    assert len(routines) == 0


def test_user_cannot_modify_others_routine(authenticated_client):
    """User cannot update or delete routines they don't own"""
    # Create routine as user1
    client, user1_data = authenticated_client(user_id="u1", email="user1@example.com")
    routine_response = client.post(
        "/routines",
        json={"title": "User1 Routine"},
        headers={"Authorization": f"Bearer {user1_data['access_token']}"}
    )
    routine_id = routine_response.json()["id"]

    # Try to update as user2
    _, user2_data = authenticated_client(user_id="u2", email="user2@example.com")
    response = client.put(
        f"/routines/{routine_id}",
        json={"title": "Hacked"},
        headers={"Authorization": f"Bearer {user2_data['access_token']}"}
    )

    assert response.status_code == 403


def test_user_can_add_exercises_to_routine(authenticated_client):
    """User can add exercises to their routine"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create routine and piece
    routine_response = client.post(
        "/routines",
        json={"title": "Practice Routine"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    piece = create_piece(client, token, "Bach Suite", "bach.pdf").json()

    # Add exercise
    response = client.post(
        f"/routines/{routine_id}/exercises",
        json={
            "piece_id": piece["id"],
            "order_index": 0,
            "recommended_time_seconds": 600,
            "intentions": "Work on phrasing",
            "start_page": 3
        },
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    exercise = response.json()
    assert exercise["piece_id"] == piece["id"]
    assert exercise["order_index"] == 0
    assert exercise["recommended_time_seconds"] == 600
    assert exercise["intentions"] == "Work on phrasing"
    assert exercise["start_page"] == 3


def test_user_can_update_exercise(authenticated_client):
    """User can update exercise metadata"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Setup
    routine_response = client.post(
        "/routines",
        json={"title": "Routine"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    piece = create_piece(client, token, "Piece", "piece.pdf").json()

    exercise_response = client.post(
        f"/routines/{routine_id}/exercises",
        json={"piece_id": piece["id"], "order_index": 0, "recommended_time_seconds": 300},
        headers={"Authorization": f"Bearer {token}"}
    )
    exercise_id = exercise_response.json()["id"]

    # Update exercise
    response = client.put(
        f"/routines/{routine_id}/exercises/{exercise_id}",
        json={
            "recommended_time_seconds": 600,
            "intentions": "New focus",
            "start_page": 5
        },
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    assert response.json()["recommended_time_seconds"] == 600
    assert response.json()["intentions"] == "New focus"
    assert response.json()["start_page"] == 5


def test_user_can_reorder_exercises(authenticated_client):
    """User can reorder exercises in their routine"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create routine with 3 exercises
    routine_response = client.post(
        "/routines",
        json={"title": "Routine"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    exercise_ids = []
    for i in range(3):
        piece = create_piece(client, token, f"Piece {i}", f"piece{i}.pdf").json()
        ex_response = client.post(
            f"/routines/{routine_id}/exercises",
            json={"piece_id": piece["id"], "order_index": i},
            headers={"Authorization": f"Bearer {token}"}
        )
        exercise_ids.append(ex_response.json()["id"])

    # Reorder: [0, 1, 2] -> [2, 0, 1]
    new_order = [exercise_ids[2], exercise_ids[0], exercise_ids[1]]

    response = client.put(
        f"/routines/{routine_id}/reorder",
        json={"exercise_ids": new_order},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200

    # Verify new order
    routine_data = client.get(
        f"/routines/{routine_id}",
        headers={"Authorization": f"Bearer {token}"}
    ).json()

    exercises = routine_data["exercises"]
    assert exercises[0]["id"] == exercise_ids[2]
    assert exercises[1]["id"] == exercise_ids[0]
    assert exercises[2]["id"] == exercise_ids[1]


def test_user_can_delete_exercise(authenticated_client):
    """User can remove an exercise from their routine"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Setup
    routine_response = client.post(
        "/routines",
        json={"title": "Routine"},
        headers={"Authorization": f"Bearer {token}"}
    )
    routine_id = routine_response.json()["id"]

    piece = create_piece(client, token, "Piece", "piece.pdf").json()

    exercise_response = client.post(
        f"/routines/{routine_id}/exercises",
        json={"piece_id": piece["id"], "order_index": 0},
        headers={"Authorization": f"Bearer {token}"}
    )
    exercise_id = exercise_response.json()["id"]

    # Delete exercise
    response = client.delete(
        f"/routines/{routine_id}/exercises/{exercise_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200

    # Verify it's gone
    routine_data = client.get(
        f"/routines/{routine_id}",
        headers={"Authorization": f"Bearer {token}"}
    ).json()

    assert len(routine_data["exercises"]) == 0
