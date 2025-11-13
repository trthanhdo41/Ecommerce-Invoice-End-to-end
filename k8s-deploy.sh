#!/bin/bash

# K8s Deployment Script - Ecommerce Invoice End-to-End Project
# Usage: ./k8s-deploy.sh [up|down|status]

set -e

NAMESPACE="ecommerce-pipeline"
K8S_DIR="./k8s"

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

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not installed"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

deploy_up() {
    print_info "Deploying to Kubernetes..."
    
    # Apply all manifests
    kubectl apply -k "$K8S_DIR"
    
    print_success "Deployment started"
    print_info "Waiting for services to be ready..."
    
    # Wait for postgres-source
    kubectl wait --for=condition=ready pod -l app=postgres-source -n "$NAMESPACE" --timeout=300s 2>/dev/null || print_info "postgres-source not ready yet"
    
    # Wait for postgres-target
    kubectl wait --for=condition=ready pod -l app=postgres-target -n "$NAMESPACE" --timeout=300s 2>/dev/null || print_info "postgres-target not ready yet"
    
    # Wait for airflow
    kubectl wait --for=condition=ready pod -l app=airflow-webserver -n "$NAMESPACE" --timeout=300s 2>/dev/null || print_info "airflow-webserver not ready yet"
    
    print_success "Deployment complete!"
    echo ""
    print_info "Access Airflow UI:"
    print_info "  kubectl port-forward -n $NAMESPACE svc/airflow-webserver 8080:8080"
    echo ""
    print_info "Check status:"
    print_info "  kubectl get pods -n $NAMESPACE"
    echo ""
    print_info "View logs:"
    print_info "  kubectl logs -f <pod-name> -n $NAMESPACE"
}

deploy_down() {
    print_info "Deleting deployment..."
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    print_success "Deployment deleted"
}

deploy_status() {
    print_info "Pods:"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || print_error "Namespace not found"
    echo ""
    print_info "Services:"
    kubectl get svc -n "$NAMESPACE" 2>/dev/null || print_error "Namespace not found"
    echo ""
    print_info "PVCs:"
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null || print_error "Namespace not found"
}

# Main
case "${1:-up}" in
    up)
        deploy_up
        ;;
    down)
        deploy_down
        ;;
    status)
        deploy_status
        ;;
    *)
        echo "Usage: $0 [up|down|status]"
        exit 1
        ;;
esac
