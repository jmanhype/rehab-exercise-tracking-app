-- Database initialization script for Rehab Exercise Tracking System
-- This script sets up the required databases and extensions

-- Create the main application database
CREATE DATABASE rehab_tracking_dev;
CREATE DATABASE rehab_tracking_test;
CREATE DATABASE rehab_tracking_prod;

-- Create the EventStore databases
CREATE DATABASE rehab_eventstore_dev;
CREATE DATABASE rehab_eventstore_test;  
CREATE DATABASE rehab_eventstore_prod;

-- Connect to the main database and create extensions
\c rehab_tracking_dev;

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create indexes for better performance
-- These will be used by Ecto migrations later

-- Connect to EventStore database and set it up
\c rehab_eventstore_dev;

-- Enable required extensions for EventStore
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- EventStore tables will be created by the EventStore initialization
-- This is just to ensure the database has the required extensions

-- Set up similar extensions for test databases
\c rehab_tracking_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

\c rehab_eventstore_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set up similar extensions for prod databases
\c rehab_tracking_prod;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

\c rehab_eventstore_prod;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create application-specific database objects
\c rehab_tracking_dev;

-- Create enum types that will be used by the application
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exercise_type') THEN
        CREATE TYPE exercise_type AS ENUM ('strength', 'flexibility', 'balance', 'cardio', 'coordination');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quality_score') THEN
        CREATE TYPE quality_score AS ENUM ('poor', 'fair', 'good', 'excellent');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alert_severity') THEN
        CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
    END IF;
END$$;

-- Create the same enums for test and prod databases
\c rehab_tracking_test;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exercise_type') THEN
        CREATE TYPE exercise_type AS ENUM ('strength', 'flexibility', 'balance', 'cardio', 'coordination');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quality_score') THEN
        CREATE TYPE quality_score AS ENUM ('poor', 'fair', 'good', 'excellent');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alert_severity') THEN
        CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
    END IF;
END$$;

\c rehab_tracking_prod;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exercise_type') THEN
        CREATE TYPE exercise_type AS ENUM ('strength', 'flexibility', 'balance', 'cardio', 'coordination');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quality_score') THEN
        CREATE TYPE quality_score AS ENUM ('poor', 'fair', 'good', 'excellent');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alert_severity') THEN
        CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
    END IF;
END$$;

-- Grant necessary permissions
-- These will be refined by application migrations

GRANT ALL PRIVILEGES ON DATABASE rehab_tracking_dev TO postgres;
GRANT ALL PRIVILEGES ON DATABASE rehab_tracking_test TO postgres;
GRANT ALL PRIVILEGES ON DATABASE rehab_tracking_prod TO postgres;
GRANT ALL PRIVILEGES ON DATABASE rehab_eventstore_dev TO postgres;
GRANT ALL PRIVILEGES ON DATABASE rehab_eventstore_test TO postgres;
GRANT ALL PRIVILEGES ON DATABASE rehab_eventstore_prod TO postgres;