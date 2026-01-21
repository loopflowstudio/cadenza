"""
Piece management and sharing behavior tests.

These tests verify the piece workflow:
- Users can create, read, update, delete their pieces
- Teachers can view student libraries
- Teachers can share pieces with students
- Proper authorization and ownership validation
"""
from uuid import uuid4
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


def test_user_can_create_piece(authenticated_client):
    """User can create a new piece with PDF upload"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    response = create_piece(client, token, "Moonlight Sonata", "moonlight.pdf")

    assert response.status_code == 200
    piece = response.json()
    assert piece["title"] == "Moonlight Sonata"
    assert piece["pdf_filename"] == "moonlight.pdf"
    assert "id" in piece
    assert "s3_key" in piece
    # Dev environment uses dev/ prefix
    assert piece["s3_key"].startswith("dev/cadenza/pieces/")


def test_user_can_list_their_pieces(authenticated_client):
    """User can retrieve all their pieces"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create multiple pieces
    for i in range(3):
        create_piece(client, token, f"Piece {i}", f"piece{i}.pdf")

    # Get all pieces
    response = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    pieces = response.json()
    assert len(pieces) == 3
    titles = {p["title"] for p in pieces}
    assert "Piece 0" in titles
    assert "Piece 1" in titles
    assert "Piece 2" in titles


def test_user_can_update_piece_title(authenticated_client):
    """User can rename their piece"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create piece
    piece_response = create_piece(client, token, "Old Title", "piece.pdf")
    piece_id = piece_response.json()["id"]

    # Update title
    response = client.put(
        f"/pieces/{piece_id}",
        params={"title": "New Title"},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    assert response.json()["title"] == "New Title"


def test_user_can_delete_their_piece(authenticated_client):
    """User can delete a piece from their library"""
    client, user_data = authenticated_client(email="user@example.com")
    token = user_data["access_token"]

    # Create piece
    piece_response = create_piece(client, token, "To Delete", "delete.pdf")
    piece_id = piece_response.json()["id"]

    # Delete piece
    response = client.delete(
        f"/pieces/{piece_id}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200

    # Verify it's gone
    pieces = client.get("/pieces", headers={"Authorization": f"Bearer {token}"}).json()
    assert len(pieces) == 0


def test_user_cannot_modify_someone_elses_piece(authenticated_client):
    """User cannot update or delete pieces they don't own"""
    # Create piece as user1
    client, user1_data = authenticated_client(user_id="u1", email="user1@example.com")
    piece_response = create_piece(client, user1_data['access_token'], "User1 Piece", "piece.pdf")
    piece_id = piece_response.json()["id"]

    # Try to update as user2
    _, user2_data = authenticated_client(user_id="u2", email="user2@example.com")
    response = client.put(
        f"/pieces/{piece_id}",
        params={"title": "Hacked"},
        headers={"Authorization": f"Bearer {user2_data['access_token']}"}
    )

    assert response.status_code == 403
    assert "not authorized" in response.json()["detail"].lower()


def test_teacher_can_view_student_library(authenticated_client):
    """Teacher can see all pieces in their student's library"""
    # Create teacher
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    # Create student and add teacher
    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Student creates pieces
    for i in range(2):
        create_piece(client, student_token, f"Student Piece {i}", f"piece{i}.pdf")

    # Teacher views student library
    response = client.get(
        f"/students/{student_id}/pieces",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 200
    pieces = response.json()
    assert len(pieces) == 2
    titles = {p["title"] for p in pieces}
    assert "Student Piece 0" in titles
    assert "Student Piece 1" in titles


def test_teacher_can_share_piece_with_student(authenticated_client):
    """Teacher can share a piece from their library to a student"""
    # Create teacher with a piece
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    teacher_piece_response = create_piece(client, teacher_token, "Bach Prelude", "bach.pdf")
    teacher_piece_id = teacher_piece_response.json()["id"]

    # Create student and set teacher
    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Teacher shares piece with student
    response = client.post(
        f"/pieces/{teacher_piece_id}/share/{student_id}",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 200
    shared_piece = response.json()
    assert shared_piece["title"] == "Bach Prelude"
    assert shared_piece["owner_id"] == student_id
    assert shared_piece["shared_from_piece_id"] == teacher_piece_id

    # Verify student now has the piece
    student_pieces = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {student_token}"}
    ).json()

    assert len(student_pieces) == 1
    assert student_pieces[0]["title"] == "Bach Prelude"


def test_shared_piece_is_independent_copy(authenticated_client):
    """Shared piece is a full copy that student can modify independently"""
    # Setup teacher and student
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    _, student_data = authenticated_client(user_id="s1", email="student@example.com")
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Teacher creates and shares piece
    teacher_piece_response = create_piece(client, teacher_token, "Original Title", "piece.pdf")
    teacher_piece_id = teacher_piece_response.json()["id"]

    share_response = client.post(
        f"/pieces/{teacher_piece_id}/share/{student_id}",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    student_piece_id = share_response.json()["id"]

    # Student modifies their copy
    client.put(
        f"/pieces/{student_piece_id}",
        params={"title": "Student's Modified Title"},
        headers={"Authorization": f"Bearer {student_token}"}
    )

    # Verify teacher's original is unchanged
    teacher_pieces = client.get(
        "/pieces",
        headers={"Authorization": f"Bearer {teacher_token}"}
    ).json()

    assert teacher_pieces[0]["title"] == "Original Title", \
        "Teacher's original should be unchanged"


def test_teacher_cannot_share_with_non_student(authenticated_client):
    """Teacher can only share with their own students"""
    # Create teacher with piece
    client, teacher_data = authenticated_client(user_id="t1", email="teacher@example.com")
    teacher_token = teacher_data["access_token"]

    piece_response = create_piece(client, teacher_token, "Piece", "piece.pdf")
    piece_id = piece_response.json()["id"]

    # Create user who is NOT this teacher's student
    _, other_user_data = authenticated_client(user_id="other", email="other@example.com")
    other_user_id = other_user_data["user"]["id"]

    # Try to share
    response = client.post(
        f"/pieces/{piece_id}/share/{other_user_id}",
        headers={"Authorization": f"Bearer {teacher_token}"}
    )

    assert response.status_code == 403
    assert "not authorized" in response.json()["detail"].lower()
