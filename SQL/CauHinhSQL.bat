@echo off
chcp 65001 >nul
title Cau hinh SQL Server tu Excel

echo ============================================================
echo    TOOL CAU HINH SQL SERVER TU FILE EXCEL
echo ============================================================
echo.

REM Lấy đường dẫn thư mục chứa file .bat
set "SCRIPT_DIR=%~dp0"
set "EXCEL_FILE=%SCRIPT_DIR%ExcelCauHinh\Settup AXE.xlsx"
set "SHEET_NAME=Cài đặt SQL"

REM Kiểm tra file Excel có tồn tại không
if not exist "%EXCEL_FILE%" (
    echo [LOI] Khong tim thay file Excel!
    echo Duong dan: %EXCEL_FILE%
    echo.
    pause
    exit /b 1
)

REM Kiểm tra Python có được cài đặt không
python --version >nul 2>&1
if errorlevel 1 (
    echo [LOI] Python chua duoc cai dat hoac khong co trong PATH!
    echo Vui long cai dat Python va thu lai.
    echo.
    pause
    exit /b 1
)

REM Kiểm tra các thư viện cần thiết
echo Dang kiem tra cac thu vien can thiet...
python -c "import pandas; import openpyxl" >nul 2>&1
if errorlevel 1 (
    echo [CANH BAO] Chua cai dat cac thu vien can thiet!
    echo Dang cai dat...
    pip install -r "%SCRIPT_DIR%requirements.txt"
    if errorlevel 1 (
        echo [LOI] Khong the cai dat cac thu vien!
        echo Vui long chay: pip install -r requirements.txt
        echo.
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
echo    BAT DAU CAU HINH SQL SERVER
echo ============================================================
echo File Excel: %EXCEL_FILE%
echo Sheet: %SHEET_NAME%
echo ============================================================
echo.

REM Chạy tool
cd /d "%SCRIPT_DIR%"
python sql_config_tool.py "%EXCEL_FILE%" --sheet "%SHEET_NAME%"

if errorlevel 1 (
    echo.
    echo [LOI] Co loi xay ra trong qua trinh cau hinh!
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo ============================================================
    echo    HOAN TAT CAU HINH SQL SERVER
    echo ============================================================
    echo.
)

pause
