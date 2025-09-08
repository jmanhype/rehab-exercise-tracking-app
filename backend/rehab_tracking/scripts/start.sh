#!/bin/bash

# Docker startup script for Rehab Exercise Tracking System
# This script initializes the application inside a Docker container

set -e

echo "🚀 Starting Rehab Exercise Tracking System in Docker..."
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Environment variables with defaults
export MIX_ENV=${MIX_ENV:-prod}
export PORT=${PORT:-4000}
export PHX_SERVER=${PHX_SERVER:-true}

print_info "Environment: $MIX_ENV"
print_info "Port: $PORT"
print_info "Phoenix Server: $PHX_SERVER"

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    print_info "Waiting for PostgreSQL to be ready..."
    
    # Extract host and port from DATABASE_URL if available
    if [ ! -z "$DATABASE_URL" ]; then
        # Parse DATABASE_URL format: postgres://user:pass@host:port/db
        DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:]+):.*/\1/')
        DB_PORT=$(echo $DATABASE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')
    else
        # Use default host from environment or fallback
        DB_HOST=${DATABASE_HOST:-postgres}
        DB_PORT=${DATABASE_PORT:-5432}
    fi
    
    print_info "Checking PostgreSQL at $DB_HOST:$DB_PORT"
    
    # Wait up to 30 seconds for PostgreSQL
    for i in {1..30}; do
        if pg_isready -h $DB_HOST -p $DB_PORT -q; then
            print_status "PostgreSQL is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    print_error "PostgreSQL is not ready after 30 seconds"
    return 1
}

# Wait for EventStore database to be ready
wait_for_eventstore() {
    print_info "Waiting for EventStore database to be ready..."
    
    # Extract host and port from EVENTSTORE_URL if available
    if [ ! -z "$EVENTSTORE_URL" ]; then
        ES_HOST=$(echo $EVENTSTORE_URL | sed -E 's/.*@([^:]+):.*/\1/')
        ES_PORT=$(echo $EVENTSTORE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')
    else
        ES_HOST=${EVENTSTORE_HOST:-postgres}
        ES_PORT=${EVENTSTORE_PORT:-5432}
    fi
    
    print_info "Checking EventStore at $ES_HOST:$ES_PORT"
    
    # Wait up to 30 seconds for EventStore database
    for i in {1..30}; do
        if pg_isready -h $ES_HOST -p $ES_PORT -q; then
            print_status "EventStore database is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    print_warning "EventStore database check timed out, continuing anyway"
    return 0
}

# Initialize databases
init_databases() {
    print_info "Initializing databases..."
    
    # Create databases if they don't exist
    if mix ecto.create; then
        print_status "Main database created or already exists"
    else
        print_warning "Main database creation had issues (may already exist)"
    fi
    
    # Run migrations
    if mix ecto.migrate; then
        print_status "Database migrations completed"
    else
        print_error "Database migrations failed"
        return 1
    fi
    
    # Initialize EventStore
    if mix event_store.init; then
        print_status "EventStore initialized"
    else
        print_warning "EventStore initialization had issues (may already exist)"
    fi
}

# Compile application
compile_app() {
    print_info "Compiling application..."
    
    # Install dependencies if in development mode
    if [ "$MIX_ENV" = "dev" ]; then
        if mix deps.get; then
            print_status "Dependencies installed"
        else
            print_error "Failed to install dependencies"
            return 1
        fi
    fi
    
    # Compile the application
    if mix compile; then
        print_status "Application compiled successfully"
    else
        print_error "Application compilation failed"
        return 1
    fi
}

# Health check function
health_check() {
    print_info "Performing health check..."
    
    # Simple health check - try to connect to the application
    for i in {1..10}; do
        if curl -f http://localhost:$PORT/health >/dev/null 2>&1; then
            print_status "Application is healthy!"
            return 0
        fi
        sleep 2
    done
    
    print_warning "Health check failed, but continuing..."
    return 0
}

# Start the application
start_app() {
    print_info "Starting Phoenix application..."
    
    case $MIX_ENV in
        "prod")
            print_info "Starting in production mode with release"
            exec ./bin/rehab_tracking start
            ;;
        "dev")
            print_info "Starting in development mode"
            exec mix phx.server
            ;;
        "test")
            print_info "Running tests"
            exec mix test
            ;;
        *)
            print_info "Starting with default configuration"
            exec mix phx.server
            ;;
    esac
}

# Signal handlers for graceful shutdown
shutdown_handler() {
    print_info "Received shutdown signal, stopping application..."
    
    if [ ! -z "$APP_PID" ]; then
        kill -TERM $APP_PID 2>/dev/null || true
        wait $APP_PID 2>/dev/null || true
    fi
    
    print_status "Application stopped gracefully"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Main execution flow
main() {
    print_info "Starting initialization sequence..."
    
    # Step 1: Wait for dependencies
    wait_for_postgres || exit 1
    wait_for_eventstore || exit 1
    
    # Step 2: Compile application (if needed)
    if [ "$MIX_ENV" = "dev" ] || [ ! -f "_build/$MIX_ENV/lib/rehab_tracking/ebin/Elixir.RehabTracking.Application.beam" ]; then
        compile_app || exit 1
    else
        print_status "Application already compiled"
    fi
    
    # Step 3: Initialize databases
    init_databases || exit 1
    
    print_status "Initialization completed successfully!"
    echo ""
    print_info "Application will be available at: http://localhost:$PORT"
    print_info "Health check endpoint: http://localhost:$PORT/health"
    print_info "Environment: $MIX_ENV"
    echo "============================================================"
    
    # Step 4: Start the application
    start_app
}

# Help message
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Docker startup script for Rehab Exercise Tracking System"
    echo ""
    echo "Environment variables:"
    echo "  MIX_ENV           - Environment (prod, dev, test) [default: prod]"
    echo "  PORT              - Application port [default: 4000]"
    echo "  PHX_SERVER        - Start Phoenix server [default: true]"
    echo "  DATABASE_URL      - Main database URL"
    echo "  EVENTSTORE_URL    - EventStore database URL"
    echo "  SECRET_KEY_BASE   - Phoenix secret key base"
    echo ""
    echo "Usage: $0 [--help]"
    exit 0
fi

# Run main function
main "$@"