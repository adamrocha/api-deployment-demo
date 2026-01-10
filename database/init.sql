-- Initialize the database for API deployment demo
-- This script runs in the context of the database specified by POSTGRES_DB environment variable
-- PostgreSQL's docker-entrypoint-initdb.d automatically creates and connects to that database
-- before executing this script, so no explicit database creation or connection is needed

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