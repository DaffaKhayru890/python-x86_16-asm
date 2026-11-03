@echo off
rem TinyPrint16 -- builds the DOS .COM image with NASM from the project root.
setlocal
cd /d "%~dp0"
set "ASM=nasm"
set "SRC=src\main.asm"
set "OUT=build\tinyprint16.com"

where %ASM% >nul 2>nul
if errorlevel 1 (
    echo build failed: nasm is not on PATH 1>&2
    echo install it, or set ASM to the full path of nasm.exe 1>&2
    exit /b 1
)

if not exist build mkdir build

%ASM% -f bin -I src -o %OUT% %SRC%
if errorlevel 1 (
    echo build failed: nasm reported the errors above 1>&2
    exit /b 1
)

echo built %OUT%
endlocal
