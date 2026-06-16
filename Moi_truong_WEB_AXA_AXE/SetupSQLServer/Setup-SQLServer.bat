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
set "LOG_DIR=%BASE_DIR%logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul`) do set "LOG_STAMP=%%T"
if "%LOG_STAMP%"=="" set "LOG_STAMP=%RANDOM%%RANDOM%"
set "LOG_FILE=%LOG_DIR%\setup_sql_%LOG_STAMP%.log"
break > "%LOG_FILE%" 2>nul

set "CONFIG_JSON=%BASE_DIR%config\CustomerSettings.json"
set "CONFIG_INI=%BASE_DIR%ConfigurationFile.ini"
set "GENERATED_INI=%BASE_DIR%config\ConfigurationFile.generated.ini"
set "APPLY_SQL_PS1=%BASE_DIR%scripts\04-apply-sql-configuration.ps1"
set "RUN_PROCESS_PS1=%BASE_DIR%scripts\Run-ProcessWithStatus.ps1"
set "RESOLVE_SQL_MEDIA_PS1=%BASE_DIR%scripts\Resolve-SqlSetupFromMedia.ps1"
set "RESOLVE_SSMS_PS1=%BASE_DIR%scripts\Resolve-SsmsInstaller.ps1"
set "TEST_STATE_PS1=%BASE_DIR%scripts\Test-InstalledState.ps1"
set "GET_SETUP_CONFIG_PS1=%BASE_DIR%scripts\Get-SetupConfig.ps1"

>>"%LOG_FILE%" echo [%date% %time%] === BAT DAU SETUP SQL SERVER + SSMS ===
>>"%LOG_FILE%" echo [%date% %time%] BaseDir = %BASE_DIR%
>>"%LOG_FILE%" echo [%date% %time%] LogFile = %LOG_FILE%

call :require_file "%CONFIG_JSON%" "CustomerSettings.json"
call :require_file "%CONFIG_INI%" "ConfigurationFile.ini"
call :require_file "%APPLY_SQL_PS1%" "04-apply-sql-configuration.ps1"
call :require_file "%RUN_PROCESS_PS1%" "Run-ProcessWithStatus.ps1"
call :require_file "%RESOLVE_SQL_MEDIA_PS1%" "Resolve-SqlSetupFromMedia.ps1"
call :require_file "%RESOLVE_SSMS_PS1%" "Resolve-SsmsInstaller.ps1"
call :require_file "%TEST_STATE_PS1%" "Test-InstalledState.ps1"
call :require_file "%GET_SETUP_CONFIG_PS1%" "Get-SetupConfig.ps1"
if defined HAS_ERROR goto :failed

for /f "usebackq tokens=1* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%GET_SETUP_CONFIG_PS1%" -ConfigPath "%CONFIG_JSON%" -BaseDir "%BASE_DIR%"`) do set "%%A=%%B"

if "%SQL_OFFLINE_PATH%"=="" set "SQL_OFFLINE_PATH=%BASE_DIR%installers\offline\SQLServer2022Offline"
if "%SSMS_OFFLINE_PATH%"=="" set "SSMS_OFFLINE_PATH=%BASE_DIR%installers\offline\SSMSOffline"
if "%INSTANCE_NAME%"=="" set "INSTANCE_NAME=MSSQLSERVER"
if "%SQL_SERVICE_NAME%"=="" set "SQL_SERVICE_NAME=MSSQLSERVER"
if "%SQL_AGENT_SERVICE_NAME%"=="" set "SQL_AGENT_SERVICE_NAME=SQLSERVERAGENT"

set "SQL_SETUP_EXE="
set "SSMS_SETUP_EXE="

echo.
echo ============================================================
echo   THIET LAP SQL SERVER + SSMS
echo   Instance: %INSTANCE_NAME%
echo ============================================================
echo Log file: %LOG_FILE%
echo.

call :header "BUOC 1: Kiem tra file cau hinh"
echo [OK] CustomerSettings.json
echo [OK] ConfigurationFile.ini
echo [OK] 04-apply-sql-configuration.ps1
echo [OK] Run-ProcessWithStatus.ps1
echo [OK] Resolve-SqlSetupFromMedia.ps1
echo [OK] Resolve-SsmsInstaller.ps1
echo [OK] Test-InstalledState.ps1
echo [OK] Get-SetupConfig.ps1
echo [OK] BUOC 1 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 1 completed

call :header "BUOC 2: Tao ConfigurationFile.generated.ini"
echo [INFO] Dang tao file cau hinh cai dat SQL...
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPLY_SQL_PS1%" -ConfigPath "%CONFIG_JSON%" -TemplateIni "%CONFIG_INI%" -OutputIni "%GENERATED_INI%" -GenerateIniOnly
if %errorLevel% neq 0 (
    echo [LOI] Khong tao duoc file cau hinh SQL tu CustomerSettings.json
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] Generate INI failed, errorLevel=%errorLevel%
    goto :failed
)
echo [OK] Da tao file cau hinh:
echo      %GENERATED_INI%
echo [OK] BUOC 2 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Generated INI: %GENERATED_INI%
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 2 completed

call :header "BUOC 3: Xac dinh bo cai SQL Server offline"
call :is_sql_engine_installed
if "%SQL_ENGINE_INSTALLED%"=="1" (
    echo [SKIP] SQL Server Engine da duoc cai. Bo qua viec tim bo cai SQL.
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SQL engine already installed, skip media resolution
) else (
    call :resolve_sql_setup
    if defined HAS_ERROR goto :failed
    echo [OK] File setup se dung:
    echo      %SQL_SETUP_EXE%
    >>"%LOG_FILE%" echo [%date% %time%] [OK] SQL_SETUP_EXE=%SQL_SETUP_EXE%
)
echo [OK] BUOC 3 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 3 completed

call :header "BUOC 4: Cai dat SQL Server Engine"
call :is_sql_engine_installed
if "%SQL_ENGINE_INSTALLED%"=="1" (
    echo [SKIP] SQL Server Engine %INSTANCE_NAME% da cai day du, bo qua buoc cai Engine.
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SQL Engine already installed
) else (
    echo [INFO] SQL Engine chua cai day du, se chay cai dat ngay bay gio.
    echo [INFO] Bat dau cai SQL Server tu media offline da cau hinh.
    echo [INFO] Buoc nay co the mat 10-30 phut tuy may. Cua so se bao trang thai moi 15 giay.
    set "SQL_ARGS=/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE /CONFIGURATIONFILE=%GENERATED_INI%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "%SQL_SETUP_EXE%" -ArgumentString "!SQL_ARGS!" -StatusMessage "Dang cai SQL Server Engine" -LogPath "%LOG_FILE%"
    set "SQL_EXIT=!errorLevel!"
    >>"%LOG_FILE%" echo [%date% %time%] [INFO] SQL setup exit code: !SQL_EXIT!
    if "!SQL_EXIT!"=="0" (
        echo [OK] Cai SQL Server thanh cong.
    ) else if "!SQL_EXIT!"=="3010" (
        echo [OK] Cai SQL Server thanh cong, can restart may sau khi hoan tat cac buoc.
        set "NEED_RESTART=1"
    ) else if "!SQL_EXIT!"=="1641" (
        echo [OK] Cai SQL Server thanh cong, may co the tu restart.
        set "NEED_RESTART=1"
    ) else (
        echo [LOI] Cai SQL Server that bai. Ma loi: !SQL_EXIT!
        echo       Xem log: %LOG_FILE%
        goto :failed
    )
)

call :verify_sql_engine_installed
if defined HAS_ERROR goto :failed
echo [OK] BUOC 4 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 4 completed

call :header "BUOC 5: Khoi dong dich vu SQL"
call :start_service "%SQL_SERVICE_NAME%"
if defined HAS_ERROR goto :failed
call :start_service "%SQL_AGENT_SERVICE_NAME%"
echo [OK] BUOC 5 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 5 completed

call :header "BUOC 6: Cau hinh TCP, Firewall, Login, Quyen"
echo [INFO] Dang cau hinh SQL sau cai dat...
echo [INFO] Neu SQL Server vua cai xong, buoc nay co the doi service san sang trong vai phut.
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPLY_SQL_PS1%" -ConfigPath "%CONFIG_JSON%"
if %errorLevel% neq 0 (
    echo [LOI] Cau hinh hau cai SQL that bai.
    echo       Xem log: %LOG_FILE%
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] SQL post configuration failed, errorLevel=%errorLevel%
    goto :failed
)
echo [OK] Cau hinh SQL sau cai dat thanh cong.
echo [OK] BUOC 6 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] SQL post configuration completed
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 6 completed

call :header "BUOC 7: Cai dat SSMS"
call :is_ssms_installed
if "%SSMS_INSTALLED%"=="1" (
    echo [SKIP] SSMS da duoc cai, bo qua buoc cai SSMS.
    echo        %SSMS_INSTALLED_DETAIL%
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SSMS already installed: %SSMS_INSTALLED_DETAIL%
    set "SSMS_EXIT=0"
) else (
    call :resolve_ssms_setup
    if defined HAS_ERROR goto :failed
    if "!SSMS_SETUP_EXE!"=="" (
        echo [CANH BAO] Khong tim thay installer SSMS offline.
        echo          Dat offline layout hoac installer vao: %SSMS_OFFLINE_PATH%
        >>"%LOG_FILE%" echo [%date% %time%] [WARN] Missing SSMS offline installer, skipped
        set "SSMS_EXIT=0"
    ) else (
        echo [INFO] Bat dau cai SSMS. Buoc nay co the mat vai phut.
        echo [INFO] Da tim thay bo cai SSMS:
        echo        !SSMS_SETUP_EXE!
        >>"%LOG_FILE%" echo [%date% %time%] [OK] SSMS_SETUP_EXE=!SSMS_SETUP_EXE!
        call :get_ssms_args "!SSMS_SETUP_EXE!"
        powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "!SSMS_SETUP_EXE!" -ArgumentString "%SSMS_ARGS%" -StatusMessage "Dang cai SSMS" -LogPath "%LOG_FILE%"
        set "SSMS_EXIT=!errorLevel!"
    )
)

if not "!SSMS_EXIT!"=="0" (
    if "!SSMS_EXIT!"=="3010" (
        echo [OK] SSMS cai thanh cong, can restart may.
        set "NEED_RESTART=1"
    ) else (
        echo [CANH BAO] Cai SSMS co the that bai. Ma loi: !SSMS_EXIT!
        echo            SQL Server Engine da duoc xu ly xong, xem log de kiem tra SSMS.
        >>"%LOG_FILE%" echo [%date% %time%] [WARN] SSMS installer exit code: !SSMS_EXIT!
    )
) else (
    echo [OK] Cai SSMS hoan tat hoac da duoc bo qua an toan.
    >>"%LOG_FILE%" echo [%date% %time%] [OK] SSMS step completed
)

call :header "KIEM TRA KET QUA"
sc query %SQL_SERVICE_NAME% | findstr /i "STATE" 2>nul
sc query %SQL_AGENT_SERVICE_NAME% | findstr /i "STATE" 2>nul
echo.
echo Instance : %INSTANCE_NAME%
echo Server   : localhost
echo Log file : %LOG_FILE%
echo.

if defined NEED_RESTART (
    echo [QUAN TRONG] Vui long restart may sau khi kiem tra xong.
)

echo.
echo ============================================================
echo   SETUP SQL SERVER HOAN THANH
echo ============================================================
>>"%LOG_FILE%" echo [%date% %time%] === SETUP SQL SERVER HOAN THANH ===
call :wait_before_close
exit /b 0

:failed
echo.
echo ============================================================
echo   SETUP DUNG DO CO LOI
echo ============================================================
echo Log file: %LOG_FILE%
echo.
>>"%LOG_FILE%" echo [%date% %time%] === SETUP FAILED ===
call :wait_before_close
exit /b 1

:resolve_sql_setup
set "SQL_SETUP_EXE="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE_SQL_MEDIA_PS1%" -MediaRoot "%SQL_OFFLINE_PATH%" 2^>nul`) do (
    if "!SQL_SETUP_EXE!"=="" set "SQL_SETUP_EXE=%%S"
)

if "!SQL_SETUP_EXE!"=="" (
    echo [LOI] Chua tim thay bo cai SQL Server offline.
    echo.
    echo Vui long dat full media hoac file ISO vao:
    echo   %SQL_OFFLINE_PATH%
    set "HAS_ERROR=1"
    goto :eof
)

echo [OK] Tim thay bo cai SQL offline:
echo      !SQL_SETUP_EXE!
goto :eof

:resolve_ssms_setup
set "SSMS_SETUP_EXE="
echo [INFO] Dang tim installer SSMS trong:
echo        %SSMS_OFFLINE_PATH%
>>"%LOG_FILE%" echo [%date% %time%] [INFO] Resolve SSMS from: %SSMS_OFFLINE_PATH%
for /f "delims=" %%L in ('dir /b /a:-d "%SSMS_OFFLINE_PATH%" 2^>nul') do (
    >>"%LOG_FILE%" echo [%date% %time%] [INFO] SSMSOffline file: %%L
)
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE_SSMS_PS1%" -MediaRoot "%SSMS_OFFLINE_PATH%" 2^>nul`) do (
    if "!SSMS_SETUP_EXE!"=="" set "SSMS_SETUP_EXE=%%S"
)
goto :eof

:is_sql_engine_installed
set "SQL_ENGINE_INSTALLED=0"
for /f "usebackq tokens=1* delims=|" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%TEST_STATE_PS1%" -Check SqlEngine -InstanceName "%INSTANCE_NAME%" 2^>nul`) do (
    if /i "%%A"=="INSTALLED" set "SQL_ENGINE_INSTALLED=1"
)
goto :eof

:is_ssms_installed
set "SSMS_INSTALLED=0"
set "SSMS_INSTALLED_DETAIL="
for /f "usebackq tokens=1* delims=|" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%TEST_STATE_PS1%" -Check Ssms 2^>nul`) do (
    if /i "%%A"=="INSTALLED" (
        set "SSMS_INSTALLED=1"
        set "SSMS_INSTALLED_DETAIL=%%B"
    )
)
goto :eof

:verify_sql_engine_installed
reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v %INSTANCE_NAME% >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Khong thay registry instance %INSTANCE_NAME% sau buoc cai.
    echo       Nghia la SQL Server Engine chua duoc cai thanh cong.
    echo       Kiem tra log chi tiet cua SQL Setup tai:
    echo       C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] %INSTANCE_NAME% registry key not found after setup
    set "HAS_ERROR=1"
    goto :eof
)

sc query %SQL_SERVICE_NAME% >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Khong thay service %SQL_SERVICE_NAME% sau buoc cai.
    echo       Nghia la SQL Server Engine chua duoc cai thanh cong.
    echo       Kiem tra log chi tiet cua SQL Setup tai:
    echo       C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] %SQL_SERVICE_NAME% service not found after setup
    set "HAS_ERROR=1"
    goto :eof
)

echo [OK] Da xac nhan SQL Server Engine %INSTANCE_NAME% ton tai.
>>"%LOG_FILE%" echo [%date% %time%] [OK] %INSTANCE_NAME% instance/service verified
goto :eof

:get_ssms_args
set "SSMS_ARGS=/install /quiet /norestart"
echo %~nx1 | findstr /i "vs_setup.exe vs_ssms.exe vs_SSMS.exe" >nul 2>&1
if %errorLevel% equ 0 (
    set "SSMS_ARGS=--quiet --wait --norestart --noweb"
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

:start_service
sc query "%~1" >nul 2>&1
if %errorLevel% neq 0 (
    echo [SKIP] Khong tim thay service: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Service not found: %~1
    goto :eof
)

sc query "%~1" | findstr /i "RUNNING" >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Service dang chay: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Service already running: %~1
    goto :eof
)

echo [INFO] Dang khoi dong service: %~1
net start "%~1" >> "%LOG_FILE%" 2>&1
if %errorLevel% equ 0 (
    echo [OK] Da khoi dong service: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Started service: %~1
) else (
    echo [CANH BAO] Khong khoi dong duoc service: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] Could not start service: %~1
)
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
