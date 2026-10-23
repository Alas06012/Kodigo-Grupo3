@echo off
REM ============================================================================
REM PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
REM SCRIPT DE AUTOMATIZACIÓN PARA EL PROGRAMADOR DE TAREAS DE WINDOWS
REM EJECUCIÓN: hop-run.bat (Modo Desatendido / Headless)
REM ============================================================================

setlocal enabledelayedexpansion

REM 1. CONFIGURACIÓN DE RUTAS (Ajusta la ruta de Apache Hop y Java si difieren en tu equipo)
set "PROJECT_DIR=D:\Diego\Cursos\KODIGO SQL IA\ProyectoFinal"
set "HOP_DIR=D:\ProgramasDiego\APACHE-HOP\apache-hop-client-2.19.0\hop"
set "WORKFLOW_FILE=%PROJECT_DIR%\HOP\wf_dwh_master.hwf"
set "LOGS_DIR=%PROJECT_DIR%\HOP\logs"

REM 2. PARÁMETROS DEL PIPELINE (Por defecto: Incremental con 3 días de lookback)
set "TIPO_CARGA=INCREMENTAL"
set "DIAS_LOOKBACK=3"

REM Si se pasa un argumento al ejecutar el .bat (ej: ejecutar_pipeline_diario.bat FULL 0)
if not "%~1"=="" set "TIPO_CARGA=%~1"
if not "%~2"=="" set "DIAS_LOOKBACK=%~2"

REM 3. CREAR DIRECTORIO DE LOGS SI NO EXISTE
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

REM 4. OBTENER TIMESTAMP PARA EL ARCHIVO DE LOG Y BATCH_ID UNIFICADO (Formato YYYYMMDD_HHMMSS)
for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "FECHA_LOG=%%I"
if "%FECHA_LOG%"=="" set "FECHA_LOG=RUN_%RANDOM%"
set "LOG_FILE=%LOGS_DIR%\hop_run_%FECHA_LOG%.log"

REM BATCH_ID único para todas las 31 etapas del pipeline
set "BATCH_ID=BATCH_%FECHA_LOG%"
if not "%~3"=="" set "BATCH_ID=%~3"

echo ============================================================================ >> "%LOG_FILE%"
echo INICIO DE EJECUCION DEL PIPELINE ANALITICO HOP >> "%LOG_FILE%"
echo Fecha y Hora: %date% %time% >> "%LOG_FILE%"
echo Modo de Carga: %TIPO_CARGA% ^| Lookback: %DIAS_LOOKBACK% dias ^| Batch ID: %BATCH_ID% >> "%LOG_FILE%"
echo Workflow: %WORKFLOW_FILE% >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"

echo Iniciando ejecucion de Apache Hop...
echo Batch ID: %BATCH_ID%
echo Revisa el log en: %LOG_FILE%

REM 5. VERIFICAR EXISTENCIA DE HOP
if not exist "%HOP_DIR%\hop-run.bat" (
    echo [ERROR] No se encontro hop-run.bat en %HOP_DIR%. >> "%LOG_FILE%"
    echo [ERROR] Por favor edita la variable HOP_DIR en este archivo .bat con la ruta correcta de tu instalacion de Hop. >> "%LOG_FILE%"
    exit /b 1
)

REM 6. EJECUTAR APACHE HOP EN MODO HEADLESS
call "%HOP_DIR%\hop-run.bat" ^
    --project="default" ^
    --file="%WORKFLOW_FILE%" ^
    --runconfig="local" ^
    --parameters="TIPO_CARGA=%TIPO_CARGA%,DIAS_LOOKBACK=%DIAS_LOOKBACK%,BATCH_ID=%BATCH_ID%" >> "%LOG_FILE%" 2>&1

set "EXIT_CODE=%ERRORLEVEL%"

echo ============================================================================ >> "%LOG_FILE%"
if %EXIT_CODE% equ 0 (
    echo [SUCCESS] PIPELINE FINALIZADO CORRECTAMENTE [Codigo: 0] >> "%LOG_FILE%"
    echo Fecha y Hora Fin: %date% %time% >> "%LOG_FILE%"
    echo Pipeline finalizado con EXITO.
) else (
    echo [FAILED] ERROR DURANTE LA EJECUCION DEL PIPELINE [Codigo: %EXIT_CODE%] >> "%LOG_FILE%"
    echo Fecha y Hora Fin: %date% %time% >> "%LOG_FILE%"
    echo Pipeline FALLO con codigo %EXIT_CODE%. Revisa %LOG_FILE%
)
echo ============================================================================ >> "%LOG_FILE%"

exit /b %EXIT_CODE%
