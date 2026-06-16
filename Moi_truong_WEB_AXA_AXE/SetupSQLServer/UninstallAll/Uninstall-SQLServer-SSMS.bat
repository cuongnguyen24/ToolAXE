@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Vui long chay file nay voi quyen Administrator!
    echo       Right-click ^> Run as administrator
    pause
    exit /b 1
)

set "BASE_DIR=%~dp0"
set "ROOT_DIR=%BASE_DIR%.."
set "LOG_DIR=%BASE_DIR%logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul`) do set "LOG_STAMP=%%T"
if "%LOG_STAMP%"=="" set "LOG_STAMP=%RANDOM%%RANDOM%"
set "LOG_FILE=%LOG_DIR%\uninstall_sql_%LOG_STAMP%.log"
break > "%LOG_FILE%" 2>nul

set "CONFIG_JSON=%ROOT_DIR%\config\CustomerSettings.json"
set "GET_CONFIG_PS1=%BASE_DIR%scripts\Get-UninstallConfig.ps1"
set "RUN_PROCESS_PS1=%ROOT_DIR%\scripts\Run-ProcessWithStatus.ps1"
set "RUN_COMMAND_PS1=%BASE_DIR%scripts\Run-CommandWithStatus.ps1"
set "RESOLVE_SQL_MEDIA_PS1=%ROOT_DIR%\scripts\Resolve-SqlSetupFromMedia.ps1"
set "FIND_SSMS_UNINSTALL_PS1=%BASE_DIR%scripts\Find-SsmsUninstallCommand.ps1"

>>"%LOG_FILE%" echo [%date% %time%] === BAT DAU UNINSTALL SQL SERVER + SSMS ===
>>"%LOG_FILE%" echo [%date% %time%] BaseDir = %BASE_DIR%
>>"%LOG_FILE%" echo [%date% %time%] RootDir = %ROOT_DIR%
>>"%LOG_FILE%" echo [%date% %time%] LogFile = %LOG_FILE%

call :require_file "%CONFIG_JSON%" "CustomerSettings.json"
call :require_file "%GET_CONFIG_PS1%" "Get-UninstallConfig.ps1"
call :require_file "%RUN_PROCESS_PS1%" "Run-ProcessWithStatus.ps1"
call :require_file "%RUN_COMMAND_PS1%" "Run-CommandWithStatus.ps1"
call :require_file "%RESOLVE_SQL_MEDIA_PS1%" "Resolve-SqlSetupFromMedia.ps1"
call :require_file "%FIND_SSMS_UNINSTALL_PS1%" "Find-SsmsUninstallCommand.ps1"
if defined HAS_ERROR goto :failed

for /f "usebackq tokens=1* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%GET_CONFIG_PS1%" -ConfigPath "%CONFIG_JSON%" -BaseDir "%ROOT_DIR%"`) do set "%%A=%%B"

echo.
echo ============================================================
echo   GO UNINSTALL SQL SERVER + SSMS
echo   Instance: %INSTANCE_NAME%
echo ============================================================
echo Log file: %LOG_FILE%
echo [CANH BAO] Tool nay se go cai dat va XOA DU LIEU de dua server test ve trang thai trong.
echo.

call :header "BUOC 1: Go SSMS"
call :uninstall_all_ssms
if "!SSMS_FOUND!"=="0" (
    echo [SKIP] Khong tim thay SSMS de go.
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SSMS not installed
)

call :header "BUOC 2: Go SQL Server Engine"
call :resolve_sql_setup
if defined HAS_ERROR goto :failed

call :check_sql_service
if "!SQL_ENGINE_PRESENT!"=="0" (
    echo [SKIP] Khong tim thay service %SQL_SERVICE_NAME%. Bo qua buoc go SQL Engine.
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SQL Engine not installed
) else (
    call :stop_service "%SQL_AGENT_SERVICE_NAME%"
    call :stop_service "%SQL_SERVICE_NAME%"
    call :stop_service "%SQL_BROWSER_SERVICE_NAME%"
    set "SQL_UNINSTALL_ARGS=/Q /ACTION=Uninstall /FEATURES=SQLENGINE /INSTANCENAME=%INSTANCE_NAME% /IACCEPTSQLSERVERLICENSETERMS"
    echo [INFO] Dang go SQL Server instance %INSTANCE_NAME%...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "%SQL_SETUP_EXE%" -ArgumentString "!SQL_UNINSTALL_ARGS!" -StatusMessage "Dang go SQL Server Engine" -LogPath "%LOG_FILE%"
    set "SQL_UNINSTALL_EXIT=!errorLevel!"
    if "!SQL_UNINSTALL_EXIT!"=="0" (
        echo [OK] Go SQL Server Engine hoan tat.
    ) else if "!SQL_UNINSTALL_EXIT!"=="3010" (
        echo [OK] Go SQL Server Engine hoan tat, can restart may.
        set "NEED_RESTART=1"
    ) else (
        echo [CANH BAO] Go SQL Server Engine co the gap van de. ExitCode=!SQL_UNINSTALL_EXIT!
        >>"%LOG_FILE%" echo [%date% %time%] [WARN] SQL uninstall exit code: !SQL_UNINSTALL_EXIT!
    )
)

call :header "BUOC 3: Xoa firewall rule"
set "FIREWALL_RULE=SQL Server TCP %TCP_PORT%"
netsh advfirewall firewall show rule name="%FIREWALL_RULE%" >nul 2>&1
if %errorLevel% neq 0 (
    echo [SKIP] Firewall rule khong ton tai: %FIREWALL_RULE%
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Firewall rule not found: %FIREWALL_RULE%
) else (
    netsh advfirewall firewall delete rule name="%FIREWALL_RULE%" >> "%LOG_FILE%" 2>&1
    echo [OK] Da xoa firewall rule: %FIREWALL_RULE%
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Firewall rule deleted: %FIREWALL_RULE%
)

call :header "BUOC 4: Xoa cuong buc thu muc du lieu"
call :remove_dir_force "%BACKUP_DIR%"
call :remove_dir_force "%TEMPDB_LOG%"
call :remove_dir_force "%TEMPDB_DATA%"
call :remove_dir_force "%USERDB_LOG%"
call :remove_dir_force "%USERDB_DATA%"
call :remove_dir_force "%DATA_ROOT%"

call :header "BUOC 5: Don dep thu muc chuong trinh SQL / SSMS"
call :remove_dir_force "%ProgramFiles%\Microsoft SQL Server"
call :remove_dir_force "%ProgramFiles(x86)%\Microsoft SQL Server"
call :remove_dir_force "%ProgramFiles%\Microsoft SQL Server Management Studio 20"
call :remove_dir_force "%ProgramFiles(x86)%\Microsoft SQL Server Management Studio 20"
call :remove_dir_force "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft SQL Server Tools"
call :remove_dir_force "%ProgramData%\Microsoft\Windows\Start Menu\Programs\SQL Server 2025"
call :remove_dir_force "%ProgramData%\Microsoft\Windows\Start Menu\Programs\SQL Server 2022"

call :header "KIEM TRA KET QUA"
sc query "%SQL_SERVICE_NAME%" | findstr /i "STATE" 2>nul
sc query "%SQL_AGENT_SERVICE_NAME%" | findstr /i "STATE" 2>nul
echo.
echo Log file : %LOG_FILE%
if defined NEED_RESTART (
    echo [QUAN TRONG] Nen restart may de hoan tat viec go cai dat.
)
echo.
echo ============================================================
echo   UNINSTALL HOAN THANH
echo ============================================================
>>"%LOG_FILE%" echo [%date% %time%] === UNINSTALL HOAN THANH ===
call :wait_before_close
exit /b 0

:failed
echo.
echo ============================================================
echo   UNINSTALL DUNG DO CO LOI
echo ============================================================
echo Log file: %LOG_FILE%
echo.
>>"%LOG_FILE%" echo [%date% %time%] === UNINSTALL FAILED ===
call :wait_before_close
exit /b 1

:uninstall_all_ssms
set "SSMS_FOUND=0"
for /f "usebackq tokens=1,2,3,* delims=	" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%FIND_SSMS_UNINSTALL_PS1%" 2^>nul`) do (
    if not "%%A"=="" (
        set "SSMS_FOUND=1"
        set "SSMS_NAME=%%A"
        set "SSMS_VERSION=%%B"
        set "SSMS_EXE=%%C"
        set "SSMS_ARGS=%%D"
        call :uninstall_one_ssms
    )
)
goto :eof

:uninstall_one_ssms
echo [INFO] Dang go SSMS: !SSMS_NAME! !SSMS_VERSION!
>>"%LOG_FILE%" echo [%date% %time%] [INFO] SSMS uninstall target: !SSMS_NAME! !SSMS_VERSION!
>>"%LOG_FILE%" echo [%date% %time%] [INFO] SSMS uninstall exe   : !SSMS_EXE!
>>"%LOG_FILE%" echo [%date% %time%] [INFO] SSMS uninstall args  : !SSMS_ARGS!
set "RUN_CMD_FILEPATH=!SSMS_EXE!"
set "RUN_CMD_ARGS=!SSMS_ARGS!"
set "RUN_CMD_STATUS=Dang go SSMS: !SSMS_NAME! !SSMS_VERSION!"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%RUN_COMMAND_PS1%' -FilePath $env:RUN_CMD_FILEPATH -ArgumentString $env:RUN_CMD_ARGS -StatusMessage $env:RUN_CMD_STATUS -LogPath '%LOG_FILE%'"
set "SSMS_EXIT=!errorLevel!"
if "!SSMS_EXIT!"=="0" (
    echo [OK] Go SSMS hoan tat: !SSMS_NAME! !SSMS_VERSION!
) else if "!SSMS_EXIT!"=="3010" (
    echo [OK] Go SSMS hoan tat, can restart may: !SSMS_NAME! !SSMS_VERSION!
    set "NEED_RESTART=1"
) else (
    echo [CANH BAO] Go SSMS co the gap van de. ExitCode=!SSMS_EXIT! - !SSMS_NAME! !SSMS_VERSION!
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] SSMS uninstall exit code: !SSMS_EXIT! for !SSMS_NAME! !SSMS_VERSION!
)
goto :eof

:resolve_sql_setup
set "SQL_SETUP_EXE="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE_SQL_MEDIA_PS1%" -MediaRoot "%SQL_OFFLINE_PATH%" 2^>nul`) do (
    if "!SQL_SETUP_EXE!"=="" set "SQL_SETUP_EXE=%%S"
)
if "!SQL_SETUP_EXE!"=="" (
    echo [LOI] Khong tim thay media SQL offline de go cai dat.
    echo       Vui long dat full media hoac ISO vao:
    echo       %SQL_OFFLINE_PATH%
    set "HAS_ERROR=1"
)
goto :eof

:check_sql_service
set "SQL_ENGINE_PRESENT=0"
sc query "%SQL_SERVICE_NAME%" >nul 2>&1
if %errorLevel% equ 0 set "SQL_ENGINE_PRESENT=1"
goto :eof

:stop_service
if "%~1"=="" goto :eof
sc query "%~1" >nul 2>&1
if %errorLevel% neq 0 (
    echo [SKIP] Khong tim thay service de dung: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Service not found for stop: %~1
    goto :eof
)

sc query "%~1" | findstr /i "RUNNING" >nul 2>&1
if %errorLevel% neq 0 (
    echo [SKIP] Service khong chay: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Service not running: %~1
    goto :eof
)

echo [INFO] Dang dung service: %~1
net stop "%~1" /y >> "%LOG_FILE%" 2>&1
if %errorLevel% equ 0 (
    echo [OK] Da dung service: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Service stopped: %~1
) else (
    echo [CANH BAO] Khong dung duoc service: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] Could not stop service: %~1
)
goto :eof

:remove_dir_force
if "%~1"=="" goto :eof
if not exist "%~1" (
    echo [SKIP] Khong co thu muc: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Directory not found: %~1
    goto :eof
)

rmdir /s /q "%~1" >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Da xoa thu muc: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Removed directory: %~1
) else (
    echo [CANH BAO] Khong xoa duoc thu muc: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] Could not remove directory: %~1
)
goto :eof

:require_file
if exist "%~1" (
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Found %~2
    goto :eof
)

echo [LOI] Thieu file: %~1
>>"%LOG_FILE%" echo [%date% %time%] [ERROR] Missing file: %~1
set "HAS_ERROR=1"
goto :eof

:header
echo.
echo ------------------------------------------------------------
echo   %~1
echo ------------------------------------------------------------
>>"%LOG_FILE%" echo [%date% %time%] --- %~1 ---
goto :eof

:wait_before_close
echo.
echo Nhan phim bat ky de dong cua so...
pause >nul
goto :eof
