param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("SqlEngine", "Ssms", "SqlMedia")]
    [string]$Check,

    [string]$MediaRoot = ""
)

$ErrorActionPreference = "SilentlyContinue"

switch ($Check) {
    "SqlEngine" {
        $service = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
        $instance = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -Name MSSQLSERVER -ErrorAction SilentlyContinue

        if ($service -and $instance) {
            Write-Output "INSTALLED"
            exit 0
        }

        Write-Output "MISSING"
        exit 1
    }

    "Ssms" {
        $ssmsExe = Get-ChildItem -Path @(
            "${env:ProgramFiles}\Microsoft SQL Server Management Studio*",
            "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio*"
        ) -Recurse -Filter Ssms.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($ssmsExe) {
            Write-Output "INSTALLED|$($ssmsExe.FullName)"
            exit 0
        }

        $uninstallRoots = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        $ssmsApp = Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*SQL Server Management Studio*" } |
            Select-Object -First 1

        if ($ssmsApp) {
            Write-Output "INSTALLED|$($ssmsApp.DisplayName)"
            exit 0
        }

        Write-Output "MISSING"
        exit 1
    }

    "SqlMedia" {
        if ([string]::IsNullOrWhiteSpace($MediaRoot) -or -not (Test-Path -LiteralPath $MediaRoot)) {
            Write-Output "MISSING"
            exit 1
        }

        $setup = Get-ChildItem -LiteralPath $MediaRoot -Recurse -Filter setup.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
        $iso = Get-ChildItem -LiteralPath $MediaRoot -Recurse -Filter *.iso -File -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($setup -or $iso) {
            Write-Output "READY"
            exit 0
        }

        Write-Output "MISSING"
        exit 1
    }
}
