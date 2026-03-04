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
  
  # Nhóm Cài đặt, Cập nhật & Tên miền
  echo -e " ${YELLOW}[ CƠ BẢN & MỞ RỘNG ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "1)" "Cài đặt N8N" "2)" "Thay đổi tên miền truy cập"
  printf " %-3s %-35s %-3s %s\n" "3)" "Nâng cấp phiên bản N8N" "12)" "Cấu hình Môi trường (Biến ENV)"
  
  # Nhóm Tài khoản & Bảo mật
  echo -e "\n ${YELLOW}[ TÀI KHOẢN & BẢO MẬT ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "4)" "Tắt/Bật xác thực 2 bước (2FA)" "5)" "Đặt lại mật khẩu quản trị viên"
  
  # Nhóm Dữ liệu
  echo -e "\n ${YELLOW}[ SAO LƯU & DỮ LIỆU ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "6)" "Export (Workflow & Credential)" "7)" "Import (Workflow & Credential)"
  printf " %-3s %-35s %-3s %s\n" "13)" "Backup máy chủ N8N (.tar.gz)" "14)" "Restore hệ thống từ Backup"

  # Nhóm Hệ thống 
  echo -e "\n ${YELLOW}[ HỆ THỐNG & MONITORING ]${NC}"
  printf " %-3s %-35s %-3s %s\n" "8)" "Xem Thông tin kết nối Redis" "9)" "Xem Trạng thái Node (CPU/RAM)"
  printf " %-3s %-35s %-3s %s\n" "10)" "Khởi động lại (Restart N8N)" "11)" "Xem Logs N8N (Tail Logs)"
  printf " %-3s %-35s %-3s ${RED}%s${NC}\n" "15)" "Dọn rác (Docker Prune)" "99)" "Xóa sạch Data N8N và Cài lại"

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
    4) disable_mfa ;;
    5) reset_user_login ;;
    6) export_all_data ;;
    7) import_data ;;
    8) get_redis_info ;;
    9) show_status ;;
    10) restart_services ;;
    11) view_logs ;;
    12) configure_environment ;;
    13) backup_server ;;
    14) restore_server ;;
    15) docker_prune ;;
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
