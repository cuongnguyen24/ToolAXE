@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  SETUP SQL SERVER 2022 DEVELOPER + SSMS
::  Default instance: MSSQLSERVER
::  Run this file as Administrator.
:: ============================================================

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
set "TEST_STATE_PS1=%BASE_DIR%scripts\Test-InstalledState.ps1"

set "SQL_SETUP_EXE=%BASE_DIR%installers\SQLServer2022Developer\setup.exe"
set "SQL_BOOTSTRAP_DEV=%BASE_DIR%installers\SQL2022-SSEI-Dev.exe"
set "SQL_BOOTSTRAP_EXPR=%BASE_DIR%installers\SQL2022-SSEI-Expr.exe"
set "SQL_DOWNLOADED_MEDIA=%BASE_DIR%installers\SQLServer2022DeveloperMedia"
set "SQL_DOWNLOADED_SETUP=%SQL_DOWNLOADED_MEDIA%\setup.exe"
set "SSMS_EXE=%BASE_DIR%installers\SSMS-Setup-ENU.exe"
set "SSMS_VS_EXE=%BASE_DIR%installers\vs_SSMS.exe"

>>"%LOG_FILE%" echo [%date% %time%] === BAT DAU SETUP SQL SERVER 2022 DEVELOPER + SSMS ===
>>"%LOG_FILE%" echo [%date% %time%] BaseDir = %BASE_DIR%
>>"%LOG_FILE%" echo [%date% %time%] LogFile = %LOG_FILE%

echo.
echo ============================================================
echo   THIET LAP SQL SERVER 2022 DEVELOPER + SSMS
echo   Default instance: MSSQLSERVER
echo ============================================================
echo Log file: %LOG_FILE%
echo.

call :header "BUOC 1: Kiem tra file cau hinh"
call :require_file "%CONFIG_JSON%" "CustomerSettings.json"
call :require_file "%CONFIG_INI%" "ConfigurationFile.ini"
call :require_file "%APPLY_SQL_PS1%" "04-apply-sql-configuration.ps1"
call :require_file "%RUN_PROCESS_PS1%" "Run-ProcessWithStatus.ps1"
call :require_file "%RESOLVE_SQL_MEDIA_PS1%" "Resolve-SqlSetupFromMedia.ps1"
call :require_file "%TEST_STATE_PS1%" "Test-InstalledState.ps1"
if defined HAS_ERROR goto :failed
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
>>"%LOG_FILE%" echo [%date% %time%] [OK] Generated INI: %GENERATED_INI%
echo [OK] BUOC 2 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 2 completed

call :header "BUOC 3: Xac dinh bo cai SQL Server 2022 Developer"
call :is_sql_engine_installed
if "%SQL_ENGINE_INSTALLED%"=="1" (
    echo [SKIP] SQL Server Engine da duoc cai. Bo qua viec tim/download bo cai SQL.
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
    echo [SKIP] SQL Server Engine MSSQLSERVER da cai day du, bo qua buoc cai Engine.
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SQL Engine already installed
) else (
    echo [INFO] SQL Engine chua cai day du, se chay cai dat ngay bay gio.
    >>"%LOG_FILE%" echo [%date% %time%] [INFO] SQL Engine missing before setup, install required
    echo [INFO] Bat dau cai SQL Server 2022 Developer.
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
call :start_service "MSSQLSERVER"
if defined HAS_ERROR goto :failed
call :start_service "SQLSERVERAGENT"
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
>>"%LOG_FILE%" echo [%date% %time%] [OK] SQL post configuration completed
echo [OK] BUOC 6 hoan thanh.
>>"%LOG_FILE%" echo [%date% %time%] [OK] Step 6 completed

call :header "BUOC 7: Cai dat SSMS"
call :is_ssms_installed
if "%SSMS_INSTALLED%"=="1" (
    echo [SKIP] SSMS da duoc cai, bo qua buoc cai SSMS.
    echo        %SSMS_INSTALLED_DETAIL%
    >>"%LOG_FILE%" echo [%date% %time%] [SKIP] SSMS already installed: %SSMS_INSTALLED_DETAIL%
    set "SSMS_EXIT=0"
) else if exist "%SSMS_EXE%" (
    echo [INFO] Bat dau cai SSMS. Buoc nay co the mat vai phut.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "%SSMS_EXE%" -ArgumentString "/install /quiet /norestart" -StatusMessage "Dang cai SSMS" -LogPath "%LOG_FILE%"
    set "SSMS_EXIT=!errorLevel!"
) else if exist "%SSMS_VS_EXE%" (
    echo [INFO] Bat dau cai SSMS tu vs_SSMS.exe. Buoc nay co the mat vai phut.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "%SSMS_VS_EXE%" -ArgumentString "--quiet --wait --norestart" -StatusMessage "Dang cai SSMS" -LogPath "%LOG_FILE%"
    set "SSMS_EXIT=!errorLevel!"
) else (
    echo [CANH BAO] Khong tim thay installer SSMS.
    echo          Dat file SSMS-Setup-ENU.exe hoac vs_SSMS.exe vao installers\ de cai SSMS.
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] Missing SSMS installer, skipped
    set "SSMS_EXIT=0"
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
sc query MSSQLSERVER | findstr /i "STATE" 2>nul
sc query SQLSERVERAGENT | findstr /i "STATE" 2>nul
echo.
echo Instance : MSSQLSERVER
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
pause
exit /b 0

:failed
echo.
echo ============================================================
echo   SETUP DUNG DO CO LOI
echo ============================================================
echo Log file: %LOG_FILE%
echo.
>>"%LOG_FILE%" echo [%date% %time%] === SETUP FAILED ===
pause
exit /b 1

:resolve_sql_setup
if exist "%SQL_SETUP_EXE%" (
    call :detect_original_filename "%SQL_SETUP_EXE%"
    echo !DETECTED_ORIGINAL_FILENAME! | findstr /i "SSEI" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [INFO] File hien tai la bootstrapper SQL Developer:
        echo        %SQL_SETUP_EXE%
        echo [INFO] Tool se download/extract full media vao:
        echo        %SQL_DOWNLOADED_MEDIA%
        set "SQL_BOOTSTRAP_DEV=%SQL_SETUP_EXE%"
        call :download_sql_media
        if defined HAS_ERROR goto :eof
        set "SQL_SETUP_EXE=!DOWNLOADED_SETUP_FOUND!"
    ) else (
        echo [OK] Tim thay full media SQL Developer:
        echo      %SQL_SETUP_EXE%
    )
) else if exist "%SQL_DOWNLOADED_SETUP%" (
    echo [OK] Tim thay full media da download truoc do:
    echo      %SQL_DOWNLOADED_SETUP%
    set "SQL_SETUP_EXE=%SQL_DOWNLOADED_SETUP%"
) else if exist "%SQL_BOOTSTRAP_DEV%" (
    echo [INFO] Tim thay bootstrapper SQL Developer:
    echo        %SQL_BOOTSTRAP_DEV%
    call :download_sql_media
    if defined HAS_ERROR goto :eof
    set "SQL_SETUP_EXE=!DOWNLOADED_SETUP_FOUND!"
) else (
    echo [LOI] Chua co bo cai SQL Server 2022 Developer.
    echo.
    echo Tool can file:
    echo   installers\SQLServer2022Developer\setup.exe
    echo hoac:
    echo   installers\SQL2022-SSEI-Dev.exe
    echo.
    if exist "%SQL_BOOTSTRAP_EXPR%" (
        echo [CANH BAO] Dang co SQL2022-SSEI-Expr.exe = ban Express, khong dung voi yeu cau Developer.
    )
    set "HAS_ERROR=1"
)
goto :eof

:download_sql_media
set "DOWNLOADED_SETUP_FOUND="
call :is_sql_media_ready
if "%SQL_MEDIA_READY%"=="1" (
    echo [SKIP] Full media SQL da co san, bo qua download.
    set "DOWNLOADED_SETUP_FOUND="
    for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE_SQL_MEDIA_PS1%" -MediaRoot "%SQL_DOWNLOADED_MEDIA%" 2^>^&1`) do (
        if "!DOWNLOADED_SETUP_FOUND!"=="" set "DOWNLOADED_SETUP_FOUND=%%S"
    )
    goto :eof
)
if not exist "%SQL_DOWNLOADED_MEDIA%" mkdir "%SQL_DOWNLOADED_MEDIA%" >nul 2>&1
echo [INFO] Dang download/extract full media SQL Server Developer...
echo [INFO] Buoc nay can internet va co the mat 10-30 phut. Cua so se bao trang thai moi 15 giay.

call :try_sql_download "/Action=Download /MediaPath=%SQL_DOWNLOADED_MEDIA% /MediaType=ISO /Quiet" "Dang download SQL media dang ISO"
if defined DOWNLOADED_SETUP_FOUND goto :sql_media_ready

call :try_sql_download "/Action=Download /MediaPath=%SQL_DOWNLOADED_MEDIA% /MediaType=CAB /Quiet" "Dang download SQL media dang CAB"
if defined DOWNLOADED_SETUP_FOUND goto :sql_media_ready

call :try_sql_download "/Action=Download /MediaPath=%SQL_DOWNLOADED_MEDIA% /Quiet" "Dang download SQL media"
if defined DOWNLOADED_SETUP_FOUND goto :sql_media_ready

echo [LOI] Bootstrapper khong download duoc full media SQL Server Developer.
echo       Thuong do 1 trong cac nguyen nhan sau:
echo       - May khong co internet hoac bi proxy/firewall chan download Microsoft
echo       - File bootstrapper khong ho tro silent download tren moi truong nay
echo       - Thieu quyen ghi vao thu muc installers
echo.
echo       Xem log chi tiet tai:
echo       %LOG_FILE%
set "HAS_ERROR=1"
goto :eof

:sql_media_ready
echo [OK] Da co full media/setup:
echo      !DOWNLOADED_SETUP_FOUND!
>>"%LOG_FILE%" echo [%date% %time%] [OK] SQL media ready: !DOWNLOADED_SETUP_FOUND!
goto :eof

:try_sql_download
set "TRY_ARGS=%~1"
set "TRY_STATUS=%~2"
echo [INFO] Thu download media voi tham so:
echo        !TRY_ARGS!
>>"%LOG_FILE%" echo [%date% %time%] [INFO] Try SQL bootstrapper args: !TRY_ARGS!
powershell -NoProfile -ExecutionPolicy Bypass -File "%RUN_PROCESS_PS1%" -FilePath "%SQL_BOOTSTRAP_DEV%" -ArgumentString "!TRY_ARGS!" -StatusMessage "!TRY_STATUS!" -LogPath "%LOG_FILE%"
set "DOWNLOAD_EXIT=!errorLevel!"
>>"%LOG_FILE%" echo [%date% %time%] [INFO] SQL bootstrapper download exit code: !DOWNLOAD_EXIT!

if not "!DOWNLOAD_EXIT!"=="0" (
    echo [CANH BAO] Lan thu nay that bai. Ma loi: !DOWNLOAD_EXIT!
    goto :eof
)

set "RESOLVED_SETUP="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE_SQL_MEDIA_PS1%" -MediaRoot "%SQL_DOWNLOADED_MEDIA%" 2^>^&1`) do (
    if "!RESOLVED_SETUP!"=="" set "RESOLVED_SETUP=%%S"
)

if "!RESOLVED_SETUP!"=="" (
    echo [CANH BAO] Download thanh cong nhung chua tim thay setup.exe/ISO hop le.
    >>"%LOG_FILE%" echo [%date% %time%] [WARN] Download succeeded but setup.exe was not resolved
    goto :eof
)

set "DOWNLOADED_SETUP_FOUND=!RESOLVED_SETUP!"
goto :eof

:is_sql_engine_installed
set "SQL_ENGINE_INSTALLED=0"
for /f "usebackq tokens=1* delims=|" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%TEST_STATE_PS1%" -Check SqlEngine 2^>nul`) do (
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

:is_sql_media_ready
set "SQL_MEDIA_READY=0"
for /f "usebackq tokens=1* delims=|" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%TEST_STATE_PS1%" -Check SqlMedia -MediaRoot "%SQL_DOWNLOADED_MEDIA%" 2^>nul`) do (
    if /i "%%A"=="READY" set "SQL_MEDIA_READY=1"
)
goto :eof

:detect_original_filename
set "DETECTED_ORIGINAL_FILENAME="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "(Get-Item -LiteralPath '%~1').VersionInfo.OriginalFilename" 2^>nul`) do set "DETECTED_ORIGINAL_FILENAME=%%F"
>>"%LOG_FILE%" echo [%date% %time%] [INFO] OriginalFilename for %~1 = !DETECTED_ORIGINAL_FILENAME!
goto :eof

:verify_sql_engine_installed
reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" /v MSSQLSERVER >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Khong thay registry instance MSSQLSERVER sau buoc cai.
    echo       Nghia la SQL Server Engine chua duoc cai thanh cong.
    echo       Kiem tra log chi tiet cua SQL Setup tai:
    echo       C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] MSSQLSERVER registry key not found after setup
    set "HAS_ERROR=1"
    goto :eof
)

sc query MSSQLSERVER >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Khong thay service MSSQLSERVER sau buoc cai.
    echo       Nghia la SQL Server Engine chua duoc cai thanh cong.
    echo       Kiem tra log chi tiet cua SQL Setup tai:
    echo       C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] MSSQLSERVER service not found after setup
    set "HAS_ERROR=1"
    goto :eof
)

echo [OK] Da xac nhan SQL Server Engine MSSQLSERVER ton tai.
>>"%LOG_FILE%" echo [%date% %time%] [OK] MSSQLSERVER instance/service verified
goto :eof

:require_file
if exist "%~1" (
    echo [OK] %~2
    >>"%LOG_FILE%" echo [%date% %time%] [OK] Found %~2
) else (
    echo [LOI] Thieu file: %~1
    >>"%LOG_FILE%" echo [%date% %time%] [ERROR] Missing file: %~1
    set "HAS_ERROR=1"
)
goto :eof

:start_service
sc query "%~1" >nul 2>&1
if %errorLevel% neq 0 (
    if /i "%~1"=="MSSQLSERVER" (
        echo [LOI] Khong tim thay service bat buoc: %~1
        echo       SQL Server Engine chua duoc cai thanh cong, nen khong the cau hinh tiep.
        echo       Hay xem log setup SQL trong:
        echo       C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log
        >>"%LOG_FILE%" echo [%date% %time%] [ERROR] Required service not found: %~1
        set "HAS_ERROR=1"
    ) else (
        echo [SKIP] Khong tim thay service tuy chon: %~1
        >>"%LOG_FILE%" echo [%date% %time%] [SKIP] Optional service not found: %~1
    )
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
