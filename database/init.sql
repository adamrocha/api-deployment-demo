-- Initialize the database for API deployment demo
-- This script uses the POSTGRES_DB environment variable set by docker-compose.yml or Kubernetes
-- The database is already created by PostgreSQL using POSTGRES_DB, so we just connect to it

-- Connect to the database (database name comes from POSTGRES_DB environment variable)
-- In docker-entrypoint-initdb.d scripts, the POSTGRES_DB database is already created

-- Create a sample table (this will also be created by SQLAlchemy, but included for reference)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create an index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Insert some sample data
INSERT INTO users (name, email) VALUES 
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com'),
    ('Bob Johnson', 'bob.johnson@example.com')
ON CONFLICT (email) DO NOTHING;