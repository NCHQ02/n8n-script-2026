#!/bin/bash
uninstall() {
    echo -e "\n${YELLOW}[*] Đang kiểm tra và gỡ bỏ công cụ tại: ${INSTALL_PATH}${NC}"
    if [[ -f "$INSTALL_PATH" ]]; then
        if sudo rm -f "$INSTALL_PATH"; then
            echo -e "${GREEN}[+] Đã gỡ bỏ '$INSTALL_PATH' thành công.${NC}"
        else
            echo -e "${RED}[!] Lỗi khi thực hiện lệnh gỡ bỏ (kiểm tra quyền sudo).${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Không tìm thấy file công cụ tại '${INSTALL_PATH}'.${NC}"
    fi
    exit 0
}

show_help() {
    echo "  --help              Hiển thị thông tin trợ giúp này"
    echo "  --install           Cài đặt N8N không cần tương tác (kết hợp --domain, --email)"
    echo "  --domain <str>      Truyền tên miền ứng dụng"
    echo "  --email <str>       Truyền email để đăng ký SSL HOẶC user N8N"
    echo "  --backup            Chạy Siêu Backup toàn hệ thống"
    echo "  --backup-cron       Chạy Backup dạng Cronjob (giữ lại 7 file)"
    echo "  --prune-cache       Chạy Dọn rác máy chủ (Docker Prune)"
    echo "  --disable-2fa       Tắt MFA cho một user (kết hợp --email)"
    echo "  --reset-owner       Reset tài khoản Owner N8N"
    echo "  --export            Export dữ liệu workflow/credentials (kết hợp --path)"
    echo "  --import            Import dữ liệu workflow/credentials (kết hợp --file)"
    echo "  --restore           Phục hồi toàn bộ server từ file nén (kết hợp --file)"
    echo "  --install-template  Cài template mẫu từ Marketplace (kết hợp --id)"
    echo "  --audit-json        Quét hệ thống và xuất kết quả ra định dạng JSON"
    echo "  --config-set        Set cấu hình môi trường .env (kết hợp --key, --value)"
    echo "  --change-domain     Đổi tên miền ứng dụng (kết hợp --domain)"
    echo "  --upgrade           Nâng cấp phiên bản N8N lên latest"
    echo "  --status            Xem trạng thái các dịch vụ"
    echo "  --restart           Khởi động lại các dịch vụ"
    echo "  --logs              Xem log của N8N"
    echo "  --update-script     Cập nhật script Cloud Manager"
    echo "  --reinstall         Xóa và cài đặt lại N8N toàn bộ"
    echo "  --redis-info        Lấy thông tin đăng nhập Redis"
    echo "  --db-info           Lấy thông tin đăng nhập PostgreSQL"
    echo "  --setup-cron        Cấu hình Auto-Backup theo lịch (kết hợp --value on/off)"
    echo "  --setup-tunnel      Cấu hình Cloudflare Tunnel kết nối Localhost ra Internet"
    echo "  --path <str>        Truyền đường dẫn thư mục"
    echo "  --file <str>        Truyền đường dẫn tập tin"
    echo "  --id <str>          Truyền ID (cho Marketplace)"
    echo "  --key <str>         Truyền tên biến môi trường (Ví dụ: GENERIC_TIMEZONE)"
    echo "  --value <str>       Truyền giá trị biến môi trường (Ví dụ: Asia/Ho_Chi_Minh)"
    echo "  --uninstall         Gỡ bỏ n8n-host khỏi hệ thống"
    exit 0
}

if [[ "$1" == "--help" ]]; then
    show_help
fi

export NON_INTERACTIVE="false"
export CLI_DOMAIN=""
export CLI_EMAIL=""
export CLI_PATH=""
export CLI_FILE=""
export CLI_ID=""
export CLI_KEY=""
export CLI_VALUE=""
CLI_ACTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) CLI_ACTION="install"; shift ;;
    --domain) shift; export CLI_DOMAIN="$1"; shift ;;
    --email) shift; export CLI_EMAIL="$1"; shift ;;
    --path) shift; export CLI_PATH="$1"; shift ;;
    --file) shift; export CLI_FILE="$1"; shift ;;
    --id) shift; export CLI_ID="$1"; shift ;;
    --key) shift; export CLI_KEY="$1"; shift ;;
    --value) shift; export CLI_VALUE="$1"; shift ;;
    --backup) CLI_ACTION="backup"; shift ;;
    --prune-cache) CLI_ACTION="prune-cache"; shift ;;
    --disable-2fa) CLI_ACTION="disable-2fa"; shift ;;
    --reset-owner) CLI_ACTION="reset-owner"; shift ;;
    --export) CLI_ACTION="export"; shift ;;
    --import) CLI_ACTION="import"; shift ;;
    --restore) CLI_ACTION="restore"; shift ;;
    --install-template) CLI_ACTION="install-template"; shift ;;
    --audit-json) CLI_ACTION="audit-json"; shift ;;
    --config-set) CLI_ACTION="config-set"; shift ;;
    --change-domain) CLI_ACTION="change-domain"; shift ;;
    --upgrade) CLI_ACTION="upgrade"; shift ;;
    --status) CLI_ACTION="status"; shift ;;
    --restart) CLI_ACTION="restart"; shift ;;
    --logs) CLI_ACTION="logs"; shift ;;
    --update-script) CLI_ACTION="update-script"; shift ;;
    --reinstall) CLI_ACTION="reinstall"; shift ;;
    --redis-info) CLI_ACTION="redis-info"; shift ;;
    --db-info) CLI_ACTION="db-info"; shift ;;
    --setup-cron) CLI_ACTION="setup-cron"; shift ;;
    --setup-tunnel) CLI_ACTION="setup-tunnel"; shift ;;
    --uninstall) uninstall; exit 0 ;;
    --help) show_help ;;
    --backup-cron) run_auto_backup; exit 0 ;;
    *) echo -e "${RED}[!] Tuỳ chọn không hợp lệ: $1${NC}"; show_help ;;
  esac
done

if [[ -n "$CLI_ACTION" ]]; then
  export NON_INTERACTIVE="true"
  case "$CLI_ACTION" in
    install) install ;;
    backup) run_auto_backup; echo -e "${GREEN}[+] Đã chạy xong Backup qua CLI!${NC}" ;;
    prune-cache) docker_prune ;;
    disable-2fa) disable_mfa ;;
    reset-owner) reset_user_login ;;
    export) export_all_data ;;
    import) import_data ;;
    restore) restore_server ;;
    install-template) open_marketplace ;;
    audit-json) system_audit ;;
    config-set) configure_environment ;;
    change-domain) change_domain ;;
    upgrade) upgrade_n8n_version ;;
    status) show_status ;;
    restart) restart_services ;;
    logs) view_logs ;;
    update-script) update_script ;;
    reinstall) reinstall_n8n ;;
    redis-info) get_redis_info ;;
    db-info) get_database_info ;;
    setup-cron) configure_auto_backup ;;
    setup-tunnel) setup_cloudflare_tunnel ;;
  esac
  exit 0
fi


# --- Hiển thị Menu Chính ---
show_menu() {
  clear
  printf "${CYAN}+==================================================================================+${NC}\n"
  printf "${CYAN}|                                N8N Cloud Manager                                 |${NC}\n"
  printf "${CYAN}|                          Create & Custom By NCHQ02                             |${NC}\n"
  printf "${CYAN}+==================================================================================+${NC}\n"
  echo ""
  echo -e " ${YELLOW}Phím tắt: Nhấn Ctrl + C hoặc nhập 0 để thoát${NC}"
  echo -e " ${GREEN}Xem hướng dẫn:${NC} ${CYAN}https://docs.google.com/document/d/1EmJObjeM-77QJcekn1IBm8JEZyxi5_HP49VVsEr6Dwk/edit?usp=sharing${NC}"
  echo "------------------------------------------------------------------------------------"
  
  # Nhóm 1: Cài đặt và Cơ bản
  echo -e " ${YELLOW}[ 1. CÀI ĐẶT & CƠ BẢN ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "1)" "Cài đặt N8N mới" "2)" "Thay đổi Tên miền truy cập"
  printf " %-3s %-35s %-3s %s\n" "3)" "Nâng cấp phiên bản N8N" "4)" "Cấu hình Môi trường (Timezone,...)"
  printf " %-3s %-35s\n" "21)" "Cấu hình Cloudflare Tunnel (Local)"

  # Nhóm 2: Tài khoản & Bảo mật
  echo -e "\n ${YELLOW}[ 2. TÀI KHOẢN & BẢO MẬT ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "5)" "Tắt/Bật xác thực 2 bước (2FA/MFA)" "6)" "Đặt lại mật khẩu Quản trị viên"
  
  # Nhóm 3: Dữ liệu (Backup & Restore)
  echo -e "\n ${YELLOW}[ 3. DỮ LIỆU & SAO LƯU ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "7)" "Export (Tải Workflows & Credential)" "8)" "Import (Phục hồi Workflows/Creds)"
  printf " %-3s %-35s %-3s %s\n" "9)" "Siêu Backup (Toàn bộ Server -> Zip)" "10)" "Khôi phục toàn bộ hệ thống từ Zip"
  printf " %-3s %-35s %-3s %s\n" "11)" "Cấu hình Auto-Backup theo lịch (Cron)" "12)" "Marketplace (Cài đặt Workflow mẫu)"

  # Nhóm 4: Hệ thống & Logs
  echo -e "\n ${YELLOW}[ 4. QUẢN TRỊ HỆ THỐNG ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "13)" "Xem Thông tin tài khoản Redis" "14)" "Xem Thông tin tài khoản Database"
  printf " %-3s %-35s %-3s %s\n" "15)" "Xem Trạng thái/Tài nguyên (RAM/CPU)" "16)" "Khởi động lại (Restart N8N Container)"
  printf " %-3s %-35s %-3s %s\n" "17)" "Xem Error Logs N8N (Terminal)" "18)" "Dọn rác máy chủ (Docker Prune)"
  printf " %-3s %-35s %-3s ${RED}%s${NC}\n" "19)" "System & Security Audit" "20)" "Cập nhật N8N Cloud Manager"

  # Nhóm Nguy hiểm
  echo -e "\n ${RED}[ 5. KHU VỰC NGUY HIỂM ]${NC}"
  printf " %-3s %-35s\n" "99)" "Xóa sạch Dữ liệu N8N và Cài đặt lại"

  echo "------------------------------------------------------------------------------------"
  read -p "$(echo -e ${CYAN}'Nhập lựa chọn của bạn (0-99) [ 0 = Thoát! ]: '${NC})" choice
  echo ""
}

while true; do
  show_menu
  case "$choice" in
    1) install ;;
    2) change_domain ;;
    3) upgrade_n8n_version ;;
    4) configure_environment ;;
    5) disable_mfa ;;
    6) reset_user_login ;;
    7) export_all_data ;;
    8) import_data ;;
    9) backup_server ;;
    10) restore_server ;;
    11) configure_auto_backup ;;
    12) open_marketplace ;;
    13) get_redis_info ;;
    14) get_database_info ;;
    15) show_status ;;
    16) restart_services ;;
    17) view_logs ;;
    18) docker_prune ;;
    19) system_audit ;;
    20) update_script ;;
    21) setup_cloudflare_tunnel ;;
    99) reinstall_n8n ;;
    0)
        echo "Tạm Biệt nhé!  - NCHQ02 mãi iu Bạn!"
        echo "Design By Nguyễn Cao Hoàng Quý!"
        exit 0
        ;;
    *)
      if ! [[ "$choice" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${RED}[!] Lựa chọn không đúng. Vui lòng chọn lại.${NC}"
      fi
      sleep 1
      ;;
  esac
done
