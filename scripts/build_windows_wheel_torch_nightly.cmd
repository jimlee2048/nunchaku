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

:: conda environment name
set ENV_NAME=build_env_%PYTHON_VERSION%_%TORCH_VERSION%
echo Using conda environment: %ENV_NAME%

:: create conda environment
call conda create -y -n %ENV_NAME% python=%PYTHON_VERSION% || exit /b 1
call conda activate %ENV_NAME% || exit /b 1

:: install dependencies
call pip install uv || exit /b 1
call uv pip install ninja setuptools wheel build || exit /b 1
call uv pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cu%CUDA_SHORT_VERSION% || exit /b 1

:: set environment variables
set NUNCHAKU_INSTALL_MODE=ALL
set NUNCHAKU_BUILD_WHEELS=1
set NVCC_PREPEND_FLAGS=-allow-unsupported-compiler
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v%CUDA_VERSION%

:: cd to the parent directory
cd /d "%~dp0.."
if exist build rd /s /q build
if exist dist rd /s /q dist

:: set up Visual Studio compilation environment
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -startdir=none -arch=x64 -host_arch=x64 || exit /b 1
set DISTUTILS_USE_SDK=1

:: build wheels
python -m build --wheel --no-isolation || exit /b 1

:: exit conda
call conda deactivate
call conda remove -y -n %ENV_NAME% --all

echo Build complete!
