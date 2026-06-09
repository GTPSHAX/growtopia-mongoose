@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "BUILD_DIR=%REPO_ROOT%\build\windows"
set "BUILD_TYPE=Debug"
set "CLEAN=no"

:parse
if "%~1"=="" goto build
if "%~1"=="--release" (
  set "BUILD_TYPE=Release"
  shift
  goto parse
)
if "%~1"=="--debug" (
  set "BUILD_TYPE=Debug"
  shift
  goto parse
)
if "%~1"=="--build-dir" (
  shift
  if "%~1"=="" (
    echo Missing value for --build-dir 1>&2
    exit /b 1
  )
  set "BUILD_DIR=%~1"
  shift
  goto parse
)
if "%~1"=="--clean" (
  set "CLEAN=yes"
  shift
  goto parse
)
if "%~1"=="--help" goto usage

echo Unknown option: %~1 1>&2
goto usage_error

:usage
echo Usage: scripts\build.bat [options]
echo.
echo Options:
echo   --release          Build with Release config
echo   --debug            Build with Debug config
echo   --build-dir DIR    Build directory, default .\build\windows
echo   --clean            Remove the build directory before configuring
echo   --help             Show this help
exit /b 0

:usage_error
echo Usage: scripts\build.bat [--release] [--debug] [--build-dir DIR] [--clean] 1>&2
exit /b 1

:build
if "%CLEAN%"=="yes" (
  if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
)

cmake -S "%REPO_ROOT%" -B "%BUILD_DIR%" -DCMAKE_BUILD_TYPE=%BUILD_TYPE%
if errorlevel 1 exit /b 1

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE%
if errorlevel 1 exit /b 1

endlocal
