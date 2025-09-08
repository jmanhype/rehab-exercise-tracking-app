#!/bin/bash

# Test script for Docker setup
# Validates docker-compose configuration and attempts to build

set -e

echo "🐳 Testing Docker setup for Rehab Exercise Tracking..."
echo "====================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    print_error "docker-compose.yml not found. Please run this from the backend/rehab_tracking directory"
    exit 1
fi

print_status "Found docker-compose.yml"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop"
    exit 1
fi

print_status "Docker is running"

# Validate docker-compose configuration
echo "🔍 Validating docker-compose configuration..."
if docker-compose config >/dev/null 2>&1; then
    print_status "docker-compose.yml is valid"
else
    print_error "docker-compose.yml has configuration errors"
    echo "Running docker-compose config to show errors:"
    docker-compose config
    exit 1
fi

# Check if services can be built
echo "🔨 Testing Docker build process..."
if docker-compose build --no-cache app; then
    print_status "Docker image built successfully"
else
    print_error "Docker build failed"
    exit 1
fi

# Pull required images
echo "📥 Pulling required images..."
if docker-compose pull postgres redis rabbitmq prometheus grafana; then
    print_status "Required images pulled successfully"
else
    print_warning "Some images failed to pull, but this might be okay"
fi

# Test starting services (without actually running them)
echo "🚀 Testing service startup (dry run)..."
if docker-compose up --no-start; then
    print_status "Services can be created successfully"
else
    print_error "Service creation failed"
    exit 1
fi

# Clean up test containers
echo "🧹 Cleaning up test containers..."
docker-compose down --remove-orphans >/dev/null 2>&1 || true

print_status "All tests passed! Docker setup is ready."
echo ""
echo "To start the services, run:"
echo "  docker-compose up -d"
echo ""
echo "To monitor the logs, run:"
echo "  docker-compose logs -f app"
echo ""
echo "To access the application:"
echo "  http://localhost:4000"
echo "  Health check: http://localhost:4000/health"
echo ""
echo "To access monitoring:"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  RabbitMQ Management: http://localhost:15672 (guest/guest)"