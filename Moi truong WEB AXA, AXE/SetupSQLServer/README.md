# Setup SQL Server 2022 Developer + SSMS

## Muc tieu

Bo khung nay dung de dong goi mot tool cai dat:

- SQL Server 2022 Developer
- Default instance: `MSSQLSERVER`
- SSMS
- Cau hinh mang, firewall, login, user, role, va tham so van hanh co ban

Tool nay duoc thiet ke theo cung phong cach voi bo cai IIS hien co:

- co thu muc installer offline
- co script chay chinh
- co file config
- co script hau cai
- co file SQL de tao login/quyen
- co thu muc log

## Cau truc thu muc

```text
SetupSQLServer\
|-- Setup-SQLServer-2022-Developer.bat
|-- Setup-SQLServer-2022-Developer.ps1
|-- ConfigurationFile.ini
|-- README.md
|-- config\
|   |-- CustomerSettings.json
|   `-- ConfigurationFile.generated.ini
|-- installers\
|   |-- README.txt
|   |-- SQLServer2022Developer\
|   |   `-- setup.exe
|   `-- SSMS-Setup-ENU.exe
|-- logs\
`-- scripts\
    |-- 01-post-install.sql
    |-- 02-create-logins-and-permissions.sql
    |-- 03-configure-network-and-firewall.ps1
    `-- 04-apply-sql-configuration.ps1
```

## Cac file ban can chuan bi

### 1. SQL Server 2022 Developer

Tool ho tro 2 cach:

**Cach tot nhat: full media offline**

Dat bo cai da giai nen vao:

```text
installers\SQLServer2022Developer\
```

Can co file:

```text
installers\SQLServer2022Developer\setup.exe
```

**Cach dung bootstrapper**

Dat file:

```text
installers\SQL2022-SSEI-Dev.exe
```

Hoac neu file bootstrapper dang nam tai:

```text
installers\SQLServer2022Developer\setup.exe
```

tool se tu nhan dien va download full media vao:

```text
installers\SQLServer2022DeveloperMedia\
```

Luu y: cach bootstrapper can internet.

### 2. SSMS installer

Dat file:

```text
installers\SSMS-Setup-ENU.exe
```

## Cac file can chinh truoc khi chay

### `config\CustomerSettings.json`

Day la file cau hinh chinh can sua:

- `SAPWD`
- `SqlAdmins`
- `ServiceAccounts`
- `Network`
- `Paths`
- `ServerTuning`
- `AppLogins`
- `Databases`

File `.bat` se doc file nay va tao ra:

```text
config\ConfigurationFile.generated.ini
```

### `ConfigurationFile.ini`

Day la template goc. Thong thuong khong can chay truc tiep file nay, vi `.bat` se tao file generated tu `CustomerSettings.json`.

## Cach dung

### Cach de dung nhat

Chay file:

```text
Setup-SQLServer-2022-Developer.bat
```

Bang quyen Administrator.

File `.bat` se:

- giu cua so de ban xem ket qua
- tao log
- tao `config\ConfigurationFile.generated.ini`
- cai SQL Server Engine neu chua co instance `MSSQLSERVER`
- cau hinh TCP/firewall/login/quyen theo `CustomerSettings.json`
- cai SSMS neu co installer

### Cach PowerShell

Neu ban van muon dung file PowerShell phu:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\\Setup-SQLServer-2022-Developer.ps1
```

## Luu y quan trong

- File `Setup-SQLServer-2022-Developer.bat` la diem chay chinh.
- File `Setup-SQLServer-2022-Developer.ps1` van duoc giu lai nhu mot phien ban phu.
- Tool uu tien full media SQL Server Developer tai `installers\SQLServer2022Developer\setup.exe`.
- Neu gap bootstrapper `SQL2022-SSEI-Dev.exe`, tool se thu download full media vao `installers\SQLServer2022DeveloperMedia`.
- File `SQL2022-SSEI-Expr.exe` la ban Express, khong dung cho yeu cau Developer.
- Tool hien da goi setup SQL Server, cai SSMS, cau hinh TCP/firewall, va tao login/quyen theo `CustomerSettings.json`.
- Mat khau `sa` trong `CustomerSettings.json` can du manh de SQL Server Setup chap nhan.

## Goi y buoc tiep theo

Neu can mo rong them cho moi truong khach hang:

1. Them script restore `.bak`.
2. Them job backup dinh ky.
3. Them cau hinh memory/MAXDOP rieng theo RAM/CPU tung may.
