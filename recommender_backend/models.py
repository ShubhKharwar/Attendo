from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

# ==================== REQUEST/RESPONSE MODELS ====================

class TaskCreate(BaseModel):
    """Model for creating a new task."""
    task_title: str = Field(..., description="Short, clear title of the task")
    task_description: str = Field(..., description="Brief explanation of the activity")
    course_tags: List[str] = Field(default_factory=list, description="Related courses")
    topic_tags: List[str] = Field(default_factory=list, description="Specific topics covered")
    estimated_time: int = Field(..., gt=0, le=120, description="Time in minutes (1-120)")
    task_type: str = Field(..., description="Format: quiz, video, reading, flashcards, coding")
    difficulty_level: Optional[str] = Field(default="medium", description="easy, medium, hard")
    prerequisites: Optional[List[str]] = Field(default_factory=list)

class TaskRead(TaskCreate):
    """Model for reading a task."""
    task_id: str
    created_at: datetime
    updated_at: datetime
    popularity_score: Optional[float] = 0.0
    completion_rate: Optional[float] = 0.0
    avg_rating: Optional[float] = 0.0

class UserProfileCreate(BaseModel):
    """Model for creating a user profile."""
    name: str = Field(..., description="User's name")
    interests: List[str] = Field(default_factory=list, description="User's stated interests")
    current_courses: List[str] = Field(default_factory=list, description="Currently enrolled courses")
    learning_preferences: Optional[Dict[str, Any]] = Field(default_factory=dict)

class UserProfile(UserProfileCreate):
    """Model for reading a user profile."""
    user_id: str
    created_at: datetime
    updated_at: datetime
    attendance_history: Optional[Dict[str, Any]] = Field(default_factory=dict)
    performance_metrics: Optional[Dict[str, Any]] = Field(default_factory=dict)

class AttendanceRecord(BaseModel):
    """Model for attendance information."""
    missed_classes: int = Field(ge=0, description="Number of missed classes")
    days_since_last_absence: int = Field(ge=0, description="Days since last absence")
    total_classes: Optional[int] = Field(default=None, ge=0)
    attendance_rate: Optional[float] = Field(default=None, ge=0.0, le=1.0)

class StudentContext(BaseModel):
    """Model for student context information."""
    break_duration: int = Field(..., description="Available break time in minutes")
    interests: List[str] = Field(..., description="Student's interests")
    academic_situation: str = Field(..., description="Description of academic status")

class RecommendationRequest(BaseModel):
    """Model for recommendation requests."""
    user_id: str = Field(..., description="User identifier")
    break_duration_minutes: int = Field(..., gt=0, le=180, description="Available time in minutes")
    current_courses: Optional[List[str]] = Field(default_factory=list)
    interests: Optional[List[str]] = Field(default_factory=list)
    recent_attendance: Optional[Dict[str, AttendanceRecord]] = Field(default_factory=dict)

    # Optional context for better recommendations
    current_location: Optional[str] = Field(default=None)
    preferred_task_types: Optional[List[str]] = Field(default_factory=list)
    difficulty_preference: Optional[str] = Field(default="medium")

class RecommendationResponse(BaseModel):
    """Model for individual recommendation response."""
    rank: int = Field(..., description="Recommendation ranking (1=top)")
    task_id: str = Field(..., description="Task identifier")
    title: str = Field(..., description="Engaging task title")
    description: str = Field(..., description="Task description")
    estimated_time: int = Field(..., description="Estimated completion time")
    task_type: str = Field(..., description="Type of task")
    course_tags: List[str] = Field(default_factory=list)
    topic_tags: List[str] = Field(default_factory=list)

    # Scoring information
    interest_score: Optional[float] = Field(default=None, description="Interest match score")
    catchup_score: Optional[float] = Field(default=None, description="Catch-up priority score")
    final_score: Optional[float] = Field(default=None, description="Combined recommendation score")

    # LLM-generated personalization
    reasoning: str = Field(..., description="Why this task is recommended")
    urgency_level: Optional[str] = Field(default=None, description="low, medium, high")

    # Metadata
    difficulty_level: Optional[str] = Field(default="medium")
    prerequisites_met: Optional[bool] = Field(default=True)

class TaskFeedbackCreate(BaseModel):
    """Model for creating task feedback."""
    user_id: str
    task_id: str
    rating: int = Field(..., ge=1, le=5)
    feedback_text: Optional[str] = None
    difficulty_rating: Optional[str] = Field(default=None, pattern="^(too_easy|just_right|too_hard)$")
    time_taken: Optional[int] = Field(default=None, ge=0)

class RecommendationFeedback(BaseModel):
    """Model for feedback on recommendations."""
    user_id: str
    task_id: str
    was_clicked: bool = False
    was_completed: bool = False
    completion_time: Optional[int] = None
    user_rating: Optional[int] = Field(default=None, ge=1, le=5)

class AnalyticsResponse(BaseModel):
    """Model for analytics data."""
    total_tasks: int
    total_users: int
    total_recommendations: int
    avg_completion_rate: float
    popular_topics: List[Dict[str, Any]]
    task_type_distribution: Dict[str, int]
    difficulty_distribution: Dict[str, int]
    avg_task_rating: Optional[float] = None

class DebugRecommendationResponse(BaseModel):
    """Model for debugging recommendation pipeline."""
    user_context: Dict[str, Any]
    time_filtered_tasks: List[Dict[str, Any]]
    candidate_tasks: List[Dict[str, Any]]
    scoring_breakdown: Dict[str, Any]
    llm_prompt: str
    llm_response: str
    final_recommendations: List[RecommendationResponse]
    processing_time_ms: float

# ==================== CONFIGURATION MODELS ====================

class RAGConfig(BaseModel):
    """Configuration for RAG engine."""
    embedding_model: str = "all-MiniLM-L6-v2"
    max_candidates: int = 20
    alpha_interest: float = 0.4  # Weight for interest score
    beta_catchup: float = 0.6    # Weight for catch-up score
    llm_max_tokens: int = 500
    llm_temperature: float = 0.7
    use_free_llm: bool = True    # Use free Hugging Face models instead of paid APIs

class SystemConfig(BaseModel):
    """System configuration."""
    max_recommendations: int = 3
    min_task_time: int = 5      # Minimum task time in minutes
    max_task_time: int = 120    # Maximum task time in minutes
    default_difficulty: str = "medium"
    supported_task_types: List[str] = [
        "quiz", "video", "reading", "flashcards", 
        "coding", "writing", "practice", "project"
    ]
    supported_difficulties: List[str] = ["easy", "medium", "hard"]

print("✅ Pydantic models created!")
