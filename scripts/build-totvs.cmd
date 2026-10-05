@echo off
setlocal
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "APPSERVER_DIR=%HBBRIDGE_TOTVS_APPSERVER_DIR%"
set "INCLUDES_DIR=%HBBRIDGE_TOTVS_INCLUDES%"
set "ENVIRONMENT=%HBBRIDGE_TOTVS_ENV%"
if not "%~1"=="" set "APPSERVER_DIR=%~1"
if not "%~2"=="" set "INCLUDES_DIR=%~2"
if not "%~3"=="" set "ENVIRONMENT=%~3"
if "%ENVIRONMENT%"=="" set "ENVIRONMENT=PROTHEUS"
set "COMPILE_LOG=%PROJECT_ROOT%\tmp\totvs-compile.log"
set "MISSING_DIR=0"

if "%APPSERVER_DIR%"=="" (
    echo Set HBBRIDGE_TOTVS_APPSERVER_DIR or pass the AppServer directory as argument 1.
    exit /b 2
)
if "%INCLUDES_DIR%"=="" (
    echo Set HBBRIDGE_TOTVS_INCLUDES or pass the vendor include directories as argument 2.
    exit /b 2
)
set "INCLUDES_DIR=%INCLUDES_DIR%;%PROJECT_ROOT%\includes"
if not exist "%APPSERVER_DIR%\appserver.exe" (
    echo AppServer executable not found: %APPSERVER_DIR%\appserver.exe
    exit /b 2
)
for %%D in ("%INCLUDES_DIR:;=" "%") do (
    if not exist "%%~D\" (
        echo Include directory not found: %%~D
        set "MISSING_DIR=1"
    )
)
if "%MISSING_DIR%"=="1" exit /b 2
if not exist "%PROJECT_ROOT%\tmp\" mkdir "%PROJECT_ROOT%\tmp"

rem Lifecycle scripts are optional and explicitly configured by the operator.
if not "%HBBRIDGE_TOTVS_STOP_SCRIPT%"=="" (
    if not exist "%HBBRIDGE_TOTVS_STOP_SCRIPT%" (
        echo Configured stop script not found.
        exit /b 2
    )
    call "%HBBRIDGE_TOTVS_STOP_SCRIPT%"
    if errorlevel 1 (
        echo Could not stop the configured TOTVS processes. Compilation was not started.
        exit /b 1
    )
)

pushd "%APPSERVER_DIR%"
appserver.exe -compile -files="%PROJECT_ROOT%\src\tlpp" -includes="%INCLUDES_DIR%" -env="%ENVIRONMENT%" -consolefile="%COMPILE_LOG%"
set "COMPILE_EXIT=%ERRORLEVEL%"
popd

set "START_EXIT=0"
if not "%HBBRIDGE_TOTVS_START_SCRIPT%"=="" (
    if not exist "%HBBRIDGE_TOTVS_START_SCRIPT%" (
        echo Configured start script not found.
        exit /b 2
    )
    call "%HBBRIDGE_TOTVS_START_SCRIPT%" <nul
    call set "START_EXIT=%%ERRORLEVEL%%"
)
echo Compilation log: %COMPILE_LOG%
if not "%COMPILE_EXIT%"=="0" exit /b %COMPILE_EXIT%
exit /b %START_EXIT%
