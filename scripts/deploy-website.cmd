@echo off
setlocal
cd /d "%~dp0.."

echo [1/4] Building admin dashboard...
call npm.cmd run build
if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo [2/4] Copying admin into website\admin ...
if exist "website\admin" rmdir /s /q "website\admin"
xcopy "dist\admin" "website\admin\" /E /I /Y /Q >nul
if not exist "website\admin\index.html" (
  echo Missing website\admin\index.html
  exit /b 1
)

echo [3/4] Deploying website to Vercel...
cd website
call npx.cmd vercel --prod
if errorlevel 1 (
  echo Vercel deploy failed.
  exit /b 1
)

echo [4/4] Done. Open https://www.alghaithst.com/admin
endlocal
