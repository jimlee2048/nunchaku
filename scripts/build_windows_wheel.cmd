@echo off
setlocal enabledelayedexpansion

:: get arguments
set PYTHON_VERSION=%1
set TORCH_VERSION=%2
set CUDA_VERSION=%3
set MAX_JOBS=%4

set CUDA_SHORT_VERSION=%CUDA_VERSION:.=%
echo CUDA_SHORT_VERSION: %CUDA_SHORT_VERSION%
echo MAX_JOBS: %MAX_JOBS%

:: setup some variables
if "%TORCH_VERSION%"=="2.8" (
    set TORCHVISION_VERSION=0.23
) else if "%TORCH_VERSION%"=="2.9" (
    set TORCHVISION_VERSION=0.24
) else if "%TORCH_VERSION%"=="2.10" (
    set TORCHVISION_VERSION=0.25
) else if "%TORCH_VERSION%"=="2.13" (
    set TORCHVISION_VERSION=0.28
) else (
    echo Unsupported TORCH_VERSION: %TORCH_VERSION%
    exit /b 1
)
echo setting TORCHVISION_VERSION to %TORCHVISION_VERSION%

:: use the Python selected by actions/setup-python and keep dependencies on the
:: runner's workspace drive instead of the smaller Windows system drive.
cd /d "%~dp0.."
if exist .venv rd /s /q .venv
call python -m pip install uv || exit /b 1
call uv venv --python "%PYTHON_VERSION%" .venv || exit /b 1
set PYTHON_EXE=%CD%\.venv\Scripts\python.exe

:: install dependencies
call uv pip install --python "%PYTHON_EXE%" ninja setuptools wheel build || exit /b 1
call uv pip install --python "%PYTHON_EXE%" --no-cache-dir torch==%TORCH_VERSION% torchvision==%TORCHVISION_VERSION% --index-url "https://download.pytorch.org/whl/cu%CUDA_SHORT_VERSION%/" || exit /b 1

:: set environment variables
set NUNCHAKU_INSTALL_MODE=ALL
set NUNCHAKU_BUILD_WHEELS=1
set NVCC_PREPEND_FLAGS=-allow-unsupported-compiler
if not defined CUDA_PATH (
    echo CUDA_PATH is not set. The CUDA toolkit installation did not complete correctly.
    exit /b 1
)
set CUDA_HOME=%CUDA_PATH%

if exist build rd /s /q build
if exist dist rd /s /q dist

:: set up Visual Studio compilation environment
set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
if not exist "%VSWHERE%" (
    echo vswhere.exe was not found.
    exit /b 1
)
for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set VS_INSTALL_PATH=%%I
if not defined VS_INSTALL_PATH (
    echo A Visual Studio installation with the C++ toolchain was not found.
    exit /b 1
)
call "%VS_INSTALL_PATH%\Common7\Tools\VsDevCmd.bat" -startdir=none -arch=x64 -host_arch=x64 || exit /b 1
set DISTUTILS_USE_SDK=1

:: build wheels
"%PYTHON_EXE%" -m build --wheel --no-isolation || exit /b 1

echo Build complete!
