# Setup IIS + .NET 4.8 — Windows Server 2022 Standard

**File:** `Setup-IIS-DotNet48-WinServer2022.bat`  
**Mục tiêu:** Tự động thiết lập môi trường IIS cho ứng dụng web .NET 4.8  
**Ngày:** 2026-06-10

---

## Cấu trúc thư mục

```
Moi truong WEB AXA, AXE\
├── Setup-IIS-DotNet48-WinServer2022.bat   ← File chạy chính
├── ndp48-x86-x64-allos-enu.exe            ← .NET 4.8 Offline Installer (~116MB)
└── logs\
    └── setup_YYYYMMDD_HHMMSS.log          ← Log sinh tự động mỗi lần chạy
```

---

## Luồng thực thi tổng quan

```
START
  │
  ├─ [Kiểm tra] Quyền Administrator?
  │     └─ Không → Báo lỗi, thoát
  │
  ├─ Khởi tạo LOG file (logs\setup_YYYYMMDD_HHMMSS.log)
  │
  ├─ BƯỚC 1 : Cài đặt tính năng IIS (Windows Feature)
  ├─ BƯỚC 2 : Cài đặt công cụ quản lý IIS
  ├─ BƯỚC 3 : Kiểm tra & cài đặt .NET Framework 4.8
  ├─ BƯỚC 4 : Bật .NET Framework Features (WCF, ASPNET)
  ├─ BƯỚC 5 : Cấu hình Application Pool AppPool_DotNet48
  ├─ BƯỚC 6 : Đăng ký ASP.NET với IIS (aspnet_regiis)
  ├─ BƯỚC 7 : Cấu hình Windows Firewall (port 80, 443)
  ├─ BƯỚC 8 : Restart IIS + Kiểm tra kết quả
  │
  └─ HOÀN THÀNH — In hướng dẫn bước tiếp theo
```

---

## Chi tiết từng bước

### Tiền xử lý — Kiểm tra quyền & Khởi tạo log

```
net session
  ├─ Thất bại → In lỗi "Run as administrator" → exit /b 1
  └─ Thành công → Tạo thư mục logs\
                   Đặt tên LOG_FILE = logs\setup_YYYYMMDD_HHMMSS.log
                   Ghi header log (thời gian, tên máy)
```

---

### BƯỚC 1 — Cài đặt tính năng IIS

Dùng lệnh: `Install-WindowsFeature` (PowerShell) cho từng feature.

| Nhóm | Windows Feature |
|------|----------------|
| **IIS Core** | `Web-Server` |
| **Common HTTP** | `Web-Common-Http`, `Web-Default-Doc`, `Web-Dir-Browsing`, `Web-Http-Errors`, `Web-Static-Content`, `Web-Http-Redirect` |
| **Health & Diagnostics** | `Web-Health`, `Web-Http-Logging`, `Web-Log-Libraries`, `Web-Request-Monitor`, `Web-Http-Tracing` |
| **Performance** | `Web-Performance`, `Web-Stat-Compression`, `Web-Dyn-Compression` |
| **Security** | `Web-Security`, `Web-Filtering`, `Web-Basic-Auth`, `Web-Windows-Auth`, `Web-Digest-Auth`, `Web-Client-Auth`, `Web-Url-Auth`, `Web-IP-Security` |
| **App Dev (.NET)** | `Web-App-Dev`, `Web-Net-Ext`, `Web-Net-Ext45`, `Web-Asp`, `Web-Asp-Net`, `Web-Asp-Net45`, `Web-ISAPI-Ext`, `Web-ISAPI-Filter`, `Web-CGI`, `Web-Includes`, `Web-WebSockets` |

> Mỗi feature: `[OK]` nếu cài được, `[SKIP]` nếu đã có hoặc không áp dụng.

---

### BƯỚC 2 — Cài đặt công cụ quản lý IIS

| Windows Feature | Mục đích |
|----------------|----------|
| `Web-Mgmt-Tools` | Bộ công cụ quản lý tổng hợp |
| `Web-Mgmt-Console` | IIS Manager GUI |
| `Web-Mgmt-Compat` | Tương thích API cũ |
| `Web-Metabase` | Metabase API (legacy) |
| `Web-Lgcy-Mgmt-Console` | Console quản lý legacy |
| `Web-Lgcy-Scripting` | Script hỗ trợ IIS 6 |
| `Web-WMI` | WMI Provider cho IIS |
| `Web-Scripting-Tools` | IIS PowerShell cmdlets |
| `Web-Mgmt-Service` | Web Management Service (remote) |

---

### BƯỚC 3 — Kiểm tra & cài đặt .NET Framework 4.8

Đây là bước có **logic phân nhánh phức tạp nhất**.

#### 3.1 — Kiểm tra .NET đã cài chưa

```
Registry: HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full → Release
  │
  ├─ Release >= 528040 → .NET 4.8 đã có → BỎ QUA, không cài lại
  ├─ Release < 528040  → Cần nâng cấp   → Gọi :download_dotnet48
  └─ Không có key      → Chưa có .NET   → Gọi :download_dotnet48
```

> **Bảng Release Number:**
> | Release | Phiên bản |
> |---------|----------|
> | 528040  | .NET 4.8 (Windows 10 May 2019+) |
> | 528049  | .NET 4.8 (Windows 10 Nov 2019+) |
> | 528372+ | .NET 4.8 (Windows 11 / Server 2022) |

#### 3.2 — Hàm `:download_dotnet48` — Logic chọn nguồn cài đặt

```
:download_dotnet48
  │
  ├─ Xác định LOCAL_INSTALLER = %~dp0\ndp48-x86-x64-allos-enu.exe
  │                              (cùng thư mục với file .bat)
  │
  ├─ [Kiểm tra mạng] ping download.microsoft.com
  │     │
  │     ├─ CÓ MẠNG (ping thành công)
  │     │    ├─ Download từ Microsoft CDN (TLS 1.2, PowerShell WebClient)
  │     │    │    URL: download.microsoft.com/.../NDP48-x86-x64-AllOS-ENU.exe
  │     │    │    Lưu vào: %TEMP%\NDP48-x86-x64-AllOS-ENU.exe
  │     │    │
  │     │    ├─ File tải về > 50MB → DOTNET48_INSTALLER = file vừa tải
  │     │    └─ File tải về ≤ 50MB (lỗi/redirect) → fallback sang Local
  │     │
  │     └─ KHÔNG CÓ MẠNG (ping thất bại)
  │          └─ Bỏ qua bước download, dùng file Local
  │
  ├─ [Nếu DOTNET48_INSTALLER chưa xác định] → Kiểm tra file Local
  │     │
  │     ├─ File tồn tại + kích thước > 50MB
  │     │    └─ DOTNET48_INSTALLER = LOCAL_INSTALLER → tiếp tục cài
  │     │
  │     ├─ File tồn tại nhưng < 50MB
  │     │    └─ [LỖI] Báo file hỏng → goto :eof (dừng bước này)
  │     │
  │     └─ File không tồn tại
  │          └─ [LỖI] Hướng dẫn đặt file vào đúng thư mục → goto :eof
  │
  └─ [Cài đặt] DOTNET48_INSTALLER /q /norestart
        │
        ├─ errorLevel 0    → Cài thành công
        ├─ errorLevel 3010 → Cài thành công, cần RESTART máy
        ├─ errorLevel 1641 → Cài thành công, máy tự restart
        └─ Khác            → Cài thất bại, in mã lỗi
```

---

### BƯỚC 4 — Bật .NET Framework Features (Windows Feature)

| Windows Feature | Mục đích |
|----------------|----------|
| `NET-Framework-45-Features` | Nhóm tính năng .NET 4.5+ |
| `NET-Framework-45-Core` | Core runtime |
| `NET-Framework-45-ASPNET` | ASP.NET 4.5 integration |
| `NET-WCF-Services45` | WCF Services |
| `NET-WCF-HTTP-Activation45` | WCF HTTP Activation |
| `NET-WCF-TCP-Activation45` | WCF TCP Activation |
| `NET-WCF-Pipe-Activation45` | WCF Named Pipe Activation |

---

### BƯỚC 5 — Cấu hình Application Pool

**Tên pool:** `AppPool_DotNet48`

```
[Kiểm tra] AppPool đã tồn tại?
  │
  ├─ Chưa có → Tạo mới với cấu hình:
  │              managedRuntimeVersion : v4.0
  │              managedPipelineMode   : Integrated
  │              enable32BitAppOnWin64 : false
  │
  └─ Đã có   → Cập nhật cấu hình (không xóa, không tạo lại)

Sau khi tạo/cập nhật, áp dụng thêm:
  processModel.idleTimeout       : 00:00:00  (tắt idle timeout)
  recycling.periodicRestart.time : 00:00:00  (tắt auto recycle theo giờ)
  failure.rapidFailProtection    : false     (tắt rapid fail protection)
```

---

### BƯỚC 6 — Đăng ký ASP.NET với IIS

```
Kiểm tra tồn tại:
  %windir%\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe
  │
  ├─ Tồn tại  → Chạy: aspnet_regiis.exe -iru
  │              (-iru = Install & Register, không ảnh hưởng app đang chạy)
  └─ Không có → Cảnh báo, bỏ qua (log lại)
```

---

### BƯỚC 7 — Cấu hình Windows Firewall

```
Với mỗi port (80 và 443):
  │
  ├─ [Kiểm tra] Rule đã tồn tại? (netsh advfirewall show rule)
  │     ├─ Chưa có → Tạo rule mới: dir=in, action=allow, protocol=TCP
  │     └─ Đã có   → Bỏ qua, giữ nguyên
```

| Rule | Port | Protocol | Direction |
|------|------|----------|-----------|
| IIS HTTP Port 80 | 80 | TCP | Inbound |
| IIS HTTPS Port 443 | 443 | TCP | Inbound |

---

### BƯỚC 8 — Restart IIS & Kiểm tra kết quả

```
iisreset /stop → chờ 3 giây → iisreset /start

Kiểm tra sau restart:
  - sc query W3SVC  → Trạng thái dịch vụ IIS (World Wide Web)
  - sc query WAS    → Trạng thái Windows Activation Service
  - appcmd list apppool          → Danh sách Application Pool
  - reg query ... /v Version     → Phiên bản .NET Framework
  - reg query ... /v Release     → Release number .NET Framework
```

---

### Kết thúc — Cảnh báo và hướng dẫn

```
NEED_RESTART được đặt?
  └─ Có → In cảnh báo "RESTART máy trước khi dùng IIS"

In hướng dẫn bước tiếp theo:
  1. (Nếu cần) Restart máy nếu vừa cài .NET 4.8 lần đầu
  2. Tạo Website mới trong IIS Manager
  3. Trỏ Website vào Application Pool: AppPool_DotNet48
  4. Cấu hình Physical Path và Binding
  5. Deploy ứng dụng .NET 4.8 vào thư mục web
```

---

## Các hàm hỗ trợ (Subroutines)

| Hàm | Tham số | Mô tả |
|-----|---------|-------|
| `:install_feature` | `<FeatureName>` | Cài Windows Feature bằng PowerShell, log kết quả OK/SKIP |
| `:download_dotnet48` | _(không có)_ | Kiểm tra mạng, chọn nguồn, tải và cài .NET 4.8 |
| `:header` | `<Tiêu đề>` | In tiêu đề phân cách bước, ghi log |
| `:log` | `<Nội dung>` | Ghi dòng log kèm timestamp vào LOG_FILE |

---

## Biến môi trường chính

| Biến | Giá trị | Mô tả |
|------|---------|-------|
| `LOG_DIR` | `%~dp0logs` | Thư mục chứa log |
| `LOG_FILE` | `logs\setup_YYYYMMDD_HHMMSS.log` | File log của lần chạy hiện tại |
| `POOL_NAME` | `AppPool_DotNet48` | Tên Application Pool tạo ra |
| `LOCAL_INSTALLER` | `%~dp0ndp48-x86-x64-allos-enu.exe` | Đường dẫn file .NET 4.8 local |
| `HAS_INTERNET` | `1` / `0` | Kết quả kiểm tra ping internet |
| `DOTNET48_INSTALLER` | `<đường dẫn exe>` | Installer sẽ được dùng để cài |
| `NEED_RESTART` | `1` / _(không đặt)_ | Cần restart máy sau khi cài .NET |
| `NET_RELEASE` | `528040+` | Release number .NET đọc từ Registry |

---

## Mã thoát (Exit Code) quan trọng

| Mã | Nguồn | Ý nghĩa |
|----|-------|---------|
| `0` | Script / Installer | Thành công |
| `1` | Script | Không có quyền Administrator |
| `3010` | .NET Installer | Cài thành công, **cần restart máy** |
| `1641` | .NET Installer | Cài thành công, máy sẽ **tự restart** |
| Khác | .NET Installer | Cài thất bại |

---

## Lưu ý vận hành

> **Server không có mạng:** Đặt file `ndp48-x86-x64-allos-enu.exe` (116MB) cùng thư mục với file `.bat` trước khi chạy. Script sẽ tự phát hiện không có internet và dùng file local.

> **Server có mạng:** Script ưu tiên tải bản mới nhất từ Microsoft CDN. Nếu tải thất bại, tự động fallback sang file local.

> **Chạy lại an toàn:** Script kiểm tra trước khi tạo (feature, AppPool, firewall rule) — không tạo trùng, không ghi đè dữ liệu đang dùng.
