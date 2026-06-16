@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  SETUP IIS + .NET 4.8 - Windows Server 2022 Standard
::  Muc tieu: Thiet lap moi truong IIS cho ung dung .NET 4.8
::  Tac gia : CE Tool Core
::  Ngay    : 2026-06-10
::
::  .NET 4.8 Installer: ndp48-x86-x64-allos-enu.exe (dat cung thu muc)
::  Logic: Co mang -> down tu Microsoft | Khong co mang -> dung file local
:: ============================================================

:: Kiem tra quyen Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Vui long chay file nay voi quyen Administrator!
    echo       Right-click ^> Run as administrator
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   THIET LAP MOI TRUONG IIS + .NET 4.8
echo   Windows Server 2022 Standard
echo ============================================================
echo.

:: Tao thu muc log
set "LOG_DIR=%~dp0logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\setup_%date:~6,4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "LOG_FILE=%LOG_FILE: =0%"

call :log "=== BAT DAU SETUP IIS + .NET 4.8 ==="
call :log "Thoi gian: %date% %time%"
call :log "May chu   : %COMPUTERNAME%"

:: ============================================================
:: BUOC 1: CAI DAT CAC TINH NANG IIS
:: ============================================================
call :header "BUOC 1: Cai dat tinh nang IIS"

echo [1/6] Cai dat Web-Server (IIS Core)...
call :install_feature "Web-Server"

echo [2/6] Cai dat Common HTTP Features...
call :install_feature "Web-Common-Http"
call :install_feature "Web-Default-Doc"
call :install_feature "Web-Dir-Browsing"
call :install_feature "Web-Http-Errors"
call :install_feature "Web-Static-Content"
call :install_feature "Web-Http-Redirect"

echo [3/6] Cai dat Health and Diagnostics...
call :install_feature "Web-Health"
call :install_feature "Web-Http-Logging"
call :install_feature "Web-Log-Libraries"
call :install_feature "Web-Request-Monitor"
call :install_feature "Web-Http-Tracing"

echo [4/6] Cai dat Performance...
call :install_feature "Web-Performance"
call :install_feature "Web-Stat-Compression"
call :install_feature "Web-Dyn-Compression"

echo [5/6] Cai dat Security...
call :install_feature "Web-Security"
call :install_feature "Web-Filtering"
call :install_feature "Web-Basic-Auth"
call :install_feature "Web-Windows-Auth"
call :install_feature "Web-Digest-Auth"
call :install_feature "Web-Client-Auth"
call :install_feature "Web-Url-Auth"
call :install_feature "Web-IP-Security"

echo [6/6] Cai dat Application Development (.NET)...
call :install_feature "Web-App-Dev"
call :install_feature "Web-Net-Ext"
call :install_feature "Web-Net-Ext45"
call :install_feature "Web-Asp"
call :install_feature "Web-Asp-Net"
call :install_feature "Web-Asp-Net45"
call :install_feature "Web-ISAPI-Ext"
call :install_feature "Web-ISAPI-Filter"
call :install_feature "Web-CGI"
call :install_feature "Web-Includes"
call :install_feature "Web-WebSockets"

:: ============================================================
:: BUOC 2: CAI DAT TINH NANG QUAN LY IIS
:: ============================================================
call :header "BUOC 2: Cai dat cong cu quan ly IIS"

call :install_feature "Web-Mgmt-Tools"
call :install_feature "Web-Mgmt-Console"
call :install_feature "Web-Mgmt-Compat"
call :install_feature "Web-Metabase"
call :install_feature "Web-Lgcy-Mgmt-Console"
call :install_feature "Web-Lgcy-Scripting"
call :install_feature "Web-WMI"
call :install_feature "Web-Scripting-Tools"
call :install_feature "Web-Mgmt-Service"

:: ============================================================
:: BUOC 3: CAI DAT .NET FRAMEWORK 4.8
:: ============================================================
call :header "BUOC 3: Kiem tra va cai dat .NET Framework 4.8"

:: Kiem tra .NET 4.8 da co chua
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul ^| findstr Release') do set "NET_RELEASE=%%a"
    if !NET_RELEASE! geq 528040 (
        echo [OK] .NET Framework 4.8 da duoc cai dat (Release: !NET_RELEASE!)
        call :log "[OK] .NET 4.8 da co san, Release=!NET_RELEASE!"
    ) else (
        echo [INFO] Phien ban .NET hien tai: !NET_RELEASE! - Can nang cap len 4.8
        call :download_dotnet48
    )
) else (
    echo [INFO] Chua co .NET Framework 4.x, se cai dat .NET 4.8
    call :download_dotnet48
)

:: ============================================================
:: BUOC 4: CAI DAT .NET FRAMEWORK FEATURES (Windows Feature)
:: ============================================================
call :header "BUOC 4: Bat tinh nang .NET Framework trong Windows"

call :install_feature "NET-Framework-45-Features"
call :install_feature "NET-Framework-45-Core"
call :install_feature "NET-Framework-45-ASPNET"
call :install_feature "NET-WCF-Services45"
call :install_feature "NET-WCF-HTTP-Activation45"
call :install_feature "NET-WCF-TCP-Activation45"
call :install_feature "NET-WCF-Pipe-Activation45"

:: ============================================================
:: BUOC 5: CAU HINH IIS - APPLICATION POOL .NET 4.8
:: ============================================================
call :header "BUOC 5: Cau hinh Application Pool .NET 4.8"

:: Kiem tra IIS dang chay
sc query W3SVC | findstr "RUNNING" >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Khoi dong dich vu IIS...
    net start W3SVC >nul 2>&1
    net start WAS >nul 2>&1
)

:: Tao Application Pool dung .NET 4.8
set "POOL_NAME=AppPool_DotNet48"
echo [INFO] Tao Application Pool: %POOL_NAME%

%windir%\system32\inetsrv\appcmd list apppool /name:"%POOL_NAME%" >nul 2>&1
if %errorLevel% neq 0 (
    %windir%\system32\inetsrv\appcmd add apppool /name:"%POOL_NAME%" /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated /enable32BitAppOnWin64:false
    if !errorLevel! equ 0 (
        echo [OK] Da tao Application Pool: %POOL_NAME%
        call :log "[OK] Tao AppPool %POOL_NAME% thanh cong"
    ) else (
        echo [CANH BAO] Khong the tao AppPool %POOL_NAME%
        call :log "[CANH BAO] Khong tao duoc AppPool %POOL_NAME%"
    )
) else (
    echo [INFO] Application Pool %POOL_NAME% da ton tai
    %windir%\system32\inetsrv\appcmd set apppool /apppool.name:"%POOL_NAME%" /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated
    echo [OK] Da cap nhat cau hinh AppPool: %POOL_NAME%
)

:: Cau hinh them cho AppPool: Identity, Recycle, Timeout
%windir%\system32\inetsrv\appcmd set apppool /apppool.name:"%POOL_NAME%" /processModel.idleTimeout:00:00:00
%windir%\system32\inetsrv\appcmd set apppool /apppool.name:"%POOL_NAME%" /recycling.periodicRestart.time:00:00:00
%windir%\system32\inetsrv\appcmd set apppool /apppool.name:"%POOL_NAME%" /failure.rapidFailProtection:false
echo [OK] Da cau hinh AppPool (Idle Timeout, Recycle, RapidFail = OFF)

:: ============================================================
:: BUOC 6: CAU HINH ASPNET REGISTER
:: ============================================================
call :header "BUOC 6: Dang ky ASP.NET voi IIS"

set "ASPNET_REGIIS_PATH=%windir%\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe"
if exist "%ASPNET_REGIIS_PATH%" (
    echo [INFO] Chay aspnet_regiis -iru ...
    "%ASPNET_REGIIS_PATH%" -iru
    if %errorLevel% equ 0 (
        echo [OK] Dang ky ASP.NET thanh cong
        call :log "[OK] aspnet_regiis -iru thanh cong"
    ) else (
        echo [CANH BAO] aspnet_regiis co loi, kiem tra thu cong
        call :log "[CANH BAO] aspnet_regiis loi"
    )
) else (
    echo [CANH BAO] Khong tim thay aspnet_regiis.exe tai: %ASPNET_REGIIS_PATH%
    call :log "[CANH BAO] Khong tim thay aspnet_regiis.exe"
)

:: ============================================================
:: BUOC 7: CAU HINH WINDOWS FIREWALL
:: ============================================================
call :header "BUOC 7: Cau hinh Windows Firewall cho IIS"

echo [INFO] Mo port 80 (HTTP)...
netsh advfirewall firewall show rule name="IIS HTTP Port 80" >nul 2>&1
if %errorLevel% neq 0 (
    netsh advfirewall firewall add rule name="IIS HTTP Port 80" dir=in action=allow protocol=TCP localport=80
    echo [OK] Da mo port 80
) else (
    echo [INFO] Rule port 80 da ton tai
)

echo [INFO] Mo port 443 (HTTPS)...
netsh advfirewall firewall show rule name="IIS HTTPS Port 443" >nul 2>&1
if %errorLevel% neq 0 (
    netsh advfirewall firewall add rule name="IIS HTTPS Port 443" dir=in action=allow protocol=TCP localport=443
    echo [OK] Da mo port 443
) else (
    echo [INFO] Rule port 443 da ton tai
)

call :log "[OK] Cau hinh Firewall hoan tat"

:: ============================================================
:: BUOC 8: KHOI DONG LAI IIS
:: ============================================================
call :header "BUOC 8: Khoi dong lai IIS"

echo [INFO] Dung IIS...
iisreset /stop >nul 2>&1
timeout /t 3 /nobreak >nul

echo [INFO] Khoi dong IIS...
iisreset /start >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] IIS da khoi dong thanh cong
    call :log "[OK] IIS khoi dong thanh cong"
) else (
    echo [CANH BAO] IIS khoi dong co van de, kiem tra thu cong
    call :log "[CANH BAO] IIS khoi dong co van de"
)

:: ============================================================
:: KIEM TRA KET QUA
:: ============================================================
call :header "KIEM TRA KET QUA SETUP"

echo.
echo --- Trang thai dich vu IIS ---
sc query W3SVC | findstr "STATE"
sc query WAS   | findstr "STATE"

echo.
echo --- Phien ban .NET dang ky ---
%windir%\system32\inetsrv\appcmd list apppool /processModel.userName:* /+[managedRuntimeVersion='v4.0'] 2>nul | findstr /i "apppool.name"

echo.
echo --- Danh sach Application Pool ---
%windir%\system32\inetsrv\appcmd list apppool

echo.
echo --- Thong tin .NET Framework ---
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Version 2>nul
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2>nul

:: ============================================================
:: HOAN THANH
:: ============================================================
echo.
echo ============================================================
echo   SETUP HOAN THANH!
echo   Log file: %LOG_FILE%
echo ============================================================
echo.
if defined NEED_RESTART (
    echo.
    echo *** QUAN TRONG: Vui long RESTART may truoc khi su dung IIS! ***
    echo     .NET 4.8 moi duoc cai dat can khoi dong lai de hoan tat.
    echo.
)
echo Cac buoc tiep theo:
echo   1. ^(Neu can^) Restart may neu vua cai .NET 4.8 lan dau
echo   2. Tao Website moi trong IIS Manager
echo   3. Tro Website vao Application Pool: %POOL_NAME%
echo   4. Cau hinh thu muc goc (Physical Path) va Binding
echo   5. Deploy ung dung .NET 4.8 cua ban vao thu muc web
echo.

call :log "=== SETUP HOAN THANH ==="
pause
exit /b 0

:: ============================================================
:: CAC HAM HO TRO
:: ============================================================

:install_feature
    set "FEATURE=%~1"
    powershell -Command "Install-WindowsFeature -Name '%FEATURE%' -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null" >nul 2>&1
    if %errorLevel% equ 0 (
        echo    [OK] %FEATURE%
        call :log "[OK] Feature: %FEATURE%"
    ) else (
        echo    [SKIP] %FEATURE% (da co hoac khong ap dung)
        call :log "[SKIP] Feature: %FEATURE%"
    )
    goto :eof

:download_dotnet48
    echo [INFO] Can cai dat .NET Framework 4.8
    call :log "[INFO] Bat dau kiem tra nguon cai dat .NET 4.8"

    :: ---------------------------------------------------------
    :: Xac dinh duong dan file local (cung thu muc voi file .bat)
    :: ---------------------------------------------------------
    set "LOCAL_INSTALLER=%~dp0ndp48-x86-x64-allos-enu.exe"
    set "DOTNET48_INSTALLER="

    :: ---------------------------------------------------------
    :: KIEM TRA KET NOI INTERNET
    :: ---------------------------------------------------------
    echo [INFO] Kiem tra ket noi internet...
    ping -n 1 -w 3000 download.microsoft.com >nul 2>&1
    if !errorLevel! equ 0 (
        set "HAS_INTERNET=1"
        echo [OK] Co ket noi internet
        call :log "[OK] Co internet - se uu tien download tu Microsoft"
    ) else (
        set "HAS_INTERNET=0"
        echo [INFO] Khong co ket noi internet
        call :log "[INFO] Khong co internet - se dung file local"
    )

    :: ---------------------------------------------------------
    :: CHON NGUON CAI DAT
    :: ---------------------------------------------------------
    if "!HAS_INTERNET!"=="1" (
        :: Co mang: uu tien download moi nhat tu Microsoft
        echo [INFO] Dang tai .NET 4.8 tu Microsoft...
        set "DOTNET48_URL=https://download.microsoft.com/download/f/3/a/f3a6af84-da23-40a5-8d1c-49cc10c8e76f/NDP48-x86-x64-AllOS-ENU.exe"
        set "DOWNLOADED=%TEMP%\NDP48-x86-x64-AllOS-ENU.exe"

        powershell -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { (New-Object Net.WebClient).DownloadFile('!DOTNET48_URL!', '!DOWNLOADED!'); Write-Host 'OK' } catch { Write-Host 'FAIL' }"

        if exist "!DOWNLOADED!" (
            for %%S in ("!DOWNLOADED!") do set "FSIZE=%%~zS"
            if !FSIZE! gtr 50000000 (
                echo [OK] Tai thanh cong ^(!FSIZE! bytes^)
                set "DOTNET48_INSTALLER=!DOWNLOADED!"
                call :log "[OK] Download .NET 4.8 thanh cong tu Microsoft"
            ) else (
                echo [CANH BAO] File tai ve qua nho ^(!FSIZE! bytes^), co the bi loi
                echo [INFO] Chuyen sang dung file local...
                call :log "[CANH BAO] Download that bai, chuyen sang local"
            )
        ) else (
            echo [CANH BAO] Khong tai duoc file tu Microsoft
            echo [INFO] Chuyen sang dung file local...
            call :log "[CANH BAO] Download that bai, chuyen sang local"
        )
    )

    :: Neu chua co installer (khong mang HOAC download that bai) -> dung local
    if "!DOTNET48_INSTALLER!"=="" (
        if exist "!LOCAL_INSTALLER!" (
            for %%S in ("!LOCAL_INSTALLER!") do set "LSIZE=%%~zS"
            if !LSIZE! gtr 50000000 (
                echo [OK] Tim thay file local: ndp48-x86-x64-allos-enu.exe ^(!LSIZE! bytes^)
                set "DOTNET48_INSTALLER=!LOCAL_INSTALLER!"
                call :log "[OK] Dung file local: !LOCAL_INSTALLER!"
            ) else (
                echo [LOI] File local ton tai nhung kich thuoc khong hop le ^(!LSIZE! bytes^)
                echo       Vui long dat dung file: ndp48-x86-x64-allos-enu.exe ^(~116MB^)
                echo       cung thu muc voi file .bat nay
                call :log "[LOI] File local khong hop le, kich thuoc=!LSIZE!"
                goto :eof
            )
        ) else (
            echo [LOI] Khong tim thay file local: !LOCAL_INSTALLER!
            echo       Vui long:
            echo         1. Dat file ndp48-x86-x64-allos-enu.exe vao cung thu muc
            echo         2. Hoac ket noi internet va chay lai
            echo       Tai thu cong: https://dotnet.microsoft.com/download/dotnet-framework/net48
            call :log "[LOI] Khong co internet va khong co file local"
            goto :eof
        )
    )

    :: ---------------------------------------------------------
    :: CAI DAT
    :: ---------------------------------------------------------
    echo [INFO] Dang cai dat .NET 4.8 tu: !DOTNET48_INSTALLER!
    echo [INFO] Vui long cho, qua trinh nay co the mat vai phut...
    "!DOTNET48_INSTALLER!" /q /norestart
    if !errorLevel! equ 0 (
        echo [OK] Cai dat .NET 4.8 thanh cong
        call :log "[OK] .NET 4.8 cai dat thanh cong"
    ) else if !errorLevel! equ 3010 (
        echo [OK] Cai dat .NET 4.8 thanh cong
        echo [CANH BAO] Can RESTART may de hoan tat cai dat!
        call :log "[OK] .NET 4.8 cai dat thanh cong, can restart (code 3010)"
        set "NEED_RESTART=1"
    ) else if !errorLevel! equ 1641 (
        echo [OK] Cai dat .NET 4.8 thanh cong - May se tu dong restart
        call :log "[OK] .NET 4.8 cai dat thanh cong, tu restart (code 1641)"
        set "NEED_RESTART=1"
    ) else (
        echo [LOI] Cai dat .NET 4.8 that bai, ma loi: !errorLevel!
        call :log "[LOI] .NET 4.8 cai dat that bai, errorLevel=!errorLevel!"
    )
    goto :eof

:header
    echo.
    echo ------------------------------------------------------------
    echo   %~1
    echo ------------------------------------------------------------
    call :log "--- %~1 ---"
    goto :eof

:log
    echo [%date% %time%] %~1 >> "%LOG_FILE%"
    goto :eof
