# --- Tự động cập nhật Script ---

update_script() {
  clear
  echo -e "${CYAN}=== CẬP NHẬT N8N CLOUD MANAGER ===${NC}"
  echo -e "${YELLOW}[*] Hệ thống sẽ tải phiên bản script (n8n-host) mới nhất từ kho lưu trữ của NCHQ02...${NC}"
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    read -p "Bạn có muốn tiếp tục cập nhật không? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Đã hủy thao tác."
      sleep 1
      return 0
    fi
  fi

  # URL thô (raw.githubusercontent.com) của file dist/n8n-host.sh (Sẽ tải trực tiếp script đã build)
  # Có thể tùy chỉnh link repo tại đây
  local UPDATE_URL="https://raw.githubusercontent.com/NCHQ02/n8n-script-2026/main/dist/n8n-host.sh"
  local TEMP_FILE="/tmp/n8n-host-update.sh"

  echo -e "\nĐang tải xuống phiên bản mới nhất..."
  if curl -sSL --fail "$UPDATE_URL" -o "$TEMP_FILE"; then
    echo -e "${GREEN}[+] Tải thành công. Đang ghi đè file hiện tại...${NC}"
    sudo mv "$TEMP_FILE" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}[+] Đã Cập nhật xong N8N Cloud Manager.${NC}"
    echo -e "${YELLOW}Vui lòng chạy lại lệnh 'n8n-host' để trải nghiệm phiên bản mới nhất!${NC}\n"
    exit 0
  else
    echo -e "${RED}[!] Không thể tải phiên bản mới. Kiểm tra kết nối Internet hoặc link Repo Repository Github.${NC}"
    sudo rm -f "$TEMP_FILE"
    echo ""
    if [[ "$NON_INTERACTIVE" != "true" ]]; then read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."; fi
  fi
}
