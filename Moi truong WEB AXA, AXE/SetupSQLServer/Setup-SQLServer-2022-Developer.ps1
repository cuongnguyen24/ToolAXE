param(
    [string]$ConfigPath = "$PSScriptRoot\config\CustomerSettings.json",
    [switch]$SkipInstallerChecks
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  $Message"
    Write-Host "============================================================"
}

function Write-Step {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $script:LogFile -Value "[$timestamp] $Message"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Add-FirewallRuleIfMissing {
    param(
        [string]$Name,
        [int]$Port
    )

    $rule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -DisplayName $Name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
        Write-Host "[OK] Added firewall rule $Name"
        Write-Log "[OK] Added firewall rule $Name for port $Port"
    }
    else {
        Write-Host "[SKIP] Firewall rule already exists: $Name"
        Write-Log "[SKIP] Firewall rule already exists: $Name"
    }
}

if (-not (Test-Administrator)) {
    Write-Host "[ERROR] Please run this script as Administrator."
    exit 1
}

$logDir = Join-Path $PSScriptRoot "logs"
Ensure-Directory -Path $logDir
$script:LogFile = Join-Path $logDir ("setup_sql_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Write-Section "SETUP SQL SERVER 2022 DEVELOPER + SSMS"
Write-Host "Config file : $ConfigPath"
Write-Host "Log file    : $script:LogFile"
Write-Log "=== Start setup SQL Server 2022 Developer ==="

Assert-PathExists -Path $ConfigPath -Description "Config file"
$customerSettings = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$configurationIni = Join-Path $PSScriptRoot "ConfigurationFile.ini"
$postInstallSql = Join-Path $PSScriptRoot "scripts\01-post-install.sql"
$securitySql = Join-Path $PSScriptRoot "scripts\02-create-logins-and-permissions.sql"
$postInstallPs1 = Join-Path $PSScriptRoot "scripts\03-configure-network-and-firewall.ps1"
$sqlMediaRoot = Join-Path $PSScriptRoot "installers\SQLServer2022Developer"
$sqlSetupExe = Join-Path $sqlMediaRoot "setup.exe"
$ssmsInstaller = Join-Path $PSScriptRoot "installers\SSMS-Setup-ENU.exe"

Write-Section "STEP 1 - PRECHECK"
Assert-PathExists -Path $configurationIni -Description "SQL configuration file"
Assert-PathExists -Path $postInstallSql -Description "Post-install SQL script"
Assert-PathExists -Path $securitySql -Description "Security SQL script"
Assert-PathExists -Path $postInstallPs1 -Description "Post-install PowerShell script"

if (-not $SkipInstallerChecks) {
    Assert-PathExists -Path $sqlSetupExe -Description "SQL Server setup.exe"
    Assert-PathExists -Path $ssmsInstaller -Description "SSMS installer"
}
else {
    Write-Step "Skipped installer file checks because -SkipInstallerChecks was used."
}

foreach ($folder in @(
    $customerSettings.Paths.DataRoot,
    $customerSettings.Paths.UserDbData,
    $customerSettings.Paths.UserDbLog,
    $customerSettings.Paths.TempDbData,
    $customerSettings.Paths.TempDbLog,
    $customerSettings.Paths.Backup
)) {
    if ($folder) {
        Ensure-Directory -Path $folder
        Write-Log "[OK] Ensured directory exists: $folder"
    }
}

Write-Section "STEP 2 - INSTALL SQL SERVER"
Write-Step "Review and run the SQL setup command below."
$sqlSetupCommand = @(
    "`"$sqlSetupExe`"",
    "/Q",
    "/ACTION=Install",
    "/IACCEPTSQLSERVERLICENSETERMS",
    "/SUPPRESSPRIVACYSTATEMENTNOTICE",
    "/CONFIGURATIONFILE=`"$configurationIni`""
) -join " "

Write-Host $sqlSetupCommand
Write-Log "[TODO] Run SQL setup command: $sqlSetupCommand"

Write-Section "STEP 3 - INSTALL SSMS"
Write-Step "Review and run the SSMS installer command below."
$ssmsCommand = "`"$ssmsInstaller`" /install /quiet /norestart"
Write-Host $ssmsCommand
Write-Log "[TODO] Run SSMS command: $ssmsCommand"

Write-Section "STEP 4 - POST INSTALL"
Write-Step "Run network and firewall configuration script."
$networkCommand = "powershell -ExecutionPolicy Bypass -File `"$postInstallPs1`" -ConfigPath `"$ConfigPath`""
Write-Host $networkCommand
Write-Log "[TODO] Run post-install PowerShell: $networkCommand"

Write-Step "Run SQL scripts after the instance is available."
$instanceDisplay = if ([string]::IsNullOrWhiteSpace($customerSettings.InstanceName)) { "localhost" } else { "localhost" }
$sqlCmdPostInstall = "sqlcmd -S $instanceDisplay -E -b -i `"$postInstallSql`""
$sqlCmdSecurity = "sqlcmd -S $instanceDisplay -E -b -i `"$securitySql`""
Write-Host $sqlCmdPostInstall
Write-Host $sqlCmdSecurity
Write-Log "[TODO] Run SQL script: $sqlCmdPostInstall"
Write-Log "[TODO] Run SQL script: $sqlCmdSecurity"

Write-Section "STEP 5 - SUMMARY"
Write-Host "Instance            : MSSQLSERVER (default instance)"
Write-Host "Edition             : SQL Server 2022 Developer"
Write-Host "Authentication mode : Mixed Mode (edit if needed)"
Write-Host "TCP port            : $($customerSettings.Network.TcpPort)"
Write-Host "SQL admins          : $($customerSettings.SqlAdmins -join ', ')"
Write-Host "Application logins  : $($customerSettings.AppLogins | ForEach-Object { $_.LoginName } | Sort-Object -Unique -join ', ')"
Write-Host ""
Write-Host "Next action:"
Write-Host "1. Put SQL media into installers\\SQLServer2022Developer\\"
Write-Host "2. Put SSMS installer into installers\\SSMS-Setup-ENU.exe"
Write-Host "3. Edit config\\CustomerSettings.json"
Write-Host "4. Run this script as Administrator"

Write-Log "=== Framework created and validated ==="
