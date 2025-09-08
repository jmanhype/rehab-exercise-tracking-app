#!/bin/bash

# Rehab Exercise Tracking System Startup Script
# This script starts PostgreSQL, runs migrations, and starts the Phoenix server

set -e  # Exit on any error

echo "🚀 Starting Rehab Exercise Tracking System..."
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if PostgreSQL is running
check_postgres() {
    echo "🔍 Checking PostgreSQL status..."
    if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        print_status "PostgreSQL is running"
        return 0
    else
        print_warning "PostgreSQL is not running"
        return 1
    fi
}

# Start PostgreSQL (macOS with Homebrew)
start_postgres() {
    echo "🐘 Starting PostgreSQL..."
    
    if command -v brew >/dev/null 2>&1; then
        if brew services list | grep postgresql | grep started >/dev/null; then
            print_status "PostgreSQL service already running"
        else
            brew services start postgresql@15 2>/dev/null || brew services start postgresql
            sleep 3
            if check_postgres; then
                print_status "PostgreSQL started successfully"
            else
                print_error "Failed to start PostgreSQL"
                return 1
            fi
        fi
    else
        print_warning "Homebrew not found. Please start PostgreSQL manually:"
        echo "  - macOS: brew services start postgresql"
        echo "  - Linux: sudo systemctl start postgresql"
        echo "  - Docker: docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15"
        read -p "Press Enter when PostgreSQL is running..."
    fi
}

# Setup database
setup_database() {
    echo "🗄️  Setting up database..."
    
    # Set Mix environment if not set
    export MIX_ENV=${MIX_ENV:-dev}
    
    # Create database if it doesn't exist
    echo "Creating database..."
    if mix ecto.create; then
        print_status "Database created or already exists"
    else
        print_warning "Database creation had issues (may already exist)"
    fi
    
    # Run migrations
    echo "Running migrations..."
    if mix ecto.migrate; then
        print_status "Migrations completed"
    else
        print_error "Migration failed"
        return 1
    fi
    
    # Initialize event store
    echo "Initializing event store..."
    if mix event_store.init; then
        print_status "Event store initialized"
    else
        print_warning "Event store initialization had issues (may already exist)"
    fi
}

# Install dependencies
install_deps() {
    echo "📦 Installing dependencies..."
    if mix deps.get; then
        print_status "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        return 1
    fi
    
    if mix compile; then
        print_status "Project compiled"
    else
        print_error "Compilation failed"
        return 1
    fi
}

# Run basic tests
run_tests() {
    echo "🧪 Running basic tests..."
    if mix test --max-failures 5; then
        print_status "Basic tests passed"
        return 0
    else
        print_warning "Some tests failed - continuing with server startup"
        return 1
    fi
}

# Start Phoenix server
start_server() {
    echo "🌐 Starting Phoenix server..."
    echo "Server will be available at: http://localhost:4000"
    echo "Health check endpoint: http://localhost:4000/health"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo "=========================================="
    
    # Start with IEx console for debugging
    iex -S mix phx.server
}

# Main execution
main() {
    # Change to the correct directory
    cd "$(dirname "$0")/.."
    
    echo "Working directory: $(pwd)"
    echo ""
    
    # Check if we're in the right directory
    if [[ ! -f "mix.exs" ]]; then
        print_error "mix.exs not found. Please run this script from the backend/rehab_tracking directory"
        exit 1
    fi
    
    # Step 1: Check/Start PostgreSQL
    if ! check_postgres; then
        start_postgres || exit 1
    fi
    
    # Step 2: Install dependencies
    install_deps || exit 1
    
    # Step 3: Setup database
    setup_database || exit 1
    
    # Step 4: Run tests (optional, don't fail if tests fail)
    echo ""
    echo "🧪 Testing system (optional)..."
    if run_tests; then
        print_status "All systems go!"
    else
        print_warning "Some tests failed, but system should still work"
    fi
    
    echo ""
    print_status "System startup complete!"
    echo ""
    
    # Step 5: Start server
    start_server
}

# Help text
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Rehab Exercise Tracking System Startup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --no-tests     Skip running tests"
    echo "  --setup-only   Only setup database, don't start server"
    echo ""
    echo "Environment variables:"
    echo "  MIX_ENV        Set environment (dev, test, prod)"
    echo "  PORT           Set server port (default: 4000)"
    echo ""
    exit 0
fi

# Handle options
if [[ "$1" == "--setup-only" ]]; then
    cd "$(dirname "$0")/.."
    check_postgres || start_postgres || exit 1
    install_deps || exit 1
    setup_database || exit 1
    print_status "Setup complete!"
    exit 0
fi

# Run main function
main "$@"