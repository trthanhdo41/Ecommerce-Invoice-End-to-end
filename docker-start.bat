@echo off
REM Docker Start Script for Windows - Ecommerce Invoice End-to-End Project
REM Usage: docker-start.bat [up|down|logs|status]

setlocal enabledelayedexpansion

set DOCKER_DIR=docker

if "%1"=="" (
    set ACTION=up
) else (
    set ACTION=%1
)

if not exist "%DOCKER_DIR%\.env" (
    echo Creating .env file from template...
    copy "%DOCKER_DIR%\.env.example" "%DOCKER_DIR%\.env"
    echo Edit %DOCKER_DIR%\.env with your GCP/AWS credentials if needed
)

if "%ACTION%"=="up" (
    echo Starting Docker services...
    cd %DOCKER_DIR%
    docker-compose up -d
    cd ..
    
    echo Services started!
    echo.
    echo Waiting for services to be ready (30 seconds)...
    timeout /t 30
    
    echo.
    echo Check status: docker-compose -f docker/docker-compose.yml ps
    echo.
    echo Access Airflow: http://localhost:8080
    echo Username: airflow ^| Password: airflow
    echo.
    echo Databases:
    echo   Source: localhost:5432 (postgres/postgres)
    echo   Target: localhost:5433 (postgres/postgres)
) else if "%ACTION%"=="down" (
    echo Stopping Docker services...
    cd %DOCKER_DIR%
    docker-compose down
    cd ..
    echo Services stopped
) else if "%ACTION%"=="logs" (
    cd %DOCKER_DIR%
    docker-compose logs -f
    cd ..
) else if "%ACTION%"=="status" (
    cd %DOCKER_DIR%
    docker-compose ps
    cd ..
) else (
    echo Usage: docker-start.bat [up^|down^|logs^|status]
    exit /b 1
)
