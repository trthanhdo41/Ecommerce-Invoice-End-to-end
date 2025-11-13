#!/bin/bash

# Docker Start Script - Ecommerce Invoice End-to-End Project
# Usage: ./docker-start.sh [up|down|logs|status]

set -e

DOCKER_DIR="./docker"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker not installed"
    exit 1
fi

if ! docker ps &> /dev/null; then
    print_error "Docker daemon not running"
    exit 1
fi

# Create .env if not exists
if [ ! -f "$DOCKER_DIR/.env" ]; then
    print_info "Creating .env file from template..."
    cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
    print_info "Edit $DOCKER_DIR/.env with your GCP/AWS credentials if needed"
fi

# Main
case "${1:-up}" in
    up)
        print_info "Starting Docker services..."
        cd "$DOCKER_DIR"
        docker-compose up -d
        cd ..
        
        print_success "Services started!"
        echo ""
        print_info "Waiting for services to be ready (30 seconds)..."
        sleep 30
        
        print_info "Check status: docker-compose -f docker/docker-compose.yml ps"
        echo ""
        print_info "Access Airflow: http://localhost:8080"
        print_info "Username: airflow | Password: airflow"
        echo ""
        print_info "Databases:"
        print_info "  Source: localhost:5432 (postgres/postgres)"
        print_info "  Target: localhost:5433 (postgres/postgres)"
        ;;
    down)
        print_info "Stopping Docker services..."
        cd "$DOCKER_DIR"
        docker-compose down
        cd ..
        print_success "Services stopped"
        ;;
    logs)
        cd "$DOCKER_DIR"
        docker-compose logs -f
        cd ..
        ;;
    status)
        cd "$DOCKER_DIR"
        docker-compose ps
        cd ..
        ;;
    *)
        echo "Usage: $0 [up|down|logs|status]"
        exit 1
        ;;
esac
