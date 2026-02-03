from typing import Annotated, Optional
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, UploadFile, Form, File
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select

from app import models, schemas, auth
from app.database import engine, get_db, create_db_and_tables

app = FastAPI(title="Cadenza API")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Cadenza API"}


@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/auth/dev-login", response_model=schemas.AuthResponse)
def dev_login(
    email: str,
    db: Annotated[Session, Depends(get_db)]
):
    """
    Development-only login endpoint that bypasses Apple Sign In.
    Creates or updates a user with the given email.
    """
    # Find or create user by email
    user = db.exec(select(models.User).where(models.User.email == email)).first()

    if not user:
        # Create new user
        user = models.User(
            apple_user_id=f"dev_{email}",  # Fake Apple ID for dev
            email=email,
            full_name=None,
            user_type=None
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    elif not user.apple_user_id:
        # Upgrade stub user with dev credentials
        user.apple_user_id = f"dev_{email}"
        db.add(user)
        db.commit()
        db.refresh(user)

    access_token = auth.create_access_token(data={"sub": user.id})

    return schemas.AuthResponse(
        access_token=access_token,
        user=user
    )

@app.post("/auth/apple", response_model=schemas.AuthResponse)
def authenticate_with_apple(
    request: schemas.AppleAuthRequest,
    db: Annotated[Session, Depends(get_db)]
):
    apple_payload = auth.decode_apple_identity_token(request.id_token)

    apple_user_id = apple_payload.get("sub")
    email = apple_payload.get("email", f"{apple_user_id}@privaterelay.appleid.com")

    # First check if this Apple ID already exists
    user = db.exec(select(models.User).where(models.User.apple_user_id == apple_user_id)).first()

    if not user:
        # Check if this email was already added as a stub (e.g., by a student adding a teacher)
        user = db.exec(select(models.User).where(models.User.email == email)).first()

        if user:
            # Update the stub user with Apple credentials
            user.apple_user_id = apple_user_id
            # Note: We keep their existing teacher_id if they were added by a student
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            # Create a completely new user
            user = models.User(
                apple_user_id=apple_user_id,
                email=email,
                full_name=None,
                user_type=None
            )
            db.add(user)
            db.commit()
            db.refresh(user)

    access_token = auth.create_access_token(data={"sub": user.id})

    return schemas.AuthResponse(
        access_token=access_token,
        user=user
    )

@app.get("/auth/me", response_model=models.User)
def get_current_user_info(
    current_user: Annotated[models.User, Depends(auth.get_current_user)]
):
    return current_user


# MARK: - Teacher/Student Management

@app.post("/users/set-teacher", response_model=schemas.SetTeacherResponse)
def set_teacher(
    teacher_email: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Set a teacher for the current user (student can only have one teacher)"""
    # Validate email format
    if not teacher_email or "@" not in teacher_email:
        raise HTTPException(status_code=400, detail="Invalid email address")

    # Check if current user is trying to set themselves
    if teacher_email == current_user.email:
        raise HTTPException(status_code=400, detail="Cannot set yourself as teacher")

    # Find or create teacher user
    teacher = db.exec(select(models.User).where(models.User.email == teacher_email)).first()

    if not teacher:
        # Create a new user for this teacher email
        # They'll complete their profile on first login
        teacher = models.User(
            apple_user_id=None,  # Will be set on first Apple Sign In
            email=teacher_email,
            full_name=None,  # Will be set on first Apple Sign In
            user_type=None   # Will be determined on first login
        )
        db.add(teacher)
        db.commit()
        db.refresh(teacher)

    current_user.teacher_id = teacher.id
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    db.refresh(teacher)

    return schemas.SetTeacherResponse(message="Teacher set successfully", teacher=teacher)


@app.delete("/users/remove-teacher")
def remove_teacher(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Remove the current user's teacher"""
    current_user.teacher_id = None
    db.add(current_user)
    db.commit()

    return {"message": "Teacher removed successfully"}


@app.get("/users/my-teacher", response_model=models.User | None)
def get_my_teacher(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get the current user's teacher"""
    if not current_user.teacher_id:
        return None

    teacher = db.get(models.User, current_user.teacher_id)
    return teacher


@app.get("/users/my-students", response_model=list[models.User])
def get_my_students(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get all students who have set the current user as their teacher"""
    students = db.exec(
        select(models.User).where(models.User.teacher_id == current_user.id)
    ).all()

    return list(students)


# MARK: - Piece Management

@app.get("/pieces", response_model=list[models.Piece])
def get_my_pieces(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get all pieces owned by the current user"""
    pieces = db.exec(
        select(models.Piece).where(models.Piece.owner_id == current_user.id)
    ).all()

    pieces_list = list(pieces)
    print(f"[DB READ] GET /pieces - User {current_user.id} ({current_user.email}) - Returning {len(pieces_list)} pieces")
    return pieces_list


@app.post("/pieces", response_model=models.Piece)
async def create_piece(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    title: Annotated[str, Form()],
    pdf_file: Annotated[UploadFile, File()]
):
    """
    Create a new piece for the current user.

    The iOS app sends the PDF file content (from bundle, Dropbox, iCloud, etc.).
    The server handles uploading to S3.
    """
    from app import s3
    from uuid import uuid4

    # Generate UUID for the piece
    piece_id = uuid4()

    # Upload file to S3
    pdf_filename = pdf_file.filename or "upload.pdf"
    file_content = await pdf_file.read()

    s3_key = s3.get_piece_s3_key(piece_id)
    s3.upload_file_content(s3_key, file_content)

    # Create database record
    piece = models.Piece(
        id=piece_id,
        owner_id=current_user.id,
        title=title,
        pdf_filename=pdf_filename,
        s3_key=s3_key
    )

    db.add(piece)
    db.commit()
    db.refresh(piece)

    print(f"[DB WRITE] POST /pieces - User {current_user.id} ({current_user.email}) - Created piece {piece_id} '{title}'")
    return piece


@app.put("/pieces/{piece_id}", response_model=models.Piece)
def update_piece(
    piece_id: str,
    title: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Update a piece's title"""
    from uuid import UUID

    piece = db.get(models.Piece, UUID(piece_id))

    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    if piece.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this piece")

    piece.title = title
    piece.updated_at = datetime.now(timezone.utc)
    db.add(piece)
    db.commit()
    db.refresh(piece)

    print(f"[DB WRITE] PUT /pieces/{piece_id} - User {current_user.id} ({current_user.email}) - Updated title to '{title}'")
    return piece


@app.delete("/pieces/{piece_id}")
def delete_piece(
    piece_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Delete a piece"""
    from uuid import UUID

    piece = db.get(models.Piece, UUID(piece_id))

    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    if piece.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this piece")

    print(f"[DB WRITE] DELETE /pieces/{piece_id} - User {current_user.id} ({current_user.email}) - Deleted piece '{piece.title}'")
    db.delete(piece)
    db.commit()

    return {"message": "Piece deleted successfully"}


@app.get("/students/{student_id}/pieces", response_model=list[models.Piece])
def get_student_pieces(
    student_id: int,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get all pieces for a specific student (teacher only)"""
    student = db.get(models.User, student_id)

    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if student.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this student's pieces")

    pieces = db.exec(
        select(models.Piece).where(models.Piece.owner_id == student_id)
    ).all()

    return list(pieces)


@app.post("/pieces/{piece_id}/share/{student_id}", response_model=models.Piece)
def share_piece_with_student(
    piece_id: str,
    student_id: int,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Share a piece with a student (creates a copy in student's library)"""
    from uuid import UUID

    # Get the original piece
    original_piece = db.get(models.Piece, UUID(piece_id))

    if not original_piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    if original_piece.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to share this piece")

    # Get the student
    student = db.get(models.User, student_id)

    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if student.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to share with this student")

    # Create a copy for the student
    new_piece = models.Piece(
        owner_id=student_id,
        title=original_piece.title,
        pdf_filename=original_piece.pdf_filename,
        shared_from_piece_id=original_piece.id
    )

    db.add(new_piece)
    db.commit()
    db.refresh(new_piece)

    return new_piece


@app.get("/pieces/{piece_id}/download-url", response_model=schemas.PieceDownloadUrlResponse)
def get_piece_download_url(
    piece_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get a presigned URL to download the PDF for a piece"""
    from uuid import UUID
    from app import s3

    piece = db.get(models.Piece, UUID(piece_id))

    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    if piece.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this piece")

    if not piece.s3_key:
        raise HTTPException(status_code=404, detail="PDF not available for this piece")

    download_url = s3.generate_download_url(piece.s3_key)

    return schemas.PieceDownloadUrlResponse(
        download_url=download_url,
        expires_in=3600
    )


# MARK: - Routine Management

@app.get("/routines", response_model=list[models.Routine])
def get_my_routines(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get all routines owned by the current user"""
    routines = db.exec(
        select(models.Routine).where(models.Routine.owner_id == current_user.id)
    ).all()
    return list(routines)


@app.post("/routines", response_model=models.Routine)
def create_routine(
    routine: schemas.RoutineCreate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Create a new routine"""
    new_routine = models.Routine(
        owner_id=current_user.id,
        title=routine.title,
        description=routine.description
    )
    db.add(new_routine)
    db.commit()
    db.refresh(new_routine)
    return new_routine


@app.get("/routines/{routine_id}")
def get_routine(
    routine_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get a routine with its exercises"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this routine")

    exercises = db.exec(
        select(models.Exercise)
        .where(models.Exercise.routine_id == routine.id)
        .order_by(models.Exercise.order_index)
    ).all()

    return {
        "routine": routine,
        "exercises": list(exercises)
    }


@app.put("/routines/{routine_id}", response_model=models.Routine)
def update_routine(
    routine_id: str,
    routine_update: schemas.RoutineCreate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Update a routine's metadata"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this routine")

    routine.title = routine_update.title
    routine.description = routine_update.description
    routine.updated_at = datetime.now(timezone.utc)
    db.add(routine)
    db.commit()
    db.refresh(routine)
    return routine


@app.delete("/routines/{routine_id}")
def delete_routine(
    routine_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Delete a routine and all its exercises"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this routine")

    # Delete all exercises first
    exercises = db.exec(
        select(models.Exercise).where(models.Exercise.routine_id == routine.id)
    ).all()
    for exercise in exercises:
        db.delete(exercise)

    db.delete(routine)
    db.commit()
    return {"message": "Routine deleted successfully"}


# MARK: - Exercise Management

@app.post("/routines/{routine_id}/exercises", response_model=models.Exercise)
def add_exercise_to_routine(
    routine_id: str,
    exercise: schemas.ExerciseCreate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Add an exercise to a routine"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this routine")

    # Verify the piece exists and user owns it
    piece = db.get(models.Piece, exercise.piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    if piece.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to use this piece")

    new_exercise = models.Exercise(
        routine_id=routine.id,
        piece_id=exercise.piece_id,
        order_index=exercise.order_index,
        recommended_time_seconds=exercise.recommended_time_seconds,
        intentions=exercise.intentions,
        start_page=exercise.start_page
    )
    db.add(new_exercise)

    # Update routine's updated_at
    routine.updated_at = datetime.now(timezone.utc)
    db.add(routine)

    db.commit()
    db.refresh(new_exercise)
    return new_exercise


@app.put("/routines/{routine_id}/exercises/{exercise_id}", response_model=models.Exercise)
def update_exercise(
    routine_id: str,
    exercise_id: str,
    exercise_update: schemas.ExerciseUpdate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Update an exercise's metadata"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this routine")

    exercise = db.get(models.Exercise, UUID(exercise_id))
    if not exercise or exercise.routine_id != routine.id:
        raise HTTPException(status_code=404, detail="Exercise not found in this routine")

    if exercise_update.recommended_time_seconds is not None:
        exercise.recommended_time_seconds = exercise_update.recommended_time_seconds
    if exercise_update.intentions is not None:
        exercise.intentions = exercise_update.intentions
    if exercise_update.start_page is not None:
        exercise.start_page = exercise_update.start_page
    if exercise_update.order_index is not None:
        exercise.order_index = exercise_update.order_index

    db.add(exercise)

    # Update routine's updated_at
    routine.updated_at = datetime.now(timezone.utc)
    db.add(routine)

    db.commit()
    db.refresh(exercise)
    return exercise


@app.delete("/routines/{routine_id}/exercises/{exercise_id}")
def delete_exercise(
    routine_id: str,
    exercise_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Remove an exercise from a routine"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this routine")

    exercise = db.get(models.Exercise, UUID(exercise_id))
    if not exercise or exercise.routine_id != routine.id:
        raise HTTPException(status_code=404, detail="Exercise not found in this routine")

    db.delete(exercise)

    # Update routine's updated_at
    routine.updated_at = datetime.now(timezone.utc)
    db.add(routine)

    db.commit()
    return {"message": "Exercise removed successfully"}


@app.put("/routines/{routine_id}/reorder")
def reorder_exercises(
    routine_id: str,
    reorder: schemas.RoutineReorder,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Reorder all exercises in a routine"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this routine")

    # Update order_index for each exercise
    for index, exercise_id in enumerate(reorder.exercise_ids):
        exercise = db.get(models.Exercise, exercise_id)
        if not exercise or exercise.routine_id != routine.id:
            raise HTTPException(status_code=400, detail=f"Exercise {exercise_id} not found in routine")
        exercise.order_index = index
        db.add(exercise)

    # Update routine's updated_at
    routine.updated_at = datetime.now(timezone.utc)
    db.add(routine)

    db.commit()
    return {"message": "Exercises reordered successfully"}


# MARK: - Routine Assignment

@app.post("/students/{student_id}/assign-routine")
def assign_routine_to_student(
    student_id: int,
    routine_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """
    Assign a routine to a student.
    This copies the routine to the student's account and shares all referenced pieces.
    """
    from uuid import UUID

    # Verify student exists and current user is their teacher
    student = db.get(models.User, student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if student.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to assign routines to this student")

    # Get the original routine
    original_routine = db.get(models.Routine, UUID(routine_id))
    if not original_routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if original_routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to assign this routine")

    # Get original exercises
    original_exercises = db.exec(
        select(models.Exercise)
        .where(models.Exercise.routine_id == original_routine.id)
        .order_by(models.Exercise.order_index)
    ).all()

    # Create a copy of the routine for the student
    new_routine = models.Routine(
        owner_id=student_id,
        title=original_routine.title,
        description=original_routine.description,
        assigned_by_id=current_user.id,
        assigned_at=datetime.now(timezone.utc),
        shared_from_routine_id=original_routine.id
    )
    db.add(new_routine)
    db.flush()  # Get the new routine ID

    # Copy exercises and share pieces
    piece_mapping = {}  # original_piece_id -> student_piece_id
    pieces_newly_shared = 0

    for orig_exercise in original_exercises:
        # Check if student already has this piece
        student_piece_id = orig_exercise.piece_id

        if orig_exercise.piece_id not in piece_mapping:
            # Check if student already has a copy of this piece
            existing_piece = db.exec(
                select(models.Piece).where(
                    models.Piece.owner_id == student_id,
                    models.Piece.shared_from_piece_id == orig_exercise.piece_id
                )
            ).first()

            if existing_piece:
                piece_mapping[orig_exercise.piece_id] = existing_piece.id
            else:
                # Share the piece with the student
                original_piece = db.get(models.Piece, orig_exercise.piece_id)
                if original_piece:
                    new_piece = models.Piece(
                        owner_id=student_id,
                        title=original_piece.title,
                        pdf_filename=original_piece.pdf_filename,
                        s3_key=original_piece.s3_key,  # Share the same S3 file
                        shared_from_piece_id=original_piece.id
                    )
                    db.add(new_piece)
                    db.flush()
                    piece_mapping[orig_exercise.piece_id] = new_piece.id
                    pieces_newly_shared += 1

        student_piece_id = piece_mapping.get(orig_exercise.piece_id, orig_exercise.piece_id)

        # Create exercise in new routine
        new_exercise = models.Exercise(
            routine_id=new_routine.id,
            piece_id=student_piece_id,
            order_index=orig_exercise.order_index,
            recommended_time_seconds=orig_exercise.recommended_time_seconds,
            intentions=orig_exercise.intentions,
            start_page=orig_exercise.start_page
        )
        db.add(new_exercise)

    # Remove any existing assignment for this student (must flush before creating new one due to unique constraint)
    existing_assignment = db.exec(
        select(models.RoutineAssignment).where(models.RoutineAssignment.student_id == student_id)
    ).first()
    if existing_assignment:
        db.delete(existing_assignment)
        db.flush()  # Flush the delete before inserting new assignment

    # Create the assignment
    assignment = models.RoutineAssignment(
        student_id=student_id,
        routine_id=new_routine.id,
        assigned_by_id=current_user.id
    )
    db.add(assignment)

    db.commit()
    db.refresh(new_routine)

    return {
        "message": "Routine assigned successfully",
        "routine": new_routine,
        "pieces_shared": pieces_newly_shared
    }


@app.get("/students/{student_id}/current-routine")
def get_student_current_routine(
    student_id: int,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get a student's currently assigned routine"""
    student = db.get(models.User, student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if student.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this student's routine")

    assignment = db.exec(
        select(models.RoutineAssignment).where(models.RoutineAssignment.student_id == student_id)
    ).first()

    if not assignment:
        return None

    routine = db.get(models.Routine, assignment.routine_id)
    exercises = db.exec(
        select(models.Exercise)
        .where(models.Exercise.routine_id == routine.id)
        .order_by(models.Exercise.order_index)
    ).all()

    return {
        "assignment": assignment,
        "routine": routine,
        "exercises": list(exercises)
    }


@app.get("/my-current-routine")
def get_my_current_routine(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get the current user's assigned routine (student view)"""
    assignment = db.exec(
        select(models.RoutineAssignment).where(models.RoutineAssignment.student_id == current_user.id)
    ).first()

    if not assignment:
        return None

    routine = db.get(models.Routine, assignment.routine_id)
    exercises = db.exec(
        select(models.Exercise)
        .where(models.Exercise.routine_id == routine.id)
        .order_by(models.Exercise.order_index)
    ).all()

    return {
        "assignment": assignment,
        "routine": routine,
        "exercises": list(exercises)
    }


# MARK: - Practice Sessions

@app.post("/sessions", response_model=models.PracticeSession)
def start_practice_session(
    routine_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Start a new practice session from a routine"""
    from uuid import UUID

    routine = db.get(models.Routine, UUID(routine_id))
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")

    if routine.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to practice this routine")

    session = models.PracticeSession(
        user_id=current_user.id,
        routine_id=routine.id
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@app.put("/sessions/{session_id}/complete", response_model=models.PracticeSession)
def complete_practice_session(
    session_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Mark a practice session as complete"""
    from uuid import UUID

    session = db.get(models.PracticeSession, UUID(session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to complete this session")

    session.completed_at = datetime.now(timezone.utc)
    if session.started_at:
        # Ensure both datetimes are timezone-aware for comparison
        started = session.started_at
        if started.tzinfo is None:
            started = started.replace(tzinfo=timezone.utc)
        duration = (session.completed_at - started).total_seconds()
        session.duration_seconds = int(duration)

    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@app.post("/sessions/{session_id}/exercises/{exercise_id}/complete", response_model=models.ExerciseSession)
def complete_exercise_in_session(
    session_id: str,
    exercise_id: str,
    exercise_session: schemas.ExerciseSessionCreate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Mark an exercise as complete within a practice session"""
    from uuid import UUID

    session = db.get(models.PracticeSession, UUID(session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this session")

    exercise = db.get(models.Exercise, UUID(exercise_id))
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    # Verify exercise belongs to the session's routine
    if exercise.routine_id != session.routine_id:
        raise HTTPException(status_code=400, detail="Exercise does not belong to session's routine")

    existing_exercise_session = db.exec(
        select(models.ExerciseSession).where(
            models.ExerciseSession.session_id == session.id,
            models.ExerciseSession.exercise_id == exercise.id
        )
    ).first()

    if existing_exercise_session:
        existing_exercise_session.completed_at = datetime.now(timezone.utc)
        if "actual_time_seconds" in exercise_session.model_fields_set:
            existing_exercise_session.actual_time_seconds = exercise_session.actual_time_seconds
        if "reflections" in exercise_session.model_fields_set:
            existing_exercise_session.reflections = exercise_session.reflections
        db.add(existing_exercise_session)
        db.commit()
        db.refresh(existing_exercise_session)
        return existing_exercise_session

    new_exercise_session = models.ExerciseSession(
        session_id=session.id,
        exercise_id=exercise.id,
        completed_at=datetime.now(timezone.utc),
        actual_time_seconds=exercise_session.actual_time_seconds,
        reflections=exercise_session.reflections
    )
    db.add(new_exercise_session)
    db.commit()
    db.refresh(new_exercise_session)
    return new_exercise_session


@app.patch("/sessions/{session_id}/exercises/{exercise_id}", response_model=models.ExerciseSession)
def toggle_exercise_completion(
    session_id: str,
    exercise_id: str,
    update: schemas.ExerciseSessionUpdate,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Toggle exercise completion state within a practice session"""
    from uuid import UUID

    session = db.get(models.PracticeSession, UUID(session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this session")

    exercise = db.get(models.Exercise, UUID(exercise_id))
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    if exercise.routine_id != session.routine_id:
        raise HTTPException(status_code=400, detail="Exercise does not belong to session's routine")

    exercise_session = db.exec(
        select(models.ExerciseSession).where(
            models.ExerciseSession.session_id == session.id,
            models.ExerciseSession.exercise_id == exercise.id
        )
    ).first()

    if exercise_session is None:
        exercise_session = models.ExerciseSession(
            session_id=session.id,
            exercise_id=exercise.id
        )

    if update.is_complete:
        exercise_session.completed_at = datetime.now(timezone.utc)
        if "actual_time_seconds" in update.model_fields_set:
            exercise_session.actual_time_seconds = update.actual_time_seconds
        if "reflections" in update.model_fields_set:
            exercise_session.reflections = update.reflections
    else:
        exercise_session.completed_at = None
        exercise_session.actual_time_seconds = None
        exercise_session.reflections = None

    db.add(exercise_session)
    db.commit()
    db.refresh(exercise_session)
    return exercise_session


@app.get("/sessions", response_model=list[models.PracticeSession])
def get_my_practice_sessions(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get all practice sessions for the current user"""
    sessions = db.exec(
        select(models.PracticeSession)
        .where(models.PracticeSession.user_id == current_user.id)
        .order_by(models.PracticeSession.started_at.desc())
    ).all()
    return list(sessions)


@app.get("/sessions/calendar", response_model=list[schemas.CalendarDay])
def get_practice_calendar(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get calendar data showing days with practice sessions (for gold stars)"""
    # Get completed sessions grouped by date
    sessions = db.exec(
        select(models.PracticeSession)
        .where(
            models.PracticeSession.user_id == current_user.id,
            models.PracticeSession.completed_at.isnot(None)
        )
    ).all()

    # Group by date
    date_counts = {}
    for session in sessions:
        if session.completed_at:
            date_str = session.completed_at.strftime('%Y-%m-%d')
            date_counts[date_str] = date_counts.get(date_str, 0) + 1

    # Convert to CalendarDay objects
    calendar_days = [
        schemas.CalendarDay(date=date, session_count=count)
        for date, count in sorted(date_counts.items())
    ]

    return calendar_days


@app.get("/sessions/completions", response_model=list[schemas.SessionCompletion])
def get_practice_completions(
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get completion timestamps for local-time calendar bucketing"""
    sessions = db.exec(
        select(models.PracticeSession.completed_at)
        .where(
            models.PracticeSession.user_id == current_user.id,
            models.PracticeSession.completed_at.isnot(None)
        )
        .order_by(models.PracticeSession.completed_at.desc())
    ).all()

    return [schemas.SessionCompletion(completed_at=completed_at) for completed_at in sessions]


@app.get("/sessions/{session_id}")
def get_practice_session(
    session_id: str,
    current_user: Annotated[models.User, Depends(auth.get_current_user)],
    db: Annotated[Session, Depends(get_db)]
):
    """Get a practice session with its exercise completions"""
    from uuid import UUID

    session = db.get(models.PracticeSession, UUID(session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this session")

    exercise_sessions = db.exec(
        select(models.ExerciseSession)
        .where(models.ExerciseSession.session_id == session.id)
        .order_by(models.ExerciseSession.completed_at)
    ).all()

    return {
        "session": session,
        "exercise_sessions": list(exercise_sessions)
    }
