@echo off
setlocal EnableDelayedExpansion

set CERT_FILE=dist\certs\server.crt
set KEY_FILE=dist\certs\server.key
set CN=localhost
set DAYS=365
set RSA_BITS=2048
set SAN=DNS:localhost,IP:127.0.0.1

:parse
if "%~1"=="" goto run

if /I "%~1"=="--cn" (
  set CN=%~2
  shift
  shift
  goto parse
)

if /I "%~1"=="--days" (
  set DAYS=%~2
  shift
  shift
  goto parse
)

if /I "%~1"=="--bits" (
  set RSA_BITS=%~2
  shift
  shift
  goto parse
)

if /I "%~1"=="--san" (
  set SAN=%~2
  shift
  shift
  goto parse
)

if /I "%~1"=="--cert" (
  set CERT_FILE=%~2
  shift
  shift
  goto parse
)

if /I "%~1"=="--key" (
  set KEY_FILE=%~2
  shift
  shift
  goto parse
)

echo Unknown option: %1
exit /b 1

:run

for %%F in ("%CERT_FILE%") do (
  if not exist "%%~dpF" mkdir "%%~dpF"
)

for %%F in ("%KEY_FILE%") do (
  if not exist "%%~dpF" mkdir "%%~dpF"
)

openssl req ^
  -x509 ^
  -newkey rsa:%RSA_BITS% ^
  -nodes ^
  -days %DAYS% ^
  -keyout "%KEY_FILE%" ^
  -out "%CERT_FILE%" ^
  -subj "/CN=%CN%" ^
  -addext "subjectAltName=%SAN%"

if errorlevel 1 exit /b 1

echo Certificate : %CERT_FILE%
echo Private Key : %KEY_FILE%