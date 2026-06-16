# Setup SQL Server + SSMS

## Muc tieu

Bo tool nay dung de cai:

- SQL Server theo `InstanceName` va media dat trong `Installers.SqlOfflinePath`
- SSMS
- Cau hinh TCP, firewall, login, role, va tham so van hanh co ban

## Cau truc thu muc

```text
SetupSQLServer\
|-- Setup-SQLServer-2022-Developer.bat
|-- ConfigurationFile.ini
|-- README.md
|-- config\
|   |-- CustomerSettings.json
|   `-- ConfigurationFile.generated.ini
|-- installers\
|   |-- README.txt
|   `-- offline\
|       |-- README.txt
|       |-- SQLServer2022Offline\
|       |   `-- README.txt
|       `-- SSMSOffline\
|           `-- README.txt
|-- logs\
`-- scripts\
    |-- 04-apply-sql-configuration.ps1
    |-- Get-SetupConfig.ps1
    |-- Resolve-SqlSetupFromMedia.ps1
    |-- Resolve-SsmsInstaller.ps1
    |-- Run-ProcessWithStatus.ps1
    `-- Test-InstalledState.ps1
```

## Cau hinh

Sua [CustomerSettings.json](</C:/Users/Admin/Desktop/ToolAXE/CauHinhHeThongAXE/Moi truong WEB AXA, AXE/SetupSQLServer/config/CustomerSettings.json>):

- `InstanceName`
- `Installers.SqlOfflinePath`
- `Installers.SsmsOfflinePath`
- `AuthenticationMode`
- `SaPassword`
- `SqlAdmins`
- `ServiceAccounts`
- `Network`
- `Paths`
- `ServerTuning`
- `AppLogins`
- `Databases`

File `.bat` se doc config nay de:

- sinh `ConfigurationFile.generated.ini`
- hien thi dung instance
- tim bo cai SQL offline
- tim bo cai SSMS offline

## Bo cai offline

### SQL Server

Dat bo cai offline vao:

```text
installers\offline\SQLServer2022Offline\
```

Ho tro:

- full media da giai nen co `setup.exe`
- hoac file ISO SQL Server

Tool se tu tim `setup.exe` hoac mount ISO de lay `setup.exe`.

### SSMS

Dat bo cai offline vao:

```text
installers\offline\SSMSOffline\
```

Ho tro:

- offline layout co `vs_setup.exe`
- hoac `SSMS-Setup-ENU.exe`

## Cach dung

Chay file:

```text
Setup-SQLServer-2022-Developer.bat
```

bang quyen Administrator.

Tool se:

- bo qua cac buoc da cai roi
- uu tien bo cai offline
- khong co media thi bao dung thu muc can bo vao
- ghi tat ca log vao mot file trong `logs\`

## Luu y

- Neu `SQL Engine` da ton tai, tool se skip buoc tim media va buoc cai engine.
- Neu `SSMS` da ton tai, tool se skip buoc cai SSMS.
- Ban dat media SQL/SSMS nao vao thu muc `offline` thi tool se cai theo media do.
- `ConfigurationFile.ini` la template goc, con file thuc te de SQL Setup dung la `config\ConfigurationFile.generated.ini`.
