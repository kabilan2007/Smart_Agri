@echo off
title Smart Agri - Backend Server
color 0A

echo.
echo  ============================================
echo    SMART AGRI - Python FastAPI Backend
echo  ============================================
echo.

:: Check if .env exists
if not exist ".env" (
    echo  [SETUP] .env not found. Creating from template...
    copy .env.example .env
    echo  [ACTION REQUIRED] Open .env and fill in your API keys!
    echo.
    notepad .env
    pause
)

:: Check if venv exists
if not exist "venv\" (
    echo  [SETUP] Creating Python virtual environment...
    python -m venv venv
    echo  [OK] Virtual environment created.
    echo.
)

:: Activate venv
echo  [INFO] Activating virtual environment...
call venv\Scripts\activate.bat

:: Install requirements
echo  [INFO] Installing Python dependencies...
pip install -r requirements.txt --quiet

echo.
echo  [READY] Starting Smart Agri Backend Server...
echo  [URL]   http://localhost:8000
echo  [DOCS]  http://localhost:8000/docs
echo.

python run.py

pause
