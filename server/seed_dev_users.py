#!/usr/bin/env python3
"""
Seed the database with development test users.

Usage:
    python seed_dev_users.py
"""
from sqlmodel import Session, select
from app.database import engine
from app.models import User
from app.auth import create_access_token
from datetime import datetime, timezone

def seed_users():
    with Session(engine) as session:
        # Check if users already exist
        existing = session.exec(select(User).where(User.email == "teacher@example.com")).first()
        if existing:
            print("✓ Test users already exist")
            return

        # Create test users
        teacher = User(
            apple_user_id="dev_teacher_001",
            email="teacher@example.com",
            full_name="Test Teacher",
            user_type="teacher",
            teacher_id=None
        )

        student1 = User(
            apple_user_id="dev_student_001",
            email="student1@example.com",
            full_name="Test Student 1",
            user_type="student",
            teacher_id=None  # Will be set after teacher is saved
        )

        student2 = User(
            apple_user_id="dev_student_002",
            email="student2@example.com",
            full_name="Test Student 2",
            user_type="student",
            teacher_id=None
        )

        session.add(teacher)
        session.commit()
        session.refresh(teacher)

        # Set teacher relationship
        student1.teacher_id = teacher.id
        student2.teacher_id = teacher.id

        session.add(student1)
        session.add(student2)
        session.commit()
        session.refresh(student1)
        session.refresh(student2)

        print(f"✓ Created test users:")
        print(f"  Teacher: {teacher.email} (id={teacher.id})")
        print(f"  Student 1: {student1.email} (id={student1.id})")
        print(f"  Student 2: {student2.email} (id={student2.id})")

        # Generate tokens for easy testing
        print(f"\n✓ Dev tokens (for manual testing):")
        print(f"  Teacher: {create_access_token(data={'sub': teacher.id})}")
        print(f"  Student 1: {create_access_token(data={'sub': student1.id})}")
        print(f"  Student 2: {create_access_token(data={'sub': student2.id})}")

if __name__ == "__main__":
    seed_users()
