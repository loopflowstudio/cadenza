"""
Seed database with test scenarios for dogfooding.

Usage:
    uv run python seed_scenario.py --scenario teacher-with-students
    uv run python seed_scenario.py --list
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable
from uuid import uuid4

from sqlmodel import Session, select

from app.database import engine, create_db_and_tables
from app.models import (
    Exercise,
    ExerciseSession,
    Piece,
    PracticeSession,
    Routine,
    User,
)

# Bundled PDFs available in the iOS app
BUNDLED_PDFS = [
    "Suzuki - Cello School - Volume 1.pdf",
    "Suzuki - Cello School - Volume 2.pdf",
    "Suzuki - Cello School - Volume 3.pdf",
    "Essential Elements for Strings.pdf",
    "Cello Time Joggers.pdf",
    "Konzert - Joseph Haydn.pdf",
    "Sonata in G major.pdf",
]


@dataclass
class Scenario:
    name: str
    description: str
    setup: Callable[[Session], None]


def setup_empty(session: Session) -> None:
    """Fresh database, no data."""
    pass


def setup_teacher_with_students(session: Session) -> None:
    """Teacher with 2 students, routines, pieces."""
    now = datetime.now(timezone.utc)

    # Create teacher
    teacher = User(
        email="teacher@example.com",
        full_name="Test Teacher",
        user_type="teacher",
        created_at=now,
    )
    session.add(teacher)
    session.flush()

    # Create students linked to teacher
    student1 = User(
        email="student1@example.com",
        full_name="Alice Student",
        user_type="student",
        teacher_id=teacher.id,
        created_at=now,
    )
    student2 = User(
        email="student2@example.com",
        full_name="Bob Student",
        user_type="student",
        teacher_id=teacher.id,
        created_at=now,
    )
    session.add(student1)
    session.add(student2)
    session.flush()

    # Create pieces for teacher (using bundled PDFs)
    pieces = []
    for i, pdf in enumerate(BUNDLED_PDFS[:3]):
        piece = Piece(
            id=uuid4(),
            owner_id=teacher.id,
            title=pdf.replace(".pdf", ""),
            pdf_filename=pdf,
            s3_key=None,  # Bundled, no S3
            created_at=now,
            updated_at=now,
        )
        session.add(piece)
        pieces.append(piece)
    session.flush()

    # Create a routine for teacher
    teacher_routine = Routine(
        id=uuid4(),
        owner_id=teacher.id,
        title="Beginner Cello Routine",
        description="Daily warm-up and fundamentals",
        created_at=now,
        updated_at=now,
    )
    session.add(teacher_routine)
    session.flush()

    # Add exercises to the routine
    for i, piece in enumerate(pieces[:2]):
        exercise = Exercise(
            id=uuid4(),
            routine_id=teacher_routine.id,
            piece_id=piece.id,
            order_index=i,
            recommended_time_seconds=600 if i == 0 else 900,
            intentions="Focus on bow control" if i == 0 else "Work on intonation",
            start_page=1,
        )
        session.add(exercise)

    # Copy routine to student1 (as if assigned)
    student_routine = Routine(
        id=uuid4(),
        owner_id=student1.id,
        title="Beginner Cello Routine",
        description="Daily warm-up and fundamentals",
        assigned_by_id=teacher.id,
        assigned_at=now - timedelta(days=3),
        shared_from_routine_id=teacher_routine.id,
        created_at=now - timedelta(days=3),
        updated_at=now - timedelta(days=3),
    )
    session.add(student_routine)
    session.flush()

    # Copy pieces to student1
    student_pieces = []
    for piece in pieces[:2]:
        student_piece = Piece(
            id=uuid4(),
            owner_id=student1.id,
            title=piece.title,
            pdf_filename=piece.pdf_filename,
            s3_key=None,
            shared_from_piece_id=piece.id,
            created_at=now - timedelta(days=3),
            updated_at=now - timedelta(days=3),
        )
        session.add(student_piece)
        student_pieces.append(student_piece)
    session.flush()

    # Add exercises to student's routine
    for i, piece in enumerate(student_pieces):
        exercise = Exercise(
            id=uuid4(),
            routine_id=student_routine.id,
            piece_id=piece.id,
            order_index=i,
            recommended_time_seconds=600 if i == 0 else 900,
            intentions="Focus on bow control" if i == 0 else "Work on intonation",
            start_page=1,
        )
        session.add(exercise)

    session.commit()
    print(f"Created teacher: {teacher.email} (id={teacher.id})")
    print(f"Created student: {student1.email} (id={student1.id})")
    print(f"Created student: {student2.email} (id={student2.id})")
    print(f"Created {len(pieces)} pieces")
    print(f"Created routine: {teacher_routine.title}")


def setup_student_with_assignment(session: Session) -> None:
    """Student with assigned routine and practice history."""
    now = datetime.now(timezone.utc)

    # Create teacher
    teacher = User(
        email="teacher@example.com",
        full_name="Test Teacher",
        user_type="teacher",
        created_at=now,
    )
    session.add(teacher)
    session.flush()

    # Create student
    student = User(
        email="student1@example.com",
        full_name="Alice Student",
        user_type="student",
        teacher_id=teacher.id,
        created_at=now,
    )
    session.add(student)
    session.flush()

    # Create pieces for student
    pieces = []
    for i, pdf in enumerate(BUNDLED_PDFS[:3]):
        piece = Piece(
            id=uuid4(),
            owner_id=student.id,
            title=pdf.replace(".pdf", ""),
            pdf_filename=pdf,
            s3_key=None,
            created_at=now - timedelta(days=7),
            updated_at=now - timedelta(days=7),
        )
        session.add(piece)
        pieces.append(piece)
    session.flush()

    # Create routine with 3 exercises
    routine = Routine(
        id=uuid4(),
        owner_id=student.id,
        title="Weekly Practice",
        description="Assigned by teacher",
        assigned_by_id=teacher.id,
        assigned_at=now - timedelta(days=7),
        created_at=now - timedelta(days=7),
        updated_at=now - timedelta(days=7),
    )
    session.add(routine)
    session.flush()

    exercises = []
    for i, piece in enumerate(pieces):
        exercise = Exercise(
            id=uuid4(),
            routine_id=routine.id,
            piece_id=piece.id,
            order_index=i,
            recommended_time_seconds=600 + (i * 300),
            intentions=["Scales and arpeggios", "Etude practice", "Repertoire"][i],
            start_page=1,
        )
        session.add(exercise)
        exercises.append(exercise)
    session.flush()

    # Create 2 completed practice sessions (for calendar gold stars)
    for days_ago in [5, 3]:
        session_time = now - timedelta(days=days_ago)
        practice = PracticeSession(
            id=uuid4(),
            user_id=student.id,
            routine_id=routine.id,
            started_at=session_time,
            completed_at=session_time + timedelta(minutes=45),
            duration_seconds=45 * 60,
        )
        session.add(practice)
        session.flush()

        # Complete all exercises in the session
        for ex in exercises:
            ex_session = ExerciseSession(
                id=uuid4(),
                session_id=practice.id,
                exercise_id=ex.id,
                completed_at=session_time + timedelta(minutes=15),
                actual_time_seconds=15 * 60,
                reflections="Good progress today",
            )
            session.add(ex_session)

    # Create 1 in-progress session (started yesterday, not completed)
    in_progress = PracticeSession(
        id=uuid4(),
        user_id=student.id,
        routine_id=routine.id,
        started_at=now - timedelta(days=1),
        completed_at=None,
        duration_seconds=None,
    )
    session.add(in_progress)
    session.flush()

    # First exercise completed
    ex_session = ExerciseSession(
        id=uuid4(),
        session_id=in_progress.id,
        exercise_id=exercises[0].id,
        completed_at=now - timedelta(days=1) + timedelta(minutes=10),
        actual_time_seconds=10 * 60,
        reflections=None,
    )
    session.add(ex_session)

    session.commit()
    print(f"Created teacher: {teacher.email} (id={teacher.id})")
    print(f"Created student: {student.email} (id={student.id})")
    print(f"Created {len(pieces)} pieces")
    print(f"Created routine with {len(exercises)} exercises")
    print("Created 2 completed practice sessions")
    print("Created 1 in-progress practice session")


SCENARIOS: dict[str, Scenario] = {
    "empty": Scenario(
        name="empty",
        description="Fresh database, no data",
        setup=setup_empty,
    ),
    "teacher-with-students": Scenario(
        name="teacher-with-students",
        description="Teacher with 2 students, routines, pieces",
        setup=setup_teacher_with_students,
    ),
    "student-with-assignment": Scenario(
        name="student-with-assignment",
        description="Student with assigned routine, practice history",
        setup=setup_student_with_assignment,
    ),
}


def clear_database(session: Session) -> None:
    """Delete all data from all tables."""
    # Delete in order to respect foreign keys
    session.exec(select(ExerciseSession)).all()
    for row in session.exec(select(ExerciseSession)):
        session.delete(row)
    for row in session.exec(select(PracticeSession)):
        session.delete(row)
    for row in session.exec(select(Exercise)):
        session.delete(row)
    for row in session.exec(select(Routine)):
        session.delete(row)
    for row in session.exec(select(Piece)):
        session.delete(row)
    for row in session.exec(select(User)):
        session.delete(row)
    session.commit()
    print("Database cleared")


def run_scenario(name: str) -> None:
    """Run a named scenario."""
    if name not in SCENARIOS:
        print(f"Unknown scenario: {name}")
        print(f"Available: {', '.join(SCENARIOS.keys())}")
        return

    scenario = SCENARIOS[name]
    print(f"Running scenario: {scenario.name}")
    print(f"  {scenario.description}\n")

    # Ensure tables exist
    create_db_and_tables()

    with Session(engine) as session:
        clear_database(session)
        scenario.setup(session)

    print(f"\nScenario '{name}' complete")


def list_scenarios() -> None:
    """Print available scenarios."""
    print("Available scenarios:\n")
    for name, scenario in SCENARIOS.items():
        print(f"  {name}")
        print(f"    {scenario.description}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed database with test scenarios")
    parser.add_argument("--scenario", "-s", help="Scenario to run")
    parser.add_argument("--list", "-l", action="store_true", help="List scenarios")
    args = parser.parse_args()

    if args.list:
        list_scenarios()
    elif args.scenario:
        run_scenario(args.scenario)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
