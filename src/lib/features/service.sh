# --- Quản lý Dịch vụ (Service Control) ---

# Xem trạng thái các container N8N và Redis
show_status() {
  clear
  echo -e "${CYAN}=== TRẠNG THÁI DỊCH VỤ ===${NC}"
  if [ ! -d "$N8N_DIR" ]; then
    echo -e "${RED}[!] Thư mục cài đặt ${N8N_DIR} không tồn tại. Vui lòng cài đặt N8N trước.${NC}"
    if [[ "$NON_INTERACTIVE" != "true" ]]; then read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."; fi
    return 1
  fi

  cd "$N8N_DIR" || return 1
  echo -e "${YELLOW}Đang lấy trạng thái từ Docker Compose...${NC}"
  echo "------------------------------------------------------------------------------------"
  $DOCKER_COMPOSE_CMD ps
  echo "------------------------------------------------------------------------------------"
  
  # Hiển thị mức sử dụng tài nguyên nhanh
  echo -e "\n${YELLOW}Tài nguyên sử dụng (CPU/RAM):${NC}"
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep -E "Name|${N8N_CONTAINER_NAME}|n8n_redis|n8n_postgres|redis|postgres" || echo "Không có container nào đang chạy."
  
  echo ""
  if [[ "$NON_INTERACTIVE" != "true" ]]; then read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."; fi
}

# Khởi động lại N8N và Redis
restart_services() {
  clear
  echo -e "${CYAN}=== KHỞI ĐỘNG LẠI DỊCH VỤ ===${NC}"
  if [ ! -d "$N8N_DIR" ]; then
    echo -e "${RED}[!] Thư mục cài đặt ${N8N_DIR} không tồn tại.${NC}"
    sleep 2
    return 1
  fi

  cd "$N8N_DIR" || return 1
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    read -p "Bạn có chắc chắn muốn khởi động lại hệ thống? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Đã hủy thao tác."
      sleep 1
      return 0
    fi
  fi

  # Restart N8N and Redis
  run_silent_command "Đang khởi động lại Docker Compose services" "cd $N8N_DIR && $DOCKER_COMPOSE_CMD restart" false
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Hệ thống đã được khởi động lại thành công!${NC}"
    echo -e "${YELLOW}[*] Lưu ý: Có thể mất 1-2 phút để N8N khởi động lên hoàn toàn.${NC}"
  fi
  if [[ "$NON_INTERACTIVE" != "true" ]]; then sleep 3; fi
}

# Xem logs của N8N
view_logs() {
  clear
  echo -e "${CYAN}=== XEM LOGS N8N ===${NC}"
  if [ ! -d "$N8N_DIR" ]; then
    echo -e "${RED}[!] Thư mục cài đặt ${N8N_DIR} không tồn tại.${NC}"
    if [[ "$NON_INTERACTIVE" != "true" ]]; then sleep 2; fi
    return 1
  fi

  cd "$N8N_DIR" || return 1
  echo -e "${YELLOW}[*] Đang hiển thị 100 dòng log gần nhất của N8N.${NC}"
  echo -e "${YELLOW}[*] Ấn Ctrl+C để thoát khỏi màn hình xem log.${NC}"
  echo "------------------------------------------------------------------------------------"
  
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    $DOCKER_COMPOSE_CMD logs --tail=100 $N8N_SERVICE_NAME
  else
    $DOCKER_COMPOSE_CMD logs -f --tail=100 $N8N_SERVICE_NAME
  fi
  
  echo "------------------------------------------------------------------------------------"
  if [[ "$NON_INTERACTIVE" != "true" ]]; then read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."; fi
}
