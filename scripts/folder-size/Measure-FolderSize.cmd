@echo off
rem Measures a folder's size, counting duplicate files only once.
rem Drag one or more folders onto this file, or double-click it and type a folder path.
setlocal
set "SCRIPT=%~dp0Measure-FolderSize.ps1"

if not "%~1"=="" goto :next
set /p "TARGET=Folder to measure: "
call :measure
goto :done

:next
if "%~1"=="" goto :done
set "TARGET=%~1"
call :measure
shift
goto :next

:measure
if not defined TARGET (
    echo No folder given.
    exit /b
)
set "TARGET=%TARGET:"=%"
rem A trailing backslash would escape the closing quote, so "D:\" becomes "D:\."
if "%TARGET:~-1%"=="\" set "TARGET=%TARGET%."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Path "%TARGET%"
exit /b

:done
echo.
pause
