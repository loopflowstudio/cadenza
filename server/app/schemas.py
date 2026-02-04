from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from typing import Optional
from app.models import User


class AppleAuthRequest(BaseModel):
    id_token: str = Field(..., alias="idToken")

    class Config:
        populate_by_name = True


class AuthResponse(BaseModel):
    access_token: str
    user: User


class SetTeacherResponse(BaseModel):
    message: str
    teacher: User


class PieceDownloadUrlResponse(BaseModel):
    download_url: str
    expires_in: int


# Routine schemas


class RoutineCreate(BaseModel):
    title: str
    description: Optional[str] = None


class ExerciseCreate(BaseModel):
    piece_id: UUID
    order_index: int
    recommended_time_seconds: Optional[int] = None
    intentions: Optional[str] = None
    start_page: Optional[int] = None


class ExerciseUpdate(BaseModel):
    recommended_time_seconds: Optional[int] = None
    intentions: Optional[str] = None
    start_page: Optional[int] = None
    order_index: Optional[int] = None


class RoutineReorder(BaseModel):
    """List of exercise IDs in desired order"""

    exercise_ids: list[UUID]


class ExerciseSessionCreate(BaseModel):
    actual_time_seconds: Optional[int] = None
    reflections: Optional[str] = None


class ExerciseSessionUpdate(BaseModel):
    is_complete: bool
    actual_time_seconds: Optional[int] = None
    reflections: Optional[str] = None


class SessionCompletion(BaseModel):
    completed_at: datetime


class CalendarDay(BaseModel):
    date: str  # YYYY-MM-DD
    session_count: int
