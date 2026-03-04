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
  printf " %-3s %-35s %-3s ${YELLOW}%s${NC}\n" "1)" "Cài đặt N8N" "6)" "Export tất cả (workflow & credentials)"
  printf " %-3s %-35s %-3s %s\n" "2)" "Thay đổi tên miền" "7)" "Import workflow & credentials"
  printf " %-3s %-35s %-3s ${GREEN}%s${NC}\n" "3)" "Nâng cấp phiên bản N8N" "8)" "Lấy thông tin Redis"
  printf " %-3s %-35s %-3s ${RED}%s${NC}\n" "4)" "Tắt xác thực 2 bước (2FA/MFA)" "9)" "Xóa N8N và cài đặt lại"
  printf " %-3s %-35s\n" "5)" "Đặt lại thông tin đăng nhập"
  echo "------------------------------------------------------------------------------------"
  read -p "$(echo -e ${CYAN}'Nhập lựa chọn của bạn (1-9) [ 0 = Thoát! ]: '${NC})" choice
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
    9) reinstall_n8n ;;
    *)
      if [[ "$choice" == "0" ]]; then
        echo "Tạm Biệt nhé!  - BanhMiSaiGon mãi iu Bạn!"
        echo "Design By Nguyễn Cao Hoàng Quý!"
        exit 0
      elif ! [[ "$choice" =~ ^[1-9]$ ]]; then
        echo -e "${RED}[!] Lựa chọn không đúng. Vui lòng chọn lại.${NC}"
      fi
      sleep 1
      ;;
  esac
done
