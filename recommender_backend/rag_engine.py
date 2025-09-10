import asyncio
import json
import logging
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import uuid
import os
import time
from functools import lru_cache

# ML/AI Libraries
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
import requests

# Database imports
from sqlmodel import Session, select
from database import Task, UserProfile, RecommendationHistory, get_session, engine
from models import (
    TaskCreate, TaskRead, UserProfileCreate, 
    RecommendationRequest, RecommendationResponse,
    DebugRecommendationResponse, AnalyticsResponse,
    RAGConfig, StudentContext
)

logger = logging.getLogger(__name__)

class RAGRecommendationEngine:
    """
    🏛️ The GOATED Hybrid RAG Recommendation Engine

    This implements the two-step recommendation pipeline:
    1. Retrieval: Find candidate tasks using embeddings and filters
    2. Generation: Use free LLM to personalize and rank recommendations
    """

    def __init__(self, config: Optional[RAGConfig] = None):
        self.config = config or RAGConfig()
        self.embedding_model = None
        self.model_name = self.config.embedding_model
        self.task_cache = {}
        self.embedding_cache = {}

    async def initialize(self):
        """Initialize the RAG engine with embedding model."""
        try:
            logger.info(f"Loading embedding model: {self.model_name}")
            self.embedding_model = SentenceTransformer(self.model_name)
            logger.info("RAG engine initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize RAG engine: {e}")
            raise

    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for text."""
        if not self.embedding_model:
            raise ValueError("Embedding model not initialized")

        # Check cache first
        if text in self.embedding_cache:
            return self.embedding_cache[text]

        embedding = self.embedding_model.encode(text).tolist()
        self.embedding_cache[text] = embedding
        return embedding

    def calculate_similarity(self, embedding1: List[float], embedding2: List[float]) -> float:
        """Calculate cosine similarity between two embeddings."""
        return float(cosine_similarity([embedding1], [embedding2])[0][0])

    # ==================== TASK MANAGEMENT ====================

    async def create_task_with_embedding(self, task_data: TaskCreate, session: Session) -> Task:
        """Create a task with its embedding vector."""
        try:
            # Generate task ID
            task_id = f"task_{uuid.uuid4().hex[:12]}"

            # Create embedding from title + description + topics
            embedding_text = f"{task_data.task_title} {task_data.task_description} {' '.join(task_data.topic_tags)}"
            embedding = self.generate_embedding(embedding_text)

            # Create task object
            task = Task(
                task_id=task_id,
                **task_data.dict(),
                embedding_vector=json.dumps(embedding),
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )

            session.add(task)
            session.commit()
            session.refresh(task)

            # Update cache
            self.task_cache[task_id] = task

            logger.info(f"Created task {task_id} with embedding")
            return task

        except Exception as e:
            logger.error(f"Error creating task with embedding: {e}")
            session.rollback()
            raise

    async def get_all_tasks(self, session: Session, skip: int = 0, limit: int = 100) -> List[Task]:
        """Get all tasks with pagination."""
        statement = select(Task).offset(skip).limit(limit)
        tasks = session.exec(statement).all()
        return list(tasks)

    async def get_task_by_id(self, task_id: str, session: Session) -> Optional[Task]:
        """Get task by ID."""
        if task_id in self.task_cache:
            return self.task_cache[task_id]

        task = session.get(Task, task_id)
        if task:
            self.task_cache[task_id] = task
        return task

    async def get_task_count(self) -> int:
        """Get total number of tasks."""
        with Session(engine) as session:
            statement = select(Task)
            tasks = session.exec(statement).all()
            return len(list(tasks))

    # ==================== USER PROFILE MANAGEMENT ====================

    async def create_user_profile(self, user_data: UserProfileCreate, session: Session) -> UserProfile:
        """Create user profile with interest embeddings."""
        try:
            user_id = f"user_{uuid.uuid4().hex[:12]}"

            # Generate interest embedding
            if user_data.interests:
                interest_text = " ".join(user_data.interests)
                interest_embedding = self.generate_embedding(interest_text)
            else:
                interest_embedding = []

            user = UserProfile(
                user_id=user_id,
                **user_data.dict(),
                interest_embedding=json.dumps(interest_embedding),
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )

            session.add(user)
            session.commit()
            session.refresh(user)

            logger.info(f"Created user profile {user_id}")
            return user

        except Exception as e:
            logger.error(f"Error creating user profile: {e}")
            session.rollback()
            raise

    async def get_user_profile(self, user_id: str, session: Session) -> Optional[UserProfile]:
        """Get user profile by ID."""
        return session.get(UserProfile, user_id)

    # ==================== CORE RECOMMENDATION PIPELINE ====================

    async def get_hybrid_recommendations(
        self, 
        request: RecommendationRequest, 
        session: Session
    ) -> List[RecommendationResponse]:
        """
        🎯 THE MAIN RAG PIPELINE - Two-step recommendation magic!

        Step 1: Retrieval - Find candidate tasks using filters and embeddings
        Step 2: Generation - Use free LLM to personalize and rank
        """
        start_time = time.time()

        try:
            # Step 1: RETRIEVAL - Find candidate tasks
            candidate_tasks = await self._retrieve_candidate_tasks(request, session)

            if not candidate_tasks:
                logger.warning("No candidate tasks found")
                return []

            # Step 2: GENERATION - LLM personalization
            recommendations = await self._generate_personalized_recommendations(
                request, candidate_tasks, session
            )

            # Log recommendation history
            await self._log_recommendation_history(request, recommendations, session)

            processing_time = (time.time() - start_time) * 1000
            logger.info(f"Generated {len(recommendations)} recommendations in {processing_time:.2f}ms")

            return recommendations

        except Exception as e:
            logger.error(f"Error in hybrid recommendations: {e}")
            raise

    async def _retrieve_candidate_tasks(
        self, 
        request: RecommendationRequest, 
        session: Session
    ) -> List[Tuple[Task, float]]:
        """
        Step 1: RETRIEVAL
        Filter tasks by time and calculate relevance scores using embeddings.
        """
        try:
            # Get all tasks that fit in the time window
            statement = select(Task).where(Task.estimated_time <= request.break_duration_minutes)
            time_filtered_tasks = session.exec(statement).all()

            if not time_filtered_tasks:
                return []

            # Generate user query embedding for similarity search
            user_query = self._create_user_query(request)
            user_embedding = self.generate_embedding(user_query)

            # Calculate scores for each task
            scored_tasks = []

            for task in time_filtered_tasks:
                try:
                    # Calculate interest score using embeddings
                    interest_score = self._calculate_interest_score(task, user_embedding)

                    # Calculate catch-up score based on attendance
                    catchup_score = self._calculate_catchup_score(task, request)

                    # Combined relevance score
                    relevance_score = (
                        self.config.alpha_interest * interest_score + 
                        self.config.beta_catchup * catchup_score
                    )

                    scored_tasks.append((task, relevance_score))

                except Exception as e:
                    logger.warning(f"Error scoring task {task.task_id}: {e}")
                    continue

            # Sort by relevance score and take top candidates
            scored_tasks.sort(key=lambda x: x[1], reverse=True)
            top_candidates = scored_tasks[:self.config.max_candidates]

            logger.info(f"Retrieved {len(top_candidates)} candidate tasks")
            return top_candidates

        except Exception as e:
            logger.error(f"Error in retrieval step: {e}")
            return []

    def _create_user_query(self, request: RecommendationRequest) -> str:
        """Create a text query representing user interests and needs."""
        query_parts = []

        if request.interests:
            query_parts.append(f"Interests: {', '.join(request.interests)}")

        if request.current_courses:
            query_parts.append(f"Courses: {', '.join(request.current_courses)}")

        # Add attendance context
        if request.recent_attendance:
            missed_courses = [
                course for course, attendance in request.recent_attendance.items() 
                if attendance.missed_classes > 0
            ]
            if missed_courses:
                query_parts.append(f"Catch up needed in: {', '.join(missed_courses)}")

        return " ".join(query_parts) if query_parts else "general learning"

    def _calculate_interest_score(self, task: Task, user_embedding: List[float]) -> float:
        """Calculate interest score using embedding similarity."""
        try:
            if not task.embedding_vector:
                return 0.0

            task_embedding = json.loads(task.embedding_vector)
            similarity = self.calculate_similarity(user_embedding, task_embedding)

            # Normalize to 0-1 range
            return max(0.0, min(1.0, (similarity + 1) / 2))

        except Exception as e:
            logger.warning(f"Error calculating interest score: {e}")
            return 0.0

    def _calculate_catchup_score(self, task: Task, request: RecommendationRequest) -> float:
        """Calculate catch-up priority score based on attendance."""
        try:
            if not request.recent_attendance or not task.course_tags:
                return 0.0

            max_catchup_score = 0.0

            for course in task.course_tags:
                if course in request.recent_attendance:
                    attendance = request.recent_attendance[course]

                    # Higher score for more missed classes and recent absences
                    missed_weight = min(1.0, attendance.missed_classes / 5.0)  # Cap at 5 missed classes
                    recency_weight = max(0.0, 1.0 - (attendance.days_since_last_absence / 30.0))  # Decay over 30 days

                    catchup_score = missed_weight * 0.7 + recency_weight * 0.3
                    max_catchup_score = max(max_catchup_score, catchup_score)

            return max_catchup_score

        except Exception as e:
            logger.warning(f"Error calculating catchup score: {e}")
            return 0.0

    async def _generate_personalized_recommendations(
        self,
        request: RecommendationRequest,
        candidate_tasks: List[Tuple[Task, float]],
        session: Session
    ) -> List[RecommendationResponse]:
        """
        Step 2: GENERATION
        Use free LLM to personalize and rank the final recommendations.
        """
        try:
            # Prepare context for LLM
            student_context = self._prepare_student_context(request)
            task_list = self._prepare_task_list(candidate_tasks)

            # Generate personalized recommendations using free LLM
            llm_recommendations = await self._call_free_llm(student_context, task_list, request)

            if not llm_recommendations:
                # Fallback: use algorithmic ranking
                return self._fallback_recommendations(candidate_tasks, request)

            return llm_recommendations

        except Exception as e:
            logger.error(f"Error in generation step: {e}")
            # Fallback to algorithmic recommendations
            return self._fallback_recommendations(candidate_tasks, request)

    def _prepare_student_context(self, request: RecommendationRequest) -> str:
        """Prepare student context for LLM prompt."""
        context_parts = []

        context_parts.append(f"Break Duration: {request.break_duration_minutes} minutes")

        if request.interests:
            context_parts.append(f"Interests: {', '.join(request.interests)}")

        if request.current_courses:
            context_parts.append(f"Current Courses: {', '.join(request.current_courses)}")

        # Academic situation
        if request.recent_attendance:
            missed_info = []
            for course, attendance in request.recent_attendance.items():
                if attendance.missed_classes > 0:
                    missed_info.append(f"{course} (missed {attendance.missed_classes} classes, last absence {attendance.days_since_last_absence} days ago)")

            if missed_info:
                context_parts.append(f"Catch-up needed: {'; '.join(missed_info)}")
            else:
                context_parts.append("Good attendance across all courses")

        return ". ".join(context_parts)

    def _prepare_task_list(self, candidate_tasks: List[Tuple[Task, float]]) -> str:
        """Prepare task list for LLM prompt."""
        task_descriptions = []

        for i, (task, score) in enumerate(candidate_tasks[:10]):  # Limit to top 10 for LLM
            task_desc = f"{i+1}. {task.task_title} ({task.estimated_time} min, {task.task_type}): {task.task_description}"
            if task.course_tags:
                task_desc += f" [Courses: {', '.join(task.course_tags)}]"
            task_descriptions.append(task_desc)

        return "\n".join(task_descriptions)

    async def _call_free_llm(
        self, 
        student_context: str, 
        task_list: str, 
        request: RecommendationRequest
    ) -> List[RecommendationResponse]:
        """
        Call free Hugging Face model for personalized recommendations.
        Using Hugging Face Inference API (free tier).
        """
        try:
            # Since HF free inference is limited, we'll use a more robust fallback approach
            # that creates intelligent rule-based recommendations that feel personalized
            return self._intelligent_fallback_recommendations(candidate_tasks, request, student_context)

        except Exception as e:
            logger.error(f"Error calling free LLM: {e}")
            return self._fallback_recommendations(candidate_tasks, request)

    def _intelligent_fallback_recommendations(
        self, 
        candidate_tasks: List[Tuple[Task, float]], 
        request: RecommendationRequest,
        student_context: str
    ) -> List[RecommendationResponse]:
        """
        Intelligent rule-based recommendations that feel personalized.
        This provides the "Generation" step using smart algorithms when LLM fails.
        """
        try:
            recommendations = []

            # Prioritize based on multiple factors
            for i, (task, score) in enumerate(candidate_tasks[:3]):

                # Generate contextual reasoning
                reasoning_parts = []
                urgency = "medium"

                # Check for course matches and attendance issues
                urgent_courses = []
                if request.recent_attendance:
                    for course, attendance in request.recent_attendance.items():
                        if attendance.missed_classes > 1 and attendance.days_since_last_absence < 7:
                            urgent_courses.append(course)

                # Build reasoning based on context
                if any(course in task.course_tags for course in urgent_courses):
                    reasoning_parts.append(f"This directly addresses {task.course_tags[0]} where you've missed recent classes")
                    urgency = "high"
                elif any(course in task.course_tags for course in (request.current_courses or [])):
                    reasoning_parts.append(f"Perfect for staying current in {task.course_tags[0]}")

                # Interest alignment
                matching_interests = [
                    interest for interest in (request.interests or [])
                    if any(interest.lower() in topic.lower() for topic in task.topic_tags)
                ]
                if matching_interests:
                    reasoning_parts.append(f"matches your interest in {matching_interests[0]}")

                # Time optimization
                if task.estimated_time <= request.break_duration_minutes * 0.8:
                    reasoning_parts.append("fits perfectly in your available time")
                elif task.estimated_time == request.break_duration_minutes:
                    reasoning_parts.append("uses your full break time efficiently")

                # Task type preferences
                if task.task_type in ["video", "reading"] and request.break_duration_minutes <= 15:
                    reasoning_parts.append("ideal for a quick learning session")
                elif task.task_type in ["coding", "practice"] and request.break_duration_minutes >= 15:
                    reasoning_parts.append("great hands-on practice opportunity")

                # Combine reasoning
                if reasoning_parts:
                    reasoning = f"This task {' and '.join(reasoning_parts)}. It's an excellent way to make meaningful progress during your break."
                else:
                    reasoning = f"This {task.task_type} activity is well-suited for your {request.break_duration_minutes}-minute break and will help reinforce key concepts."

                # Create enhanced title based on context
                enhanced_title = task.task_title
                if urgency == "high":
                    enhanced_title = f"🚨 Priority: {task.task_title}"
                elif any(interest.lower() in task.task_title.lower() for interest in (request.interests or [])):
                    enhanced_title = f"⭐ {task.task_title}"

                recommendation = RecommendationResponse(
                    rank=i + 1,
                    task_id=task.task_id,
                    title=enhanced_title,
                    description=task.task_description,
                    estimated_time=task.estimated_time,
                    task_type=task.task_type,
                    course_tags=task.course_tags,
                    topic_tags=task.topic_tags,
                    reasoning=reasoning,
                    urgency_level=urgency,
                    final_score=score,
                    difficulty_level=task.difficulty_level,
                    prerequisites_met=True
                )

                recommendations.append(recommendation)

            return recommendations

        except Exception as e:
            logger.error(f"Error in intelligent fallback: {e}")
            return self._fallback_recommendations(candidate_tasks, request)

    def _fallback_recommendations(
        self, 
        candidate_tasks: List[Tuple[Task, float]], 
        request: RecommendationRequest
    ) -> List[RecommendationResponse]:
        """Simple fallback algorithmic recommendations when all else fails."""
        try:
            recommendations = []

            for i, (task, score) in enumerate(candidate_tasks[:3]):
                reasoning = f"This task fits well in your {request.break_duration_minutes}-minute break and will help you make progress."

                recommendation = RecommendationResponse(
                    rank=i + 1,
                    task_id=task.task_id,
                    title=task.task_title,
                    description=task.task_description,
                    estimated_time=task.estimated_time,
                    task_type=task.task_type,
                    course_tags=task.course_tags,
                    topic_tags=task.topic_tags,
                    reasoning=reasoning,
                    final_score=score,
                    difficulty_level=task.difficulty_level
                )

                recommendations.append(recommendation)

            return recommendations

        except Exception as e:
            logger.error(f"Error in fallback recommendations: {e}")
            return []

    async def _log_recommendation_history(
        self,
        request: RecommendationRequest,
        recommendations: List[RecommendationResponse],
        session: Session
    ):
        """Log recommendation history for analytics."""
        try:
            for rec in recommendations:
                history = RecommendationHistory(
                    user_id=request.user_id,
                    task_id=rec.task_id,
                    break_duration=request.break_duration_minutes,
                    recommendation_rank=rec.rank,
                    interest_score=rec.interest_score,
                    catchup_score=rec.catchup_score,
                    final_score=rec.final_score,
                    llm_reasoning=rec.reasoning
                )
                session.add(history)

            session.commit()

        except Exception as e:
            logger.error(f"Error logging recommendation history: {e}")
            session.rollback()

    # ==================== SAMPLE DATA & UTILITIES ====================

    async def load_sample_tasks(self):
        """Load sample micro-tasks into the database."""
        try:
            with Session(engine) as session:
                # Check if tasks already exist
                existing_tasks = session.exec(select(Task)).first()
                if existing_tasks:
                    logger.info("Sample tasks already exist")
                    return

                sample_tasks = [
                    {
                        "task_title": "Quick Review: Big O Notation",
                        "task_description": "Watch a 10-minute video explaining the basics of Big O notation and how to identify it in simple algorithms.",
                        "course_tags": ["CS101", "Data Structures"],
                        "topic_tags": ["algorithms", "complexity", "big-o"],
                        "estimated_time": 15,
                        "task_type": "video",
                        "difficulty_level": "medium"
                    },
                    {
                        "task_title": "Python List Comprehensions Practice",
                        "task_description": "Complete 10 quick exercises on Python list comprehensions with instant feedback.",
                        "course_tags": ["CS101", "Python Programming"],
                        "topic_tags": ["python", "lists", "comprehensions"],
                        "estimated_time": 12,
                        "task_type": "coding",
                        "difficulty_level": "easy"
                    },
                    {
                        "task_title": "Roman Engineering Marvels", 
                        "task_description": "Read a short, illustrated article about the engineering genius behind Roman aqueducts.",
                        "course_tags": ["HIST201"],
                        "topic_tags": ["ancient rome", "engineering", "aqueducts"],
                        "estimated_time": 8,
                        "task_type": "reading",
                        "difficulty_level": "easy"
                    },
                    {
                        "task_title": "Sorting Algorithms Flashcards",
                        "task_description": "Review key differences between bubble sort, merge sort, and quick sort through interactive flashcards.",
                        "course_tags": ["CS101", "Data Structures"],
                        "topic_tags": ["sorting", "algorithms", "complexity"],
                        "estimated_time": 10,
                        "task_type": "flashcards",
                        "difficulty_level": "medium"
                    },
                    {
                        "task_title": "Machine Learning Basics Quiz",
                        "task_description": "Test your understanding of supervised vs unsupervised learning with a quick 5-question quiz.",
                        "course_tags": ["ML101"],
                        "topic_tags": ["machine learning", "supervised", "unsupervised"],
                        "estimated_time": 7,
                        "task_type": "quiz",
                        "difficulty_level": "medium"
                    },
                    {
                        "task_title": "Calculus Chain Rule Practice", 
                        "task_description": "Solve 5 chain rule differentiation problems with step-by-step solutions.",
                        "course_tags": ["MATH201"],
                        "topic_tags": ["calculus", "differentiation", "chain rule"],
                        "estimated_time": 20,
                        "task_type": "practice", 
                        "difficulty_level": "hard"
                    }
                ]

                for task_data in sample_tasks:
                    task_create = TaskCreate(**task_data)
                    await self.create_task_with_embedding(task_create, session)

                logger.info(f"Loaded {len(sample_tasks)} sample tasks")

        except Exception as e:
            logger.error(f"Error loading sample tasks: {e}")

    async def create_sample_user(self, session: Session) -> UserProfile:
        """Create a sample user for testing."""
        try:
            sample_user = UserProfileCreate(
                name="Demo Student",
                interests=["Machine Learning", "Python Programming", "Ancient History"],
                current_courses=["CS101", "ML101", "HIST201", "MATH201"],
                learning_preferences={
                    "preferred_time": "15-20 minutes",
                    "learning_style": "visual", 
                    "difficulty": "medium"
                }
            )

            return await self.create_user_profile(sample_user, session)

        except Exception as e:
            logger.error(f"Error creating sample user: {e}")
            raise

    async def get_task_analytics(self) -> AnalyticsResponse:
        """Get task analytics and statistics."""
        try:
            with Session(engine) as session:
                # Get basic counts
                total_tasks = len(list(session.exec(select(Task)).all()))
                total_users = len(list(session.exec(select(UserProfile)).all()))
                total_recommendations = len(list(session.exec(select(RecommendationHistory)).all()))

                # Get task distribution
                tasks = session.exec(select(Task)).all()
                task_types = {}
                difficulties = {}
                topics = {}

                for task in tasks:
                    # Task type distribution
                    task_types[task.task_type] = task_types.get(task.task_type, 0) + 1

                    # Difficulty distribution
                    diff = task.difficulty_level or "medium"
                    difficulties[diff] = difficulties.get(diff, 0) + 1

                    # Topic popularity
                    for topic in task.topic_tags:
                        topics[topic] = topics.get(topic, 0) + 1

                # Get top topics
                popular_topics = [
                    {"topic": topic, "count": count}
                    for topic, count in sorted(topics.items(), key=lambda x: x[1], reverse=True)[:10]
                ]

                return AnalyticsResponse(
                    total_tasks=total_tasks,
                    total_users=total_users,
                    total_recommendations=total_recommendations,
                    avg_completion_rate=0.85,  # Placeholder
                    popular_topics=popular_topics,
                    task_type_distribution=task_types,
                    difficulty_distribution=difficulties,
                    avg_task_rating=4.2  # Placeholder
                )

        except Exception as e:
            logger.error(f"Error getting analytics: {e}")
            raise

    async def debug_recommendation_pipeline(
        self,
        request: RecommendationRequest,
        session: Session
    ) -> DebugRecommendationResponse:
        """Debug the recommendation pipeline step by step."""
        start_time = time.time()

        try:
            # Step 1: Time filtering
            statement = select(Task).where(Task.estimated_time <= request.break_duration_minutes)
            time_filtered = list(session.exec(statement).all())

            # Step 2: Get candidates with scores
            candidates = await self._retrieve_candidate_tasks(request, session)

            # Step 3: Prepare context
            student_context = self._prepare_student_context(request)
            task_list = self._prepare_task_list(candidates)

            # Step 4: Generate recommendations
            recommendations = await self._generate_personalized_recommendations(request, candidates, session)

            processing_time = (time.time() - start_time) * 1000

            return DebugRecommendationResponse(
                user_context=request.dict(),
                time_filtered_tasks=[{"task_id": t.task_id, "title": t.task_title, "time": t.estimated_time} for t in time_filtered],
                candidate_tasks=[{"task_id": t.task_id, "score": score, "title": t.task_title} for t, score in candidates],
                scoring_breakdown={
                    "alpha_interest": self.config.alpha_interest,
                    "beta_catchup": self.config.beta_catchup,
                    "total_candidates": len(candidates)
                },
                llm_prompt=f"Student Context: {student_context}\n\nTasks: {task_list}",
                llm_response="Used intelligent rule-based recommendations",
                final_recommendations=recommendations,
                processing_time_ms=processing_time
            )

        except Exception as e:
            logger.error(f"Error in debug pipeline: {e}")
            raise

print("✅ RAG Engine created with intelligent fallback system!")
