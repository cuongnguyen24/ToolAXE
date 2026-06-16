param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\CustomerSettings.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$port = [int]$config.Network.TcpPort

Write-Host "Instance      : MSSQLSERVER"
Write-Host "TCP enabled   : $($config.Network.EnableTcp)"
Write-Host "Named pipes   : $($config.Network.EnableNamedPipes)"
Write-Host "Firewall port : $port"
Write-Host ""
Write-Host "TODO manual or scripted actions:"
Write-Host "1. Enable TCP/IP in SQL Server Configuration Manager or by registry/WMI script"
Write-Host "2. Set fixed TCP port to $port for MSSQLSERVER"
Write-Host "3. Restart SQL Server service"

if ($config.Network.OpenFirewall) {
    $ruleName = "SQL Server TCP $port"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port | Out-Null
        Write-Host "[OK] Added firewall rule: $ruleName"
    }
    else {
        Write-Host "[SKIP] Firewall rule already exists: $ruleName"
    }
}
