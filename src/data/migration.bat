@echo off
:: Batch file to run the PowerShell script with bypass execution policy
:: This approach works better in restricted environments

echo Running file migration utility...
echo.

:: Check if dry run flag is present
set DRY_RUN=
if "%1"=="--dry-run" set DRY_RUN=-DryRun

:: Execute PowerShell script with bypass execution policy
powershell -ExecutionPolicy Bypass -Command "& {.\migration_script.ps1 %DRY_RUN%}"

echo.
echo Script execution completed.
pause
