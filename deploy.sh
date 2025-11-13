#!/bin/bash

# Ecommerce Invoice End-to-End Project - Deployment Script
# Supports both Docker and Kubernetes deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_success "kubectl is installed"
}

check_disk_space() {
    available=$(df . | awk 'NR==2 {print $4}')
    required=$((50 * 1024 * 1024))  # 50GB in KB
    
    if [ "$available" -lt "$required" ]; then
        print_warning "Low disk space: $(($available / 1024 / 1024))GB available, 50GB recommended"
    else
        print_success "Sufficient disk space available"
    fi
}

# Docker deployment functions
deploy_docker() {
    print_header "Docker Deployment"
    
    check_docker
    check_docker_compose
    check_disk_space
    
    cd docker
    
    # Create .env if it doesn't exist
    if [ ! -f .env ]; then
        print_info "Creating .env file..."
        cat > .env << EOF
GOOGLE_CLOUD_PROJECT=your-gcp-project
GCP_REGION=us-central1
AIRFLOW_UID=50000
AIRFLOW_GID=50000
EOF
        print_warning "Please update .env with your GCP credentials"
    fi
    
    print_info "Starting Docker services..."
    docker-compose up -d
    
    print_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "postgres-container-source"; then
        print_success "postgres-source is running"
    else
        print_error "postgres-source failed to start"
        docker-compose logs postgres-source
        exit 1
    fi
    
    if docker-compose ps | grep -q "airflow-webserver"; then
        print_success "airflow-webserver is running"
    else
        print_error "airflow-webserver failed to start"
        docker-compose logs airflow-webserver
        exit 1
    fi
    
    cd ..
    
    print_header "Docker Deployment Complete"
    echo ""
    print_info "Access Airflow UI: http://localhost:8080"
    print_info "Username: airflow"
    print_info "Password: airflow"
    echo ""
    print_info "PostgreSQL Source: localhost:5432"
    print_info "PostgreSQL Target: localhost:5433"
    echo ""
    print_info "View logs: docker-compose -f docker/docker-compose.yml logs -f"
    print_info "Stop services: docker-compose -f docker/docker-compose.yml down"
}

# Kubernetes deployment functions
deploy_kubernetes() {
    print_header "Kubernetes Deployment"
    
    check_kubectl
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Make sure your cluster is running and kubectl is configured"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Get cluster info
    cluster_name=$(kubectl config current-context)
    print_info "Deploying to cluster: $cluster_name"
    
    print_info "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    print_info "Creating secrets..."
    kubectl apply -f k8s/secrets.yaml
    
    print_info "Creating persistent volumes..."
    kubectl apply -f k8s/pvc.yaml
    
    print_info "Creating RBAC resources..."
    kubectl apply -f k8s/rbac.yaml
    
    print_info "Creating ConfigMaps..."
    kubectl apply -f k8s/postgres-source-configmap.yaml
    kubectl apply -f k8s/postgres-target-configmap.yaml
    
    print_info "Deploying PostgreSQL databases..."
    kubectl apply -f k8s/postgres-source-deployment.yaml
    kubectl apply -f k8s/postgres-target-deployment.yaml
    
    print_info "Waiting for databases to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod -l app=postgres-source -n ecommerce-pipeline --timeout=300s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=postgres-target -n ecommerce-pipeline --timeout=300s 2>/dev/null || true
    
    print_info "Deploying Airflow..."
    kubectl apply -f k8s/airflow-deployment.yaml
    
    print_info "Waiting for Airflow to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod -l app=airflow-webserver -n ecommerce-pipeline --timeout=300s 2>/dev/null || true
    
    print_header "Kubernetes Deployment Complete"
    echo ""
    print_info "Cluster: $cluster_name"
    print_info "Namespace: ecommerce-pipeline"
    echo ""
    print_info "Check pod status:"
    print_info "  kubectl get pods -n ecommerce-pipeline"
    echo ""
    print_info "Access Airflow UI (port-forward):"
    print_info "  kubectl port-forward -n ecommerce-pipeline svc/airflow-webserver 8080:8080"
    echo ""
    print_info "View logs:"
    print_info "  kubectl logs -f <pod-name> -n ecommerce-pipeline"
    echo ""
    print_info "Delete deployment:"
    print_info "  kubectl delete namespace ecommerce-pipeline"
}

# Status check function
check_status() {
    print_header "Deployment Status"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        if docker-compose -f docker/docker-compose.yml ps &> /dev/null; then
            echo ""
            print_info "Docker Services:"
            docker-compose -f docker/docker-compose.yml ps
        fi
    fi
    
    # Check Kubernetes
    if command -v kubectl &> /dev/null; then
        if kubectl get namespace ecommerce-pipeline &> /dev/null; then
            echo ""
            print_info "Kubernetes Pods:"
            kubectl get pods -n ecommerce-pipeline
            echo ""
            print_info "Kubernetes Services:"
            kubectl get svc -n ecommerce-pipeline
        fi
    fi
}

# Stop function
stop_deployment() {
    print_header "Stopping Deployment"
    
    read -p "Stop Docker services? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f docker/docker-compose.yml down
        print_success "Docker services stopped"
    fi
    
    read -p "Delete Kubernetes deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace ecommerce-pipeline
        print_success "Kubernetes deployment deleted"
    fi
}

# Main menu
show_menu() {
    echo ""
    print_header "Ecommerce Invoice End-to-End Project - Deployment"
    echo ""
    echo "1. Deploy with Docker (Local)"
    echo "2. Deploy with Kubernetes"
    echo "3. Check Status"
    echo "4. Stop/Delete Deployment"
    echo "5. View Documentation"
    echo "6. Exit"
    echo ""
    read -p "Select option (1-6): " choice
}

# Main script
main() {
    while true; do
        show_menu
        
        case $choice in
            1)
                deploy_docker
                ;;
            2)
                deploy_kubernetes
                ;;
            3)
                check_status
                ;;
            4)
                stop_deployment
                ;;
            5)
                if command -v open &> /dev/null; then
                    open DEPLOYMENT.md
                elif command -v xdg-open &> /dev/null; then
                    xdg-open DEPLOYMENT.md
                else
                    print_info "See DEPLOYMENT.md for documentation"
                fi
                ;;
            6)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
    done
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
