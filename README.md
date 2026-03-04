# N8N Cloud Manager

> Công cụ quản lý N8N toàn diện trên VPS — cài đặt tự động, quản lý SSL, backup & restore dữ liệu.
>
> **Custom by Nguyễn Cao Hoàng Quý (BanhMiSaiGon)**

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

## 📋 Các tính năng

| Số    | Chức năng         | Mô tả                                                         |
| ----- | ----------------- | ------------------------------------------------------------- |
| **1** | Cài đặt N8N       | Cài đặt đầy đủ N8N với Docker, PostgreSQL, Redis, Nginx + SSL |
| **2** | Thay đổi tên miền | Đổi domain và tự động cấp lại chứng chỉ SSL                   |
| **3** | Nâng cấp N8N      | Pull image `latest` mới nhất từ Docker Hub                    |
| **4** | Tắt 2FA/MFA       | Tắt xác thực 2 bước cho một tài khoản cụ thể                  |
| **5** | Đặt lại đăng nhập | Reset tài khoản owner để đăng nhập lại từ đầu                 |
| **6** | Export dữ liệu    | Xuất workflows & credentials, tạo link tải xuống tạm thời     |
| **7** | Import dữ liệu    | Import từ file template `import-workflow-credentials.json`    |
| **8** | Thông tin Redis   | Hiển thị host, port, password kết nối Redis                   |
| **9** | Xóa & cài lại     | Xóa toàn bộ và cài đặt lại N8N từ đầu                         |
| **0** | Thoát             | Thoát khỏi công cụ                                            |

---

## 🗂️ Cấu trúc dự án

```
n8n_script/
├── src/                          # Mã nguồn modular (không phân phối trực tiếp)
│   ├── lib/
│   │   ├── globals.sh            # Màu sắc và biến toàn cục
│   │   ├── utils.sh              # Hàm phụ trợ (spinner, logging, ...)
│   │   ├── setup.sh              # Các bước cài đặt (Docker, Nginx, SSL, ...)
│   │   └── features.sh           # Các chức năng menu (install, export, import, ...)
│   └── main.sh                   # Menu chính và vòng lặp điều khiển
├── templates/
│   └── import-workflow-credentials.json  # Template import mặc định
├── build.sh                      # Build script: bundle src/ → n8n-host.sh
├── install.sh                    # Script cài đặt công cụ lên hệ thống
└── n8n-host.sh                   # ⚙️ File phân phối (do build.sh tạo ra — không sửa trực tiếp)
```

> **Lưu ý:** `n8n-host.sh` được tạo tự động từ `src/`. Chỉ sửa các file trong `src/` rồi chạy `build.sh`.

---

## 🔧 Phát triển & Build

### Sửa mã nguồn

```bash
# 1. Sửa file trong src/
vim src/lib/features.sh

# 2. Rebuild n8n-host.sh từ sources
bash build.sh

# 3. Kiểm tra kết quả
bash n8n-host.sh --help
```

### Cấu trúc src/

| File                  | Nội dung                                                         |
| --------------------- | ---------------------------------------------------------------- |
| `src/lib/globals.sh`  | Định nghĩa màu ANSI, biến đường dẫn, tên container               |
| `src/lib/utils.sh`    | `check_root`, `spinner`, `run_silent_command`, `update_env_file` |
| `src/lib/setup.sh`    | Cài đặt Docker, Nginx, Certbot/SSL, tạo docker-compose           |
| `src/lib/features.sh` | Mọi chức năng trong menu (install, change_domain, export...)     |
| `src/main.sh`         | `show_menu`, vòng lặp `while`, `--help`, `--uninstall`           |

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

Để xóa toàn bộ N8N và dữ liệu: chọn **mục 9** trong menu.

---

## 📚 Tài liệu tham khảo

- [Hướng dẫn sử dụng đầy đủ](https://docs.google.com/document/d/1EmJObjeM-77QJcekn1IBm8JEZyxi5_HP49VVsEr6Dwk/edit?usp=sharing)
- [N8N Official Docs](https://docs.n8n.io)
