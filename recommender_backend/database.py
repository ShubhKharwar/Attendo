from fastapi import Depends
from sqlmodel import Session
from typing import Annotated
from sqlmodel import SQLModel, create_engine, Session, Field, Column, JSON
from typing import Optional, List, Dict, Any, Annotated
import os
from datetime import datetime
import json

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./recommendation_system.db")

# SQLite specific configuration
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
else:
    connect_args = {}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    echo=False  # Set to True for SQL query logging in development
)

def create_db_and_tables():
    """Create all database tables."""
    SQLModel.metadata.create_all(engine)

def get_session():
    """Dependency for getting database session."""
    with Session(engine) as session:
        yield session

# Type annotation for session dependency
SessionDep = Annotated[Session, Depends(get_session)]

# ==================== DATABASE MODELS ====================

class TaskBase(SQLModel):
    """Base model for tasks."""
    task_title: str = Field(index=True, description="Short, clear title of the task")
    task_description: str = Field(description="Brief explanation of the activity")
    course_tags: List[str] = Field(default_factory=list, sa_column=Column(JSON), description="Related courses")
    topic_tags: List[str] = Field(default_factory=list, sa_column=Column(JSON), description="Specific topics covered")
    estimated_time: int = Field(description="Time in minutes to complete")
    task_type: str = Field(description="Format of the task (quiz, video, reading, flashcards)")
    difficulty_level: Optional[str] = Field(default="medium", description="easy, medium, hard")
    prerequisites: Optional[List[str]] = Field(default_factory=list, sa_column=Column(JSON))

class Task(TaskBase, table=True):
    """Database model for micro-tasks."""
    __tablename__ = "tasks"

    task_id: Optional[str] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Embedding storage for vector similarity
    embedding_vector: Optional[str] = Field(default=None, description="JSON string of embedding vector")

    # Metadata for recommendation scoring
    popularity_score: Optional[float] = Field(default=0.0)
    completion_rate: Optional[float] = Field(default=0.0)
    avg_rating: Optional[float] = Field(default=0.0)

class UserProfileBase(SQLModel):
    """Base model for user profiles."""
    name: str = Field(description="User's name")
    interests: List[str] = Field(default_factory=list, sa_column=Column(JSON), description="User's stated interests")
    current_courses: List[str] = Field(default_factory=list, sa_column=Column(JSON), description="Currently enrolled courses")
    learning_preferences: Optional[Dict[str, Any]] = Field(default_factory=dict, sa_column=Column(JSON))

class UserProfile(UserProfileBase, table=True):
    """Database model for user profiles."""
    __tablename__ = "user_profiles"

    user_id: Optional[str] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Interest embedding for similarity matching
    interest_embedding: Optional[str] = Field(default=None, description="JSON string of interest embedding")

    # Attendance and performance tracking
    attendance_history: Optional[Dict[str, Any]] = Field(default_factory=dict, sa_column=Column(JSON))
    performance_metrics: Optional[Dict[str, Any]] = Field(default_factory=dict, sa_column=Column(JSON))

class RecommendationHistory(SQLModel, table=True):
    """Track recommendation history for analytics."""
    __tablename__ = "recommendation_history"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(foreign_key="user_profiles.user_id", index=True)
    task_id: str = Field(foreign_key="tasks.task_id", index=True)

    # Recommendation context
    break_duration: int = Field(description="Break duration in minutes")
    recommendation_rank: int = Field(description="Rank in recommendation list (1=top)")

    # Scoring breakdown
    interest_score: Optional[float] = Field(default=None)
    catchup_score: Optional[float] = Field(default=None)
    final_score: Optional[float] = Field(default=None)
    llm_reasoning: Optional[str] = Field(default=None, description="LLM's reasoning for recommendation")

    # User interaction
    was_clicked: Optional[bool] = Field(default=None)
    was_completed: Optional[bool] = Field(default=None)
    completion_time: Optional[int] = Field(default=None, description="Actual completion time in minutes")
    user_rating: Optional[int] = Field(default=None, description="User rating 1-5")

    recommended_at: datetime = Field(default_factory=datetime.utcnow)
    interacted_at: Optional[datetime] = Field(default=None)

class TaskFeedback(SQLModel, table=True):
    """User feedback on tasks."""
    __tablename__ = "task_feedback"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(foreign_key="user_profiles.user_id", index=True)
    task_id: str = Field(foreign_key="tasks.task_id", index=True)

    rating: int = Field(ge=1, le=5, description="User rating from 1-5")
    feedback_text: Optional[str] = Field(default=None)
    difficulty_rating: Optional[str] = Field(default=None, description="too_easy, just_right, too_hard")
    time_taken: Optional[int] = Field(default=None, description="Actual time taken in minutes")

    created_at: datetime = Field(default_factory=datetime.utcnow)

# database.py  (add after other models)

class DailyRecommendedTask(SQLModel, table=True):
    __tablename__ = "daily_recommended_tasks"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(foreign_key="user_profiles.user_id", index=True)
    date: str = Field(index=True, regex=r"^\d{4}-\d{2}-\d{2}$")

    # store JSON list of tasks
    recommendations: List[Dict[str, Any]] = Field(
        sa_column=Column(JSON), default_factory=list
    )

    generated_at: datetime = Field(default_factory=datetime.utcnow)

    __table_args__ = (UniqueConstraint("user_id", "date", name="unique_user_date"),)


# Add the missing import
from fastapi import Depends

print("✅ Database models and configuration created!")
