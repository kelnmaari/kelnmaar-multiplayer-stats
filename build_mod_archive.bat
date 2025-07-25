@echo off
setlocal enabledelayedexpansion

:: Получаем название и версию мода из info.json
for /f "tokens=2 delims=:," %%a in ('findstr "name" info.json') do (
    set MOD_NAME=%%a
    set MOD_NAME=!MOD_NAME: "=!
    set MOD_NAME=!MOD_NAME:"=!
    set MOD_NAME=!MOD_NAME: =!
)

for /f "tokens=2 delims=:," %%a in ('findstr "\"version\"" info.json') do (
    set MOD_VERSION=%%a
    set MOD_VERSION=!MOD_VERSION: "=!
    set MOD_VERSION=!MOD_VERSION:"=!
    set MOD_VERSION=!MOD_VERSION: =!
)

echo Building mod archive for %MOD_NAME% v%MOD_VERSION%
echo.

:: Создаем временную папку с названием мода
if exist "%MOD_NAME%" rmdir "%MOD_NAME%" /s /q
mkdir "%MOD_NAME%"

:: Копируем основные файлы мода
echo Copying main mod files...
copy "info.json" "%MOD_NAME%\" >nul
copy "changelog.txt" "%MOD_NAME%\" >nul
copy "control.lua" "%MOD_NAME%\" >nul
copy "data.lua" "%MOD_NAME%\" >nul
copy "settings.lua" "%MOD_NAME%\" >nul
copy "thumbnail.png" "%MOD_NAME%\" >nul
copy ".factorioignore" "%MOD_NAME%\" >nul

:: Копируем папки
echo Copying lib directory...
xcopy "lib" "%MOD_NAME%\lib\" /e /i /q >nul

echo Copying locale directory...
xcopy "locale" "%MOD_NAME%\locale\" /e /i /q >nul

:: Создаем zip архив
echo Creating zip archive...
set ARCHIVE_NAME=%MOD_NAME%_%MOD_VERSION%.zip

if exist "%ARCHIVE_NAME%" del "%ARCHIVE_NAME%"

powershell "Compress-Archive -Path '%MOD_NAME%' -DestinationPath '%ARCHIVE_NAME%' -Force"

:: Удаляем временную папку
echo Cleaning up...
rmdir "%MOD_NAME%" /s /q

:: Проверяем результат
if exist "%ARCHIVE_NAME%" (
    echo.
    echo ✅ Archive created successfully: %ARCHIVE_NAME%
    for %%I in ("%ARCHIVE_NAME%") do echo    Size: %%~zI bytes
) else (
    echo.
    echo ❌ Failed to create archive!
    exit /b 1
)

pause 