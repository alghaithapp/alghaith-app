@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-backend-railway.ps1"
exit /b %ERRORLEVEL%
