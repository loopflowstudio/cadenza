from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4
from sqlalchemy import UniqueConstraint
from sqlmodel import Field, SQLModel
from pydantic import field_serializer


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: Optional[int] = Field(default=None, primary_key=True)
    apple_user_id: Optional[str] = Field(default=None, unique=True, index=True)
    email: str
    full_name: Optional[str] = None
    user_type: Optional[str] = None
    teacher_id: Optional[int] = Field(default=None, foreign_key="users.id")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at")
    def serialize_created_at(self, dt: datetime, _info):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        # Use Z notation and standard format that iOS handles well
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


class Piece(SQLModel, table=True):
    __tablename__ = "pieces"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    owner_id: int = Field(foreign_key="users.id", index=True)
    title: str
    pdf_filename: str  # Original filename for display
    s3_key: Optional[str] = None  # S3 path: cadenza/pieces/{uuid}.pdf
    shared_from_piece_id: Optional[UUID] = Field(default=None, foreign_key="pieces.id")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at", "updated_at")
    def serialize_datetime(self, dt: datetime, _info):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "shared_from_piece_id")
    def serialize_uuid(self, val: Optional[UUID], _info):
        return str(val) if val else None


class Routine(SQLModel, table=True):
    __tablename__ = "routines"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    owner_id: int = Field(foreign_key="users.id", index=True)
    title: str
    description: Optional[str] = None
    assigned_by_id: Optional[int] = Field(default=None, foreign_key="users.id")
    assigned_at: Optional[datetime] = None
    shared_from_routine_id: Optional[UUID] = Field(
        default=None, foreign_key="routines.id"
    )
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at", "updated_at", "assigned_at")
    def serialize_datetime(self, dt: Optional[datetime], _info):
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "shared_from_routine_id")
    def serialize_uuid(self, val: Optional[UUID], _info):
        return str(val) if val else None


class Exercise(SQLModel, table=True):
    __tablename__ = "exercises"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    routine_id: UUID = Field(foreign_key="routines.id", index=True)
    piece_id: UUID = Field(foreign_key="pieces.id")
    order_index: int
    recommended_time_seconds: Optional[int] = None
    intentions: Optional[str] = None
    start_page: Optional[int] = None

    @field_serializer("id", "routine_id", "piece_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)


class RoutineAssignment(SQLModel, table=True):
    __tablename__ = "routine_assignments"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    student_id: int = Field(foreign_key="users.id", unique=True, index=True)
    routine_id: UUID = Field(foreign_key="routines.id")
    assigned_by_id: int = Field(foreign_key="users.id")
    assigned_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("assigned_at")
    def serialize_datetime(self, dt: datetime, _info):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "routine_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)


class PracticeSession(SQLModel, table=True):
    __tablename__ = "practice_sessions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    routine_id: UUID = Field(foreign_key="routines.id")
    started_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    completed_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None

    @field_serializer("started_at", "completed_at")
    def serialize_datetime(self, dt: Optional[datetime], _info):
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "routine_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)


class ExerciseSession(SQLModel, table=True):
    __tablename__ = "exercise_sessions"
    __table_args__ = (UniqueConstraint("session_id", "exercise_id"),)

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    session_id: UUID = Field(foreign_key="practice_sessions.id", index=True)
    exercise_id: UUID = Field(foreign_key="exercises.id")
    completed_at: Optional[datetime] = None
    actual_time_seconds: Optional[int] = None
    reflections: Optional[str] = None

    @field_serializer("completed_at")
    def serialize_datetime(self, dt: Optional[datetime], _info):
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "session_id", "exercise_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)


class VideoSubmission(SQLModel, table=True):
    __tablename__ = "video_submissions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    exercise_id: Optional[UUID] = Field(default=None, foreign_key="exercises.id")
    piece_id: Optional[UUID] = Field(default=None, foreign_key="pieces.id")
    session_id: Optional[UUID] = Field(default=None, foreign_key="practice_sessions.id")

    s3_key: str
    thumbnail_s3_key: Optional[str] = None
    duration_seconds: int

    notes: Optional[str] = None

    reviewed_at: Optional[datetime] = None
    reviewed_by_id: Optional[int] = Field(default=None, foreign_key="users.id")

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at", "reviewed_at")
    def serialize_datetime(self, dt: Optional[datetime], _info):
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "exercise_id", "piece_id", "session_id")
    def serialize_uuid(self, val: Optional[UUID], _info):
        return str(val) if val else None


class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    submission_id: UUID = Field(foreign_key="video_submissions.id", index=True)
    sender_id: int = Field(foreign_key="users.id")

    text: Optional[str] = None
    video_s3_key: Optional[str] = None
    video_duration_seconds: Optional[int] = None
    thumbnail_s3_key: Optional[str] = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at")
    def serialize_datetime(self, dt: datetime, _info):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "submission_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)
