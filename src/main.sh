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
    echo "N8N Cloud Manager - Công cụ quản lý N8N trên CloudFly"
    echo "Cách sử dụng: n8n-host [tuỳ chọn]"
    echo "Tuỳ chọn:"
    echo "  --help      Hiển thị thông tin trợ giúp này"
    echo "  --uninstall Gỡ bỏ n8n-host khỏi hệ thống"
    exit 0
}

if [[ "$1" == "--help" ]]; then
    show_help
fi

if [[ "$1" == "--uninstall" ]]; then
    uninstall
fi

# --- Hiển thị Menu Chính ---
show_menu() {
  clear
  printf "${CYAN}+==================================================================================+${NC}\n"
  printf "${CYAN}|                                N8N Cloud Manager                                 |${NC}\n"
  printf "${CYAN}|                          Create & Custom By BanhMiSaiGon                         |${NC}\n"
  printf "${CYAN}+==================================================================================+${NC}\n"
  echo ""
  echo -e " ${YELLOW}Phím tắt: Nhấn Ctrl + C hoặc nhập 0 để thoát${NC}"
  echo -e " ${GREEN}Xem hướng dẫn:${NC} ${CYAN}https://docs.google.com/document/d/1EmJObjeM-77QJcekn1IBm8JEZyxi5_HP49VVsEr6Dwk/edit?usp=sharing${NC}"
  echo "------------------------------------------------------------------------------------"
  
  # Nhóm 1: Cài đặt và Cơ bản
  echo -e " ${YELLOW}[ 1. CÀI ĐẶT & CƠ BẢN ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "1)" "Cài đặt N8N mới" "2)" "Thay đổi Tên miền truy cập"
  printf " %-3s %-35s %-3s %s\n" "3)" "Nâng cấp phiên bản N8N" "4)" "Cấu hình Môi trường (Timezone,...)"
  
  # Nhóm 2: Tài khoản & Bảo mật
  echo -e "\n ${YELLOW}[ 2. TÀI KHOẢN & BẢO MẬT ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "5)" "Tắt/Bật xác thực 2 bước (2FA/MFA)" "6)" "Đặt lại mật khẩu Quản trị viên"
  
  # Nhóm 3: Dữ liệu (Backup & Restore)
  echo -e "\n ${YELLOW}[ 3. DỮ LIỆU & SAO LƯU ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "7)" "Export (Tải Workflows & Credential)" "8)" "Import (Phục hồi Workflows/Creds)"
  printf " %-3s %-35s %-3s %s\n" "9)" "Siêu Backup (Toàn bộ Server -> Zip)" "10)" "Khôi phục toàn bộ hệ thống từ Zip"

  # Nhóm 4: Hệ thống & Logs
  echo -e "\n ${YELLOW}[ 4. QUẢN TRỊ HỆ THỐNG ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "11)" "Xem Thông tin tài khoản Redis" "12)" "Xem Thông tin tài khoản Database"
  printf " %-3s %-35s %-3s %s\n" "13)" "Xem Trạng thái/Tài nguyên (RAM/CPU)" "14)" "Khởi động lại (Restart N8N Container)"
  printf " %-3s %-35s %-3s ${RED}%s${NC}\n" "15)" "Xem Error Logs N8N (Terminal)" "16)" "Dọn rác máy chủ (Docker Prune)"

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
    11) get_redis_info ;;
    12) get_database_info ;;
    13) show_status ;;
    14) restart_services ;;
    15) view_logs ;;
    16) docker_prune ;;
    99) reinstall_n8n ;;
    0)
        echo "Tạm Biệt nhé!  - BanhMiSaiGon mãi iu Bạn!"
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
