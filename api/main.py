from fastapi import FastAPI, Depends, HTTPException, Request, Response
from fastapi.responses import PlainTextResponse
from sqlalchemy import create_engine, Column, Integer, String, DateTime, func, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime, timedelta
import os
import time
import psutil
from dotenv import load_dotenv
from prometheus_client import Counter, Histogram, Gauge, Summary, generate_latest, CONTENT_TYPE_LATEST, Info

# Load environment variables
load_dotenv()

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL"
)
if not DATABASE_URL:
    # Construct DATABASE_URL from individual components
    postgres_user = os.getenv("DB_USER", "postgres")
    postgres_password = os.getenv("DB_PASSWORD")
    if not postgres_password:
        raise ValueError("DB_PASSWORD environment variable is required")
    postgres_host = os.getenv("DB_HOST", "localhost")
    postgres_port = os.getenv("DB_PORT", "5432")
    postgres_db = os.getenv("DB_NAME", "api_db")
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

# ============================================================================
# Enhanced Prometheus Metrics - Business & Performance Insights
# ============================================================================

# Request Metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0]
)

http_request_size_bytes = Histogram(
    'http_request_size_bytes',
    'HTTP request size in bytes',
    ['method', 'endpoint'],
    buckets=[100, 1000, 10000, 100000, 1000000]
)

http_response_size_bytes = Histogram(
    'http_response_size_bytes',
    'HTTP response size in bytes',
    ['method', 'endpoint'],
    buckets=[100, 1000, 10000, 100000, 1000000]
)

# Error Tracking
http_errors_total = Counter(
    'http_errors_total',
    'Total HTTP errors',
    ['method', 'endpoint', 'error_type', 'status_code']
)

http_exceptions_total = Counter(
    'http_exceptions_total',
    'Total exceptions raised',
    ['exception_type', 'endpoint']
)

# Business Metrics
active_users_gauge = Gauge(
    'active_users_total',
    'Total number of users in the database'
)

user_registrations_total = Counter(
    'user_registrations_total',
    'Total number of user registrations'
)

user_deletions_total = Counter(
    'user_deletions_total',
    'Total number of user deletions'
)

users_created_last_hour = Gauge(
    'users_created_last_hour',
    'Number of users created in the last hour'
)

users_created_last_day = Gauge(
    'users_created_last_day',
    'Number of users created in the last 24 hours'
)

# Database Performance
database_connections_gauge = Gauge(
    'database_connections_active',
    'Number of active database connections'
)

database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query execution time',
    ['query_type'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

database_pool_size = Gauge(
    'database_pool_size',
    'Database connection pool size'
)

database_pool_overflow = Gauge(
    'database_pool_overflow',
    'Database connection pool overflow count'
)

database_errors_total = Counter(
    'database_errors_total',
    'Total database errors',
    ['error_type']
)

# System Resource Metrics
api_memory_usage_bytes = Gauge(
    'api_memory_usage_bytes',
    'Memory usage of the API process in bytes'
)

api_cpu_usage_percent = Gauge(
    'api_cpu_usage_percent',
    'CPU usage percentage of the API process'
)

api_open_file_descriptors = Gauge(
    'api_open_file_descriptors',
    'Number of open file descriptors'
)

# Application Info
api_info = Info(
    'api_application',
    'API application information'
)

# Set application info
api_info.info({
    'version': '1.0.0',
    'python_version': os.sys.version.split()[0],
    'environment': os.getenv('API_ENV', 'unknown')
})

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
    
    # Sanitize database URL to remove credentials
    db_status = "connected"
    if DATABASE_URL:
        # Extract only the database name, hide all connection details
        try:
            db_name = DATABASE_URL.split('/')[-1].split('?')[0]
            db_status = f"connected to {db_name}"
        except Exception:
            db_status = "connected"
    
    return {
        "status": "healthy", 
        "timestamp": datetime.utcnow(),
        "environment": environment,
        "deployment": deployment_type,
        "database": db_status
    }

@app.get("/metrics", response_class=PlainTextResponse)
async def metrics(db: Session = Depends(get_db)):
    """Enhanced metrics endpoint with comprehensive system and business data"""
    try:
        # Update user metrics
        start_time = time.time()
        user_count = db.query(User).count()
        active_users_gauge.set(user_count)
        database_query_duration_seconds.labels(query_type='count').observe(time.time() - start_time)
        
        # Users created in last hour
        start_time = time.time()
        one_hour_ago = datetime.utcnow().replace(microsecond=0).replace(second=0, minute=0) - timedelta(hours=1)
        users_last_hour = db.query(User).filter(User.created_at >= one_hour_ago).count()
        users_created_last_hour.set(users_last_hour)
        database_query_duration_seconds.labels(query_type='time_range').observe(time.time() - start_time)
        
        # Users created in last 24 hours
        start_time = time.time()
        one_day_ago = datetime.utcnow() - timedelta(days=1)
        users_last_day = db.query(User).filter(User.created_at >= one_day_ago).count()
        users_created_last_day.set(users_last_day)
        database_query_duration_seconds.labels(query_type='time_range').observe(time.time() - start_time)
        
        # Database connection pool metrics
        pool = engine.pool
        database_pool_size.set(pool.size())
        database_pool_overflow.set(pool.overflow())
        
        # Database connection count (actual active connections)
        try:
            result = db.execute(text("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()"))
            db_connections = result.scalar()
            database_connections_gauge.set(db_connections or 0)
        except Exception as e:
            database_connections_gauge.set(0)
            database_errors_total.labels(error_type='connection_query').inc()
        
        # System resource metrics
        process = psutil.Process()
        api_memory_usage_bytes.set(process.memory_info().rss)
        api_cpu_usage_percent.set(process.cpu_percent(interval=0.1))
        
        try:
            api_open_file_descriptors.set(process.num_fds())
        except AttributeError:
            # num_fds() not available on all platforms
            pass
            
    except Exception as e:
        database_errors_total.labels(error_type='metrics_collection').inc()
    
    return generate_latest()

@app.post("/users", response_model=UserResponse)
async def create_user(user: UserCreate, request: Request, db: Session = Depends(get_db)):
    start_time = time.time()
    
    try:
        # Track request size
        content_length = request.headers.get('content-length', 0)
        http_request_size_bytes.labels(method='POST', endpoint='/users').observe(int(content_length) if content_length else 0)
        
        # Check if user already exists
        db_start = time.time()
        existing_user = db.query(User).filter(User.email == user.email).first()
        database_query_duration_seconds.labels(query_type='select').observe(time.time() - db_start)
        
        if existing_user:
            http_errors_total.labels(method='POST', endpoint='/users', error_type='duplicate', status_code='400').inc()
            http_requests_total.labels(method='POST', endpoint='/users', status='400').inc()
            raise HTTPException(status_code=400, detail="Email already registered")
        
        # Create user
        db_start = time.time()
        db_user = User(name=user.name, email=user.email)
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        database_query_duration_seconds.labels(query_type='insert').observe(time.time() - db_start)
        
        # Track business metrics
        user_registrations_total.inc()
        http_requests_total.labels(method='POST', endpoint='/users', status='200').inc()
        http_request_duration_seconds.labels(method='POST', endpoint='/users').observe(time.time() - start_time)
        
        return db_user
        
    except HTTPException:
        raise
    except Exception as e:
        database_errors_total.labels(error_type='create_user').inc()
        http_exceptions_total.labels(exception_type=type(e).__name__, endpoint='/users').inc()
        http_requests_total.labels(method='POST', endpoint='/users', status='500').inc()
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/users", response_model=list[UserResponse])
async def get_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    start_time = time.time()
    
    try:
        db_start = time.time()
        users = db.query(User).offset(skip).limit(limit).all()
        database_query_duration_seconds.labels(query_type='select').observe(time.time() - db_start)
        
        http_requests_total.labels(method='GET', endpoint='/users', status='200').inc()
        http_request_duration_seconds.labels(method='GET', endpoint='/users').observe(time.time() - start_time)
        
        return users
        
    except Exception as e:
        database_errors_total.labels(error_type='get_users').inc()
        http_exceptions_total.labels(exception_type=type(e).__name__, endpoint='/users').inc()
    start_time = time.time()
    
    try:
        db_start = time.time()
        user = db.query(User).filter(User.id == user_id).first()
        database_query_duration_seconds.labels(query_type='select').observe(time.time() - db_start)
        
        if user is None:
            http_errors_total.labels(method='DELETE', endpoint='/users/{id}', error_type='not_found', status_code='404').inc()
            http_requests_total.labels(method='DELETE', endpoint='/users/{id}', status='404').inc()
            raise HTTPException(status_code=404, detail="User not found")
        
        db_start = time.time()
        db.delete(user)
        db.commit()
        database_query_duration_seconds.labels(query_type='delete').observe(time.time() - db_start)
        
        # Track business metrics
        user_deletions_total.inc()
        http_requests_total.labels(method='DELETE', endpoint='/users/{id}', status='200').inc()
        http_request_duration_seconds.labels(method='DELETE', endpoint='/users/{id}').observe(time.time() - start_time)
        
        return {"message": "User deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        database_errors_total.labels(error_type='delete_user').inc()
        http_exceptions_total.labels(exception_type=type(e).__name__, endpoint='/users/{id}').inc()
        http_requests_total.labels(method='DELETE', endpoint='/users/{id}', status='500').inc()
        raise HTTPException(status_code=500, detail="Internal server error")
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