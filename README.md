# N8N Cloud Manager

> Công cụ quản lý N8N toàn diện trên VPS — cài đặt tự động, quản lý SSL, backup & restore dữ liệu.
>
> **Custom by Nguyễn Cao Hoàng Quý (NCHQ02)**

---

## 🚀 Cài đặt nhanh

Chạy một lệnh duy nhất để cài đặt:

```bash
sudo bash -c 'URL=https://raw.githubusercontent.com/NCHQ02/n8n-script-2026/main/install.sh && if [ -f /usr/bin/curl ]; then curl -fsSL -o install.sh $URL; else wget -qO install.sh $URL; fi; bash install.sh'
```

Hoặc tải trực tiếp rồi chạy:

```bash
sudo bash install.sh
```

Sau khi cài đặt, gọi công cụ bằng lệnh:

```bash
n8n-host
```

---

## 📋 Các tính năng (Menu Tương Tác)

Công cụ cung cấp một menu điều khiển trực quan với các nhóm tính năng:

**1. Cài đặt & Cơ bản**

- Cài đặt N8N mới
- Thay đổi Tên miền truy cập
- Nâng cấp phiên bản N8N
- Cấu hình Môi trường (Timezone,...)

**2. Tài khoản & Bảo mật**

- Tắt/Bật xác thực 2 bước (2FA/MFA)
- Đặt lại mật khẩu Quản trị viên

**3. Dữ liệu & Sao lưu**

- Export (Tải Workflows & Credential)
- Import (Phục hồi Workflows/Creds)
- Siêu Backup (Toàn bộ Server -> Zip)
- Khôi phục toàn bộ hệ thống từ Zip
- Cấu hình Auto-Backup theo lịch (Cron)
- Marketplace (Cài đặt Workflow mẫu)

**4. Quản trị hệ thống**

- Xem Thông tin tài khoản Redis & Database
- Xem Trạng thái/Tài nguyên (RAM/CPU)
- Khởi động lại (Restart N8N Container)
- Xem Error Logs N8N (Terminal)
- Dọn rác máy chủ (Docker Prune)
- System & Security Audit
- Cập nhật N8N Cloud Manager

**5. Khu vực nguy hiểm**

- Xóa sạch Dữ liệu N8N và Cài đặt lại

---

## ⚡ Chế độ CLI (Tự động hóa / CI/CD)

Bạn có thể gọi trực tiếp các lệnh mà không cần qua Menu (Non-interactive mode):

```bash
# Quản trị hệ thống
n8n-host --install --domain <domain> --email <email>
n8n-host --change-domain --domain <new_domain>
n8n-host --upgrade
n8n-host --reinstall
n8n-host --update-script
n8n-host --status
n8n-host --restart
n8n-host --logs
n8n-host --prune-cache

# Sao lưu & Phục hồi
n8n-host --backup
n8n-host --backup-cron
n8n-host --restore --file <path_to_zip>
n8n-host --setup-cron --value <on|off>
n8n-host --export --path <dir>
n8n-host --import --file <path_to_json>

# Tài khoản & Bảo mật
n8n-host --disable-2fa --email <email>
n8n-host --reset-owner
n8n-host --audit-json

# Thông tin & Cấu hình
n8n-host --config-set --key <KEY> --value <VALUE>
n8n-host --db-info
n8n-host --redis-info

# Tiện ích
n8n-host --install-template --id <template_id>
n8n-host --uninstall
```

---

## 🗂️ Cấu trúc dự án

```
n8n_script/
├── src/                          # Mã nguồn modular (không phân phối trực tiếp)
│   ├── lib/
│   │   ├── globals.sh            # Màu sắc và biến toàn cục
│   │   ├── utils.sh              # Hàm phụ trợ (spinner, logging, ...)
│   │   ├── setup.sh              # Các bước cài đặt (Docker, Nginx, SSL, ...)
│   │   └── features/             # Các chức năng menu (mỗi file = 1 nhóm tính năng)
│   │       ├── install.sh        # install, reinstall_n8n
│   │       ├── domain.sh         # change_domain
│   │       ├── upgrade.sh        # upgrade_n8n_version
│   │       ├── auth.sh           # disable_mfa, reset_user_login
│   │       ├── data.sh           # export_all_data, import_data
│   │       ├── backup.sh         # backup_server, restore_server, cron_jobs
│   │       ├── database.sh       # get_database_info
│   │       ├── config.sh         # configure_environment
│   │       ├── marketplace.sh    # open_marketplace
│   │       ├── cleanup.sh        # docker_prune
│   │       ├── audit.sh          # system_audit
│   │       ├── self_update.sh    # update_script
│   │       ├── service.sh        # show_status, restart, view_logs
│   │       └── redis.sh          # get_redis_info
│   └── main.sh                   # Chứa show_menu, điều hướng arguments CLI và vòng lặp chính
├── dist/
│   └── n8n-host.sh               # ⚙️ File phân phối (do build.sh tạo ra — không sửa trực tiếp)
├── templates/
│   └── import-workflow-credentials.json  # Template import mặc định
├── build.sh                      # Build script: bundle src/ → dist/n8n-host.sh
└── install.sh                    # Script cài đặt công cụ lên hệ thống
```

> **Lưu ý:** `dist/n8n-host.sh` được tạo tự động từ `src/`. Chỉ sửa các file trong `src/` rồi chạy `build.sh`.

---

## 🔧 Phát triển & Build

### Sửa mã nguồn

```bash
# 1. Sửa file trong src/ (ví dụ chỉnh tính năng install)
vim src/lib/features/install.sh

# 2. Rebuild từ sources
bash build.sh

# 3. Kiểm tra kết quả
bash dist/n8n-host.sh --help
```

### Cấu trúc src/

| File / Thư mục                    | Nội dung                                                        |
| --------------------------------- | --------------------------------------------------------------- |
| `src/lib/globals.sh`              | Định nghĩa biến toàn cục, màu sắc, tên container, paths         |
| `src/lib/utils.sh`                | Các hàm tiện ích: `spinner()`, log, kiểm tra quyền              |
| `src/lib/setup.sh`                | Khởi tạo Docker, Nginx, chứng chỉ SSL                           |
| `src/lib/features/install.sh`     | Cài đặt mới (`install`), Cài đặt lại (`reinstall_n8n`)          |
| `src/lib/features/domain.sh`      | Đổi tên miền (`change_domain`)                                  |
| `src/lib/features/upgrade.sh`     | Nâng cấp N8N (`upgrade_n8n_version`)                            |
| `src/lib/features/auth.sh`        | Quản lý xác thực (`disable_mfa`, `reset_user_login`)            |
| `src/lib/features/data.sh`        | Nhập/xuất workflows/creds (`export_all_data`, `import_data`)    |
| `src/lib/features/backup.sh`      | Quản lý hệ thống sao lưu/khôi phục (`backup_server`, cron...)   |
| `src/lib/features/config.sh`      | Quản lý biến môi trường (`configure_environment`)               |
| `src/lib/features/database.sh`    | Thông tin Postgres (`get_database_info`)                        |
| `src/lib/features/redis.sh`       | Thông tin Redis (`get_redis_info`)                              |
| `src/lib/features/service.sh`     | Trạng thái, logs, restart (`show_status`, `restart_services`)   |
| `src/lib/features/marketplace.sh` | Cài đặt workflow từ N8N Marketplace                             |
| `src/lib/features/cleanup.sh`     | Dọn dẹp cache / logs (`docker_prune`)                           |
| `src/lib/features/audit.sh`       | Kiểm tra bảo mật và tài nguyên hệ thống (`system_audit`)        |
| `src/lib/features/self_update.sh` | Tự động cập nhật script phân phối (`update_script`)             |
| `src/main.sh`                     | Vòng lặp `show_menu` và router argument `CLI_ACTION` (`--help`) |

---

## 🖥️ Yêu cầu hệ thống

- **OS:** Ubuntu 20.04+ hoặc Debian 11+ (có hỗ trợ cơ bản cho RHEL/CentOS)
- **RAM:** Tối thiểu 2GB (khuyến nghị 4GB)
- **Disk:** Tối thiểu 20GB
- **Domain:** Tên miền đã trỏ DNS A record về IP server
- **Port:** 80 và 443 không bị chặn bởi firewall

---

## 📦 Stack công nghệ

| Thành phần | Phiên bản               |
| ---------- | ----------------------- |
| N8N        | `latest`                |
| PostgreSQL | `15-alpine`             |
| Redis      | `7-alpine`              |
| Nginx      | Từ apt                  |
| SSL        | Let's Encrypt (Certbot) |

---

## 🗑️ Gỡ bỏ

```bash
n8n-host --uninstall
```

Lệnh này chỉ gỡ bỏ binary `n8n-host` khỏi hệ thống. Dữ liệu N8N vẫn được giữ nguyên.

Để xóa toàn bộ N8N và dữ liệu: chọn **mục 99** trong menu hoặc dùng lệnh `n8n-host --reinstall`.

---

## 📚 Tài liệu tham khảo

- [Hướng dẫn sử dụng đầy đủ](https://docs.google.com/document/d/1EmJObjeM-77QJcekn1IBm8JEZyxi5_HP49VVsEr6Dwk/edit?usp=sharing)
- [N8N Official Docs](https://docs.n8n.io)
