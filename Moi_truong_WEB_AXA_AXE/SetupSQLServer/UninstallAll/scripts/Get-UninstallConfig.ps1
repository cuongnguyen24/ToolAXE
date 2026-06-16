param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseDir
)

$ErrorActionPreference = "Stop"

function Get-OptionalPropertyValue {
    param(
        [object]$Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    $prop = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) {
        return $null
    }

    return $prop.Value
}

function Resolve-ConfigPathValue {
    param(
        [string]$Value,
        [string]$Fallback
    )

    $resolved = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    $resolved = $resolved.Trim().Trim('"')
    $cleanBaseDir = $BaseDir.Trim().Trim('"')

    if ([IO.Path]::IsPathRooted($resolved)) {
        return $resolved
    }

    return [IO.Path]::GetFullPath((Join-Path $cleanBaseDir $resolved))
}

$settings = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$instanceName = Get-OptionalPropertyValue -Object $settings -PropertyName "InstanceName"
if ([string]::IsNullOrWhiteSpace($instanceName)) {
    $instanceName = "MSSQLSERVER"
}

$network = Get-OptionalPropertyValue -Object $settings -PropertyName "Network"
$paths = Get-OptionalPropertyValue -Object $settings -PropertyName "Paths"
$installers = Get-OptionalPropertyValue -Object $settings -PropertyName "Installers"

$sqlServiceName = if ($instanceName -eq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$instanceName" }
$agentServiceName = if ($instanceName -eq "MSSQLSERVER") { "SQLSERVERAGENT" } else { "SQLAgent`$$instanceName" }
$browserServiceName = "SQLBrowser"

$tcpPort = Get-OptionalPropertyValue -Object $network -PropertyName "TcpPort"
if ([string]::IsNullOrWhiteSpace([string]$tcpPort)) {
    $tcpPort = 1433
}

$sqlOfflinePath = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $installers -PropertyName "SqlOfflinePath") -Fallback "..\installers\offline\SQLServer2022Offline"
$ssmsOfflinePath = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $installers -PropertyName "SsmsOfflinePath") -Fallback "..\installers\offline\SSMSOffline"

$dataRoot = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "DataRoot") -Fallback "C:\SQLServer"
$userDbData = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "UserDbData") -Fallback "C:\SQLServer\Data"
$userDbLog = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "UserDbLog") -Fallback "C:\SQLServer\Log"
$tempDbData = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "TempDbData") -Fallback "C:\SQLServer\TempDB"
$tempDbLog = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "TempDbLog") -Fallback "C:\SQLServer\TempDBLog"
$backupDir = Resolve-ConfigPathValue -Value (Get-OptionalPropertyValue -Object $paths -PropertyName "Backup") -Fallback "C:\SQLServer\Backup"

@(
    "INSTANCE_NAME=$instanceName"
    "SQL_SERVICE_NAME=$sqlServiceName"
    "SQL_AGENT_SERVICE_NAME=$agentServiceName"
    "SQL_BROWSER_SERVICE_NAME=$browserServiceName"
    "TCP_PORT=$tcpPort"
    "SQL_OFFLINE_PATH=$sqlOfflinePath"
    "SSMS_OFFLINE_PATH=$ssmsOfflinePath"
    "DATA_ROOT=$dataRoot"
    "USERDB_DATA=$userDbData"
    "USERDB_LOG=$userDbLog"
    "TEMPDB_DATA=$tempDbData"
    "TEMPDB_LOG=$tempDbLog"
    "BACKUP_DIR=$backupDir"
) | Write-Output
