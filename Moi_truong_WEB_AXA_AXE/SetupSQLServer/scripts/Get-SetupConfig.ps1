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

$sqlVersion = Get-OptionalPropertyValue -Object $settings -PropertyName "SqlVersion"
if ([string]::IsNullOrWhiteSpace($sqlVersion)) {
    $sqlVersion = "SQL Server"
}

$edition = Get-OptionalPropertyValue -Object $settings -PropertyName "Edition"
if ([string]::IsNullOrWhiteSpace($edition)) {
    $edition = "Unknown"
}

$instanceName = Get-OptionalPropertyValue -Object $settings -PropertyName "InstanceName"
if ([string]::IsNullOrWhiteSpace($instanceName)) {
    $instanceName = "MSSQLSERVER"
}

$installers = Get-OptionalPropertyValue -Object $settings -PropertyName "Installers"
$sqlOfflinePathSetting = Get-OptionalPropertyValue -Object $installers -PropertyName "SqlOfflinePath"
$ssmsOfflinePathSetting = Get-OptionalPropertyValue -Object $installers -PropertyName "SsmsOfflinePath"

$sqlServiceName = if ($instanceName -eq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$instanceName" }
$agentServiceName = if ($instanceName -eq "MSSQLSERVER") { "SQLSERVERAGENT" } else { "SQLAgent`$$instanceName" }

$sqlOfflinePath = Resolve-ConfigPathValue -Value $sqlOfflinePathSetting -Fallback "installers\offline\SQLServer2022Offline"
$ssmsOfflinePath = Resolve-ConfigPathValue -Value $ssmsOfflinePathSetting -Fallback "installers\offline\SSMSOffline"

@(
    "SQL_VERSION=$sqlVersion"
    "SQL_EDITION=$edition"
    "INSTANCE_NAME=$instanceName"
    "SQL_SERVICE_NAME=$sqlServiceName"
    "SQL_AGENT_SERVICE_NAME=$agentServiceName"
    "SQL_OFFLINE_PATH=$sqlOfflinePath"
    "SSMS_OFFLINE_PATH=$ssmsOfflinePath"
) | Write-Output
