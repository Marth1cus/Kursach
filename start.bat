@echo off
chcp 65001 >nul
rem Запуск «Каталога спортивной обуви» на Windows.
rem При первом запуске собирает Flutter Web, затем стартует Go-сервер.
cd /d "%~dp0"

where go >nul 2>nul || (echo [Ошибка] Go не найден. Установите: https://go.dev/dl/ & pause & exit /b 1)

if not exist "frontend\build\web\index.html" (
    where flutter >nul 2>nul || (echo [Ошибка] Flutter не найден в PATH. См. README.md & pause & exit /b 1)
    echo Сборка веб-версии, это займёт 1-2 минуты...
    pushd frontend
    call flutter pub get || (popd & pause & exit /b 1)
    call flutter build web --no-web-resources-cdn || (popd & pause & exit /b 1)
    popd
)

echo.
echo Сервер запускается. Откройте в браузере: http://localhost:8080
echo Для остановки закройте это окно или нажмите Ctrl+C.
echo.
start "" http://localhost:8080
cd backend
go run .
pause
