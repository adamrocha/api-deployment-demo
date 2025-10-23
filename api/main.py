from fastapi import FastAPI, Depends, HTTPException, Request, Response
from fastapi.responses import PlainTextResponse
from sqlalchemy import create_engine, Column, Integer, String, DateTime, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
import os
import time
from dotenv import load_dotenv
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# Load environment variables
load_dotenv()

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL"
)
if not DATABASE_URL:
    # Construct DATABASE_URL from individual components
    postgres_user = os.getenv("POSTGRES_USER", "postgres")
    postgres_password = os.getenv("POSTGRES_PASSWORD")
    if not postgres_password:
        raise ValueError("POSTGRES_PASSWORD environment variable is required")
    postgres_host = os.getenv("POSTGRES_HOST", "localhost")
    postgres_port = os.getenv("POSTGRES_PORT", "5432")
    postgres_db = os.getenv("POSTGRES_DB", "api_db")
    DATABASE_URL = f"postgresql://{postgres_user}:{postgres_password}@{postgres_host}:{postgres_port}/{postgres_db}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=func.now())

# Pydantic Models
class UserCreate(BaseModel):
    name: str
    email: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: datetime
    
    class Config:
        from_attributes = True

# Prometheus metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

active_users_gauge = Gauge(
    'active_users_total',
    'Total number of users in the database'
)

database_connections_gauge = Gauge(
    'database_connections_active',
    'Number of active database connections'
)

# FastAPI app
app = FastAPI(
    title="API Deployment Demo",
    description="A sample API deployed with Docker, PostgreSQL, and Nginx",
    version="1.0.0"
)

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Routes
@app.get("/")
async def root():
    start_time = time.time()
    http_requests_total.labels(method='GET', endpoint='/', status='200').inc()
    result = {"message": "Welcome to API Deployment Demo", "status": "healthy"}
    http_request_duration_seconds.labels(method='GET', endpoint='/').observe(time.time() - start_time)
    return result

@app.get("/health")
async def health_check():
    # Detect environment based on available environment variables
    environment = "production"
    deployment_type = "unknown"
    
    # Check for Kubernetes environment
    if os.getenv("KUBERNETES_SERVICE_HOST"):
        environment = "kubernetes"
        deployment_type = "k8s"
    # Check for Docker Compose environment
    elif os.getenv("API_ENV") == "staging":
        environment = "staging"
        deployment_type = "docker-compose"
    # Check for local development
    elif "localhost" in DATABASE_URL or "127.0.0.1" in DATABASE_URL:
        environment = "local"
        deployment_type = "development"
    
    return {
        "status": "healthy", 
        "timestamp": datetime.utcnow(),
        "environment": environment,
        "deployment": deployment_type,
        "database_url": DATABASE_URL.replace(DATABASE_URL.split('@')[0].split('//')[1], "***:***") if '@' in DATABASE_URL else "configured"
    }

@app.get("/metrics", response_class=PlainTextResponse)
async def metrics(db: Session = Depends(get_db)):
    # Update gauges with current values
    user_count = db.query(User).count()
    active_users_gauge.set(user_count)
    
    # Note: In a real application, you'd get actual connection count from the database
    database_connections_gauge.set(1)  # Simplified for demo
    
    return generate_latest()

@app.post("/users/", response_model=UserResponse)
async def create_user(user: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    db_user = User(name=user.name, email=user.email)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.get("/users", response_model=list[UserResponse])
async def get_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    start_time = time.time()
    http_requests_total.labels(method='GET', endpoint='/users', status='200').inc()
    users = db.query(User).offset(skip).limit(limit).all()
    http_request_duration_seconds.labels(method='GET', endpoint='/users').observe(time.time() - start_time)
    return users

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.delete("/users/{user_id}")
async def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    db.delete(user)
    db.commit()
    return {"message": "User deleted successfully"}

@app.get("/products")
async def get_products():
    """Simple products endpoint for demo purposes"""
    start_time = time.time()
    http_requests_total.labels(method='GET', endpoint='/products', status='200').inc()
    result = [
        {"id": 1, "name": "Product A", "price": 29.99},
        {"id": 2, "name": "Product B", "price": 49.99},
        {"id": 3, "name": "Product C", "price": 19.99},
    ]
    http_request_duration_seconds.labels(method='GET', endpoint='/products').observe(time.time() - start_time)
    return result

# Create tables
@app.on_event("startup")
async def startup_event():
    Base.metadata.create_all(bind=engine)