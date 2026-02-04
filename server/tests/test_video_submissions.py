import io


def create_piece(client, token, title, filename="test.pdf"):
    pdf_content = b"%PDF-1.4 fake pdf content"
    pdf_file = io.BytesIO(pdf_content)

    response = client.post(
        "/pieces",
        data={"title": title},
        files={"pdf_file": (filename, pdf_file, "application/pdf")},
        headers={"Authorization": f"Bearer {token}"},
    )
    return response


def create_video_submission(client, token, piece_id, duration_seconds=30, notes=None):
    payload = {"piece_id": piece_id, "duration_seconds": duration_seconds}
    if notes is not None:
        payload["notes"] = notes
    response = client.post(
        "/video-submissions",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    return response


def test_create_video_submission(authenticated_client):
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    piece_response = create_piece(client, token, "Video Piece")
    piece_id = piece_response.json()["id"]

    response = create_video_submission(client, token, piece_id, duration_seconds=45)

    assert response.status_code == 200
    data = response.json()
    assert "submission" in data
    assert "upload_url" in data
    assert "thumbnail_upload_url" in data
    assert data["submission"]["piece_id"] == piece_id
    assert data["submission"]["duration_seconds"] == 45
    assert "cadenza/videos" in data["submission"]["s3_key"]

    list_response = client.get(
        "/video-submissions", headers={"Authorization": f"Bearer {token}"}
    )
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_create_submission_requires_duration(authenticated_client):
    client, user_data = authenticated_client(email="student@example.com")
    token = user_data["access_token"]

    piece_response = create_piece(client, token, "Video Piece")
    piece_id = piece_response.json()["id"]

    response = client.post(
        "/video-submissions",
        json={"piece_id": piece_id},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 422


def test_teacher_views_student_submissions(authenticated_client):
    client, teacher_data = authenticated_client(
        user_id="teacher_1", email="teacher@example.com"
    )
    teacher_token = teacher_data["access_token"]

    _, student_data = authenticated_client(
        user_id="student_1", email="student@example.com"
    )
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"},
    )

    piece_response = create_piece(client, student_token, "Student Video Piece")
    piece_id = piece_response.json()["id"]

    create_video_submission(client, student_token, piece_id)

    response = client.get(
        f"/students/{student_id}/video-submissions",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )

    assert response.status_code == 200
    submissions = response.json()
    assert len(submissions) == 1
    assert submissions[0]["user_id"] == student_id


def test_non_teacher_cannot_view_other_submissions(authenticated_client):
    client, teacher_data = authenticated_client(
        user_id="teacher_1", email="teacher@example.com"
    )
    _, student_data = authenticated_client(
        user_id="student_1", email="student@example.com"
    )
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"},
    )

    piece_response = create_piece(client, student_token, "Student Video Piece")
    piece_id = piece_response.json()["id"]
    create_video_submission(client, student_token, piece_id)

    _, stranger_data = authenticated_client(
        user_id="stranger", email="stranger@example.com"
    )
    stranger_token = stranger_data["access_token"]

    response = client.get(
        f"/students/{student_id}/video-submissions",
        headers={"Authorization": f"Bearer {stranger_token}"},
    )

    assert response.status_code == 403


def test_mark_reviewed(authenticated_client):
    client, teacher_data = authenticated_client(
        user_id="teacher_1", email="teacher@example.com"
    )
    teacher_token = teacher_data["access_token"]

    _, student_data = authenticated_client(
        user_id="student_1", email="student@example.com"
    )
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"},
    )

    piece_response = create_piece(client, student_token, "Student Video Piece")
    piece_id = piece_response.json()["id"]
    submission_response = create_video_submission(client, student_token, piece_id)
    submission_id = submission_response.json()["submission"]["id"]

    student_review = client.patch(
        f"/video-submissions/{submission_id}/reviewed",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert student_review.status_code == 403

    review_response = client.patch(
        f"/video-submissions/{submission_id}/reviewed",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )

    assert review_response.status_code == 200
    reviewed = review_response.json()
    assert reviewed["reviewed_by_id"] == teacher_data["user"]["id"]
    assert reviewed["reviewed_at"] is not None

    pending_response = client.get(
        f"/students/{student_id}/video-submissions",
        params={"pending_review": True},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )

    assert pending_response.status_code == 200
    assert len(pending_response.json()) == 0


def test_get_playback_url(authenticated_client):
    client, teacher_data = authenticated_client(
        user_id="teacher_1", email="teacher@example.com"
    )
    teacher_token = teacher_data["access_token"]

    _, student_data = authenticated_client(
        user_id="student_1", email="student@example.com"
    )
    student_token = student_data["access_token"]
    student_id = student_data["user"]["id"]

    client.post(
        "/users/set-teacher",
        params={"teacher_email": "teacher@example.com"},
        headers={"Authorization": f"Bearer {student_token}"},
    )

    piece_response = create_piece(client, student_token, "Student Video Piece")
    piece_id = piece_response.json()["id"]
    submission_response = create_video_submission(client, student_token, piece_id)
    submission_id = submission_response.json()["submission"]["id"]

    owner_response = client.get(
        f"/video-submissions/{submission_id}/video-url",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert owner_response.status_code == 200
    assert "video_url" in owner_response.json()

    teacher_response = client.get(
        f"/video-submissions/{submission_id}/video-url",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert teacher_response.status_code == 200

    _, stranger_data = authenticated_client(
        user_id="stranger", email="stranger@example.com"
    )
    stranger_token = stranger_data["access_token"]
    stranger_response = client.get(
        f"/video-submissions/{submission_id}/video-url",
        headers={"Authorization": f"Bearer {stranger_token}"},
    )
    assert stranger_response.status_code == 403
