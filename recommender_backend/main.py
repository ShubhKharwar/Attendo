
from fastapi import Depends
from sqlmodel import Session
from typing import Annotated
from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import json
import logging
import os
from datetime import datetime
import uuid

# Import our custom modules
from database import get_session, create_db_and_tables, SessionDep
from models import (
    TaskCreate, TaskRead, 
    UserProfile, UserProfileCreate,
    RecommendationRequest, RecommendationResponse,
    StudentContext
)
from rag_engine import RAGRecommendationEngine

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Hybrid RAG Recommendation System",
    description="A GOATED recommendation system using Retrieval-Augmented Generation for educational micro-tasks",
    version="1.0.0",
    docs_url="/docs"
)

# Configure CORS for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # React dev
        "http://localhost:5173",  # Vite dev
        "https://*.onrender.com",  # Render deployment
        "https://*.netlify.app",   # Netlify deployment
        "https://*.vercel.app"     # Vercel deployment
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize RAG engine
rag_engine = None

@app.on_event("startup")
async def startup_event():
    """Initialize database and RAG engine on startup."""
    global rag_engine
    try:
        # Create database tables
        create_db_and_tables()
        logger.info("Database tables created successfully")

        # Initialize RAG recommendation engine
        rag_engine = RAGRecommendationEngine()
        await rag_engine.initialize()
        logger.info("RAG engine initialized successfully")

        # Load sample tasks if database is empty
        await rag_engine.load_sample_tasks()
        logger.info("Sample tasks loaded")

    except Exception as e:
        logger.error(f"Startup error: {e}")
        raise

# ==================== HEALTH CHECK ====================
@app.get("/", tags=["Health"])
async def root():
    """Health check endpoint."""
    return {
        "message": "🏛️ Hybrid RAG Recommendation System is running!",
        "version": "1.0.0",
        "status": "healthy",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health", tags=["Health"])
async def health_check():
    """Detailed health check."""
    global rag_engine
    return {
        "database": "connected",
        "rag_engine": "initialized" if rag_engine else "not_initialized",
        "embedding_model": rag_engine.model_name if rag_engine else None,
        "task_count": await rag_engine.get_task_count() if rag_engine else 0
    }

# ==================== TASK MANAGEMENT ====================
@app.post("/tasks/", response_model=TaskRead, tags=["Tasks"])
async def create_task(task: TaskCreate, session: SessionDep):
    """Create a new micro-task."""
    global rag_engine
    try:
        # Create task with embeddings
        task_obj = await rag_engine.create_task_with_embedding(task, session)
        return task_obj
    except Exception as e:
        logger.error(f"Error creating task: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks/", response_model=List[TaskRead], tags=["Tasks"])
async def get_tasks(
    session: SessionDep,
    skip: int = 0, 
    limit: int = 100, 
    
):
    """Get all tasks with pagination."""
    global rag_engine
    try:
        tasks = await rag_engine.get_all_tasks(session, skip=skip, limit=limit)
        return tasks
    except Exception as e:
        logger.error(f"Error fetching tasks: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks/{task_id}", response_model=TaskRead, tags=["Tasks"])
async def get_task(task_id: str, session: SessionDep):
    """Get a specific task by ID."""
    global rag_engine
    try:
        task = await rag_engine.get_task_by_id(task_id, session)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        return task
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching task {task_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== USER PROFILES ====================
@app.post("/users/", response_model=UserProfile, tags=["Users"])
async def create_user_profile(user: UserProfileCreate, session: SessionDep):
    """Create a new user profile."""
    global rag_engine
    try:
        user_obj = await rag_engine.create_user_profile(user, session)
        return user_obj
    except Exception as e:
        logger.error(f"Error creating user profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/users/{user_id}", response_model=UserProfile, tags=["Users"])
async def get_user_profile(user_id: str, session: SessionDep):
    """Get user profile by ID."""
    global rag_engine
    try:
        user = await rag_engine.get_user_profile(user_id, session)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== CORE RECOMMENDATION ENGINE ====================
@app.post("/recommendations/", response_model=List[RecommendationResponse], tags=["Recommendations"])
async def get_recommendations(
    request: RecommendationRequest, 
    session: SessionDep
):
    """
    🎯 THE GOATED ENDPOINT - Get personalized recommendations using Hybrid RAG!

    This is the main endpoint that implements the two-step magic:
    1. Retrieval: Find relevant candidate tasks from database
    2. Generation: Use LLM to personalize and rank recommendations
    """
    global rag_engine

    if not rag_engine:
        raise HTTPException(status_code=503, detail="RAG engine not initialized")

    try:
        logger.info(f"Processing recommendation request for user: {request.user_id}")

        # Execute the Hybrid RAG pipeline
        recommendations = await rag_engine.get_hybrid_recommendations(request, session)

        if not recommendations:
            logger.warning("No recommendations generated")
            return []

        logger.info(f"Generated {len(recommendations)} recommendations")
        return recommendations

    except Exception as e:
        logger.error(f"Error generating recommendations: {e}")
        raise HTTPException(status_code=500, detail=f"Recommendation error: {str(e)}")

@app.post("/recommendations/debug", tags=["Recommendations"])
async def debug_recommendations(
    request: RecommendationRequest, 
    session: SessionDep
):
    """Debug endpoint to see the recommendation pipeline in detail."""
    global rag_engine

    if not rag_engine:
        raise HTTPException(status_code=503, detail="RAG engine not initialized")

    try:
        # Get debug information
        debug_info = await rag_engine.debug_recommendation_pipeline(request, session)
        return debug_info

    except Exception as e:
        logger.error(f"Error in debug recommendations: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== SAMPLE DATA ENDPOINTS ====================
@app.post("/sample-data/load", tags=["Sample Data"])
async def load_sample_data(session: SessionDep):
    """Load sample tasks and user data for testing."""
    global rag_engine
    try:
        await rag_engine.load_sample_tasks()
        sample_user = await rag_engine.create_sample_user(session)

        return {
            "message": "Sample data loaded successfully",
            "sample_user_id": sample_user.user_id,
            "task_count": await rag_engine.get_task_count()
        }
    except Exception as e:
        logger.error(f"Error loading sample data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/sample-data/demo-request", tags=["Sample Data"])
async def get_demo_request():
    """Get a sample recommendation request for testing."""
    return {
        "user_id": "demo_user_123",
        "break_duration_minutes": 15,
        "current_courses": ["CS101", "MATH201"],
        "interests": ["Machine Learning", "Data Science", "Python"],
        "recent_attendance": {
            "CS101": {"missed_classes": 2, "days_since_last_absence": 1},
            "MATH201": {"missed_classes": 0, "days_since_last_absence": 30}
        }
    }

# ==================== ANALYTICS ENDPOINTS ====================
@app.get("/analytics/tasks", tags=["Analytics"])
async def get_task_analytics():
    """Get task analytics and statistics."""
    global rag_engine
    try:
        analytics = await rag_engine.get_task_analytics()
        return analytics
    except Exception as e:
        logger.error(f"Error getting task analytics: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== ERROR HANDLERS ====================
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler."""
    logger.error(f"Global error: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": "An unexpected error occurred. Please try again.",
            "timestamp": datetime.now().isoformat()
        }
    )

# ==================== MAIN ====================
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=False,  # Set to False in production
        log_level="info"
    )
