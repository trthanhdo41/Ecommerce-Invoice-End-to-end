@echo off
REM K8s Deployment Script for Windows - Ecommerce Invoice End-to-End Project
REM Usage: k8s-deploy.bat [up|down|status]

setlocal enabledelayedexpansion

set NAMESPACE=ecommerce-pipeline
set K8S_DIR=k8s

if "%1"=="" (
    set ACTION=up
) else (
    set ACTION=%1
)

REM Check kubectl
where kubectl >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo kubectl not installed
    exit /b 1
)

REM Check cluster connection
kubectl cluster-info >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Cannot connect to Kubernetes cluster
    exit /b 1
)

if "%ACTION%"=="up" (
    echo Deploying to Kubernetes...
    
    kubectl apply -k "%K8S_DIR%"
    
    echo Deployment started
    echo Waiting for services to be ready...
    
    echo.
    echo Access Airflow UI:
    echo   kubectl port-forward -n %NAMESPACE% svc/airflow-webserver 8080:8080
    echo.
    echo Check status:
    echo   kubectl get pods -n %NAMESPACE%
    echo.
    echo View logs:
    echo   kubectl logs -f ^<pod-name^> -n %NAMESPACE%
) else if "%ACTION%"=="down" (
    echo Deleting deployment...
    kubectl delete namespace %NAMESPACE% --ignore-not-found
    echo Deployment deleted
) else if "%ACTION%"=="status" (
    echo Pods:
    kubectl get pods -n %NAMESPACE% 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo Namespace not found
    )
    echo.
    echo Services:
    kubectl get svc -n %NAMESPACE% 2>nul
    echo.
    echo PVCs:
    kubectl get pvc -n %NAMESPACE% 2>nul
) else (
    echo Usage: k8s-deploy.bat [up^|down^|status]
    exit /b 1
)
