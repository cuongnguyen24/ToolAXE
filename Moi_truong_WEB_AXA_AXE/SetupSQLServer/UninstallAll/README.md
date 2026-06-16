# Uninstall SQL Server + SSMS

Tool nay dung de go manh tay:

- SQL Server instance theo `InstanceName` trong `..\config\CustomerSettings.json`
- SSMS neu da cai
- firewall rule `SQL Server TCP <port>`
- thu muc du lieu / log / tempdb / backup
- thu muc chuong trinh SQL / SSMS con sot lai

Tool nay huong toi server test de dua may ve trang thai gan nhu "chua tung cai".

## Cach dung

Chay:

```text
Uninstall-SQLServer-SSMS.bat
```

bang quyen Administrator.

## Luu y

- Tool can media SQL offline trong thu muc da khai bao, vi SQL Server uninstall dung `setup.exe` de go instance.
- Tool SE XOA DU LIEU trong cac thu muc data/log/tempdb/backup da cau hinh.
- Tool cung thu xoa thu muc chuong trinh SQL / SSMS con sot lai sau khi uninstall.
- Chi dung cho server test ma ban chap nhan mat het database, log, backup va file con lai.
- Tool ghi log vao `UninstallAll\logs\`.
