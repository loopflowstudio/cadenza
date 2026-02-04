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


def create_video_submission(client, token, piece_id, duration_seconds=30):
    response = client.post(
        "/video-submissions",
        json={"piece_id": piece_id, "duration_seconds": duration_seconds},
        headers={"Authorization": f"Bearer {token}"},
    )
    return response


def create_message(
    client,
    token,
    submission_id,
    text=None,
    include_video=False,
    video_duration_seconds=None,
):
    payload = {"text": text, "include_video": include_video}
    if video_duration_seconds is not None:
        payload["video_duration_seconds"] = video_duration_seconds
    response = client.post(
        f"/video-submissions/{submission_id}/messages",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    return response


def setup_teacher_student(authenticated_client):
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

    return client, teacher_token, student_token, student_id


def create_submission_for_student(client, student_token):
    piece_response = create_piece(client, student_token, "Student Video Piece")
    piece_id = piece_response.json()["id"]
    submission_response = create_video_submission(client, student_token, piece_id)
    return submission_response.json()["submission"]["id"]


def test_create_text_message(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    response = create_message(
        client,
        teacher_token,
        submission_id,
        text="Great progress!",
        include_video=False,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"]["text"] == "Great progress!"

    list_response = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_create_video_message(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    response = create_message(
        client,
        teacher_token,
        submission_id,
        include_video=True,
        video_duration_seconds=15,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"]["video_s3_key"] is not None
    assert data["message"]["video_duration_seconds"] == 15
    assert data["upload_url"] is not None
    assert data["thumbnail_upload_url"] is not None


def test_create_combined_message(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    response = create_message(
        client,
        teacher_token,
        submission_id,
        text="Watch your wrist here.",
        include_video=True,
        video_duration_seconds=20,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"]["text"] == "Watch your wrist here."
    assert data["message"]["video_s3_key"] is not None


def test_student_can_reply(authenticated_client):
    client, _teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    response = create_message(
        client, student_token, submission_id, text="What about bar 3?"
    )

    assert response.status_code == 200
    list_response = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_non_participant_cannot_message(authenticated_client):
    client, _teacher_token, student_token, student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    _, stranger_data = authenticated_client(
        user_id="stranger", email="stranger@example.com"
    )
    stranger_token = stranger_data["access_token"]

    response = create_message(client, stranger_token, submission_id, text="Hello!")
    assert response.status_code == 403

    list_response = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {stranger_token}"},
    )
    assert list_response.status_code == 403


def test_list_messages_authorization(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    create_message(client, teacher_token, submission_id, text="Good job!")

    student_list = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert student_list.status_code == 200

    teacher_list = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert teacher_list.status_code == 200

    _, stranger_data = authenticated_client(
        user_id="stranger", email="stranger@example.com"
    )
    stranger_token = stranger_data["access_token"]
    stranger_list = client.get(
        f"/video-submissions/{submission_id}/messages",
        headers={"Authorization": f"Bearer {stranger_token}"},
    )
    assert stranger_list.status_code == 403


def test_message_video_url(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    message_response = create_message(
        client,
        teacher_token,
        submission_id,
        include_video=True,
        video_duration_seconds=10,
    )
    message_id = message_response.json()["message"]["id"]

    teacher_url = client.get(
        f"/messages/{message_id}/video-url",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert teacher_url.status_code == 200
    assert "video_url" in teacher_url.json()

    student_url = client.get(
        f"/messages/{message_id}/video-url",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert student_url.status_code == 200

    _, stranger_data = authenticated_client(
        user_id="stranger", email="stranger@example.com"
    )
    stranger_token = stranger_data["access_token"]
    stranger_url = client.get(
        f"/messages/{message_id}/video-url",
        headers={"Authorization": f"Bearer {stranger_token}"},
    )
    assert stranger_url.status_code == 403


def test_message_requires_content(authenticated_client):
    client, teacher_token, student_token, _student_id = setup_teacher_student(
        authenticated_client
    )
    submission_id = create_submission_for_student(client, student_token)

    response = create_message(client, teacher_token, submission_id)
    assert response.status_code == 422
