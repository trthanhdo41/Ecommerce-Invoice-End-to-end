# Deployment Guide - E-commerce Invoice End-to-End Project

This guide covers deploying the project locally with Docker and on Kubernetes (k8s).

## Table of Contents

1. [Local Deployment with Docker](#local-deployment-with-docker)
2. [Kubernetes Deployment](#kubernetes-deployment)
3. [Project Architecture](#project-architecture)
4. [Troubleshooting](#troubleshooting)

---

## Local Deployment with Docker

### Prerequisites

- Docker Desktop installed and running
- Docker Compose (included with Docker Desktop)
- 8GB+ RAM available
- 20GB+ disk space

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/patcha-ranat/Ecommerce-Invoice-End-to-end.git
   cd Ecommerce-Invoice-End-to-end
   ```

2. **Set up environment variables:**
   ```bash
   # Create .env file in the docker directory
   cd docker
   cat > .env << EOF
   GOOGLE_CLOUD_PROJECT=your-gcp-project
   GCP_REGION=us-central1
   AIRFLOW_UID=50000
   AIRFLOW_GID=50000
   EOF
   ```

3. **Start all services:**
   ```bash
   docker-compose up -d
   ```

4. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

   Expected output:
   ```
   NAME                      STATUS
   postgres-container-source Running
   postgres-container-target Running
   airflow-postgres          Running
   airflow-scheduler         Running
   airflow-webserver         Running
   ```

5. **Access Airflow UI:**
   - URL: http://localhost:8080
   - Default credentials: `airflow` / `airflow`

### Service Details

| Service | Port | Purpose |
|---------|------|---------|
| postgres-source | 5432 | Source database (raw data) |
| postgres-target | 5433 | Target database (processed data) |
| airflow-postgres | (internal) | Airflow metadata database |
| airflow-webserver | 8080 | Airflow UI |
| airflow-scheduler | (internal) | DAG scheduler |

### Stopping Services

```bash
docker-compose down

# Remove volumes (WARNING: deletes data)
docker-compose down -v
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f airflow-webserver
docker-compose logs -f postgres-source
```

---

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (minikube, EKS, GKE, AKS, etc.)
- `kubectl` configured and connected to your cluster
- 16GB+ RAM available in cluster
- 50GB+ storage available

### Cluster Setup

#### Option 1: Local Testing with Minikube

```bash
# Start minikube
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable storage provisioner
minikube addons enable storage-provisioner

# Verify cluster
kubectl cluster-info
```

#### Option 2: Cloud Clusters

For GKE, EKS, or AKS, follow your provider's documentation to create a cluster and configure `kubectl`.

### Deployment Steps

1. **Create namespace and secrets:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secrets.yaml
   ```

2. **Create persistent volumes and claims:**
   ```bash
   kubectl apply -f k8s/pvc.yaml
   ```

3. **Create RBAC resources:**
   ```bash
   kubectl apply -f k8s/rbac.yaml
   ```

4. **Create ConfigMaps for database initialization:**
   ```bash
   kubectl apply -f k8s/postgres-source-configmap.yaml
   kubectl apply -f k8s/postgres-target-configmap.yaml
   ```

5. **Deploy PostgreSQL databases:**
   ```bash
   kubectl apply -f k8s/postgres-source-deployment.yaml
   kubectl apply -f k8s/postgres-target-deployment.yaml
   ```

6. **Wait for databases to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgres-source -n ecommerce-pipeline --timeout=300s
   kubectl wait --for=condition=ready pod -l app=postgres-target -n ecommerce-pipeline --timeout=300s
   ```

7. **Deploy Airflow:**
   ```bash
   kubectl apply -f k8s/airflow-deployment.yaml
   ```

8. **Wait for Airflow to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=airflow-webserver -n ecommerce-pipeline --timeout=300s
   ```

### Accessing Services

#### Port Forwarding (for local testing)

```bash
# Airflow UI
kubectl port-forward -n ecommerce-pipeline svc/airflow-webserver 8080:8080

# PostgreSQL Source
kubectl port-forward -n ecommerce-pipeline svc/postgres-source 5432:5432

# PostgreSQL Target
kubectl port-forward -n ecommerce-pipeline svc/postgres-target 5433:5432
```

#### LoadBalancer (for cloud clusters)

```bash
# Get external IP
kubectl get svc -n ecommerce-pipeline airflow-webserver

# Access via external IP
# http://<EXTERNAL-IP>:8080
```

### Monitoring Deployments

```bash
# Check pod status
kubectl get pods -n ecommerce-pipeline

# Check pod details
kubectl describe pod <pod-name> -n ecommerce-pipeline

# View logs
kubectl logs -f <pod-name> -n ecommerce-pipeline

# Check events
kubectl get events -n ecommerce-pipeline
```

### Scaling Services

```bash
# Scale Airflow webserver
kubectl scale deployment airflow-webserver --replicas=3 -n ecommerce-pipeline

# Scale Airflow scheduler
kubectl scale deployment airflow-scheduler --replicas=2 -n ecommerce-pipeline
```

### Cleanup

```bash
# Delete all resources in namespace
kubectl delete namespace ecommerce-pipeline

# Or delete specific resources
kubectl delete -f k8s/
```

---

## Project Architecture

### Docker Compose Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐             │
│  │ postgres-source  │  │ postgres-target  │             │
│  │   (Port 5432)    │  │   (Port 5433)    │             │
│  └──────────────────┘  └──────────────────┘             │
│           ▲                      ▲                       │
│           │                      │                       │
│  ┌────────┴──────────────────────┴────────┐             │
│  │     Airflow Orchestration Layer        │             │
│  ├────────────────────────────────────────┤             │
│  │  ┌──────────────────────────────────┐  │             │
│  │  │  airflow-webserver (Port 8080)   │  │             │
│  │  │  airflow-scheduler               │  │             │
│  │  │  airflow-postgres (metadata)     │  │             │
│  │  └──────────────────────────────────┘  │             │
│  └────────────────────────────────────────┘             │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Kubernetes Architecture

```
┌────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                            │
│         (ecommerce-pipeline namespace)                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                │
│  │  postgres-source│  │ postgres-target │                │
│  │  Deployment     │  │  Deployment     │                │
│  │  + Service      │  │  + Service      │                │
│  └─────────────────┘  └─────────────────┘                │
│           ▲                      ▲                        │
│           │                      │                        │
│  ┌────────┴──────────────────────┴────────┐              │
│  │     Airflow Deployments                │              │
│  ├────────────────────────────────────────┤              │
│  │  ┌──────────────────────────────────┐  │              │
│  │  │  airflow-webserver Deployment    │  │              │
│  │  │  + LoadBalancer Service          │  │              │
│  │  └──────────────────────────────────┘  │              │
│  │  ┌──────────────────────────────────┐  │              │
│  │  │  airflow-scheduler Deployment    │  │              │
│  │  └──────────────────────────────────┘  │              │
│  └────────────────────────────────────────┘              │
│                                                             │
│  ┌─────────────────────────────────────────┐              │
│  │  Persistent Storage (PVC)               │              │
│  │  - postgres-pvc (10Gi)                  │              │
│  │  - airflow-pvc (20Gi)                   │              │
│  └─────────────────────────────────────────┘              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Docker Issues

#### Services won't start

```bash
# Check Docker daemon
docker ps

# Check logs
docker-compose logs

# Rebuild images
docker-compose down
docker-compose up --build
```

#### Port conflicts

```bash
# Find process using port
lsof -i :8080

# Change port in docker-compose.yml
# ports:
#   - "8081:8080"  # Change 8080 to 8081
```

#### Out of disk space

```bash
# Clean up Docker
docker system prune -a

# Check disk usage
docker system df
```

### Kubernetes Issues

#### Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n ecommerce-pipeline

# Check events
kubectl get events -n ecommerce-pipeline --sort-by='.lastTimestamp'
```

#### PVC pending

```bash
# Check PVC status
kubectl get pvc -n ecommerce-pipeline

# For minikube, ensure storage provisioner is enabled
minikube addons enable storage-provisioner
```

#### Database connection errors

```bash
# Verify services are running
kubectl get svc -n ecommerce-pipeline

# Test connectivity
kubectl run -it --rm debug --image=postgres:13 --restart=Never -- \
  psql -h postgres-source -U postgres -d sourcedb -c "SELECT 1"
```

#### Out of memory

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n ecommerce-pipeline

# Increase resource limits in deployment YAML
# resources:
#   limits:
#     memory: "8Gi"
```

### Database Issues

#### Reset databases

```bash
# Docker
docker-compose down -v
docker-compose up -d

# Kubernetes
kubectl delete pvc -n ecommerce-pipeline --all
kubectl apply -f k8s/pvc.yaml
```

#### Connect to database

```bash
# Docker
docker exec -it postgres-container-source psql -U postgres

# Kubernetes
kubectl exec -it <postgres-pod-name> -n ecommerce-pipeline -- psql -U postgres
```

---

## Next Steps

1. Configure Airflow connections for GCP/AWS
2. Load sample data into source database
3. Create and test DAGs
4. Set up monitoring and alerting
5. Configure backup and disaster recovery

For more details, see the main [README.md](./README.md)
