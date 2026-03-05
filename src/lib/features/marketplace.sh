# --- Marketplace (Chợ Templates N8N) ---

open_marketplace() {
  while true; do
    clear
    echo -e "${CYAN}=== KHÁM PHÁ & CÀI ĐẶT WORKFLOW TỰ ĐỘNG (MARKETPLACE) ===${NC}"
    echo -e "${YELLOW}Chào mừng đến với chợ Template của NCHQ02!${NC}"
    echo -e "${GREEN}Hệ thống sẽ tải danh sách các Workflow có sẵn từ kho lưu trữ GitHub và tự động cài đặt vào N8N của bạn.${NC}"
    echo "--------------------------------------------------------"
    
    # Định nghĩa danh sách các mẫu (id|tên|link json)
    # Tương lai có thể cào tự động bằng API Github, nhưng fix cứng mảng sẽ an toàn và nhanh hơn cho Bash Script
    local templates=(
      "1|Luồng import workflow credential|import-workflow-credentials.json"
    )

    local choice
    if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_ID" ]]; then
      choice="$CLI_ID"
    else
      # Hiển thị Menu
      for item in "${templates[@]}"; do
        local id=$(echo "$item" | cut -d'|' -f1)
        local name=$(echo "$item" | cut -d'|' -f2)
        printf " [%-2s] %s\n" "$id" "$name"
      done

      echo "--------------------------------------------------------"
      echo " [0]  Quay lại Menu Chính"
      echo ""
      
      read -p "Chọn Workflow bạn muốn cài đặt (0-${#templates[@]}): " choice
      
      if [ "$choice" -eq 0 ] 2>/dev/null; then
        return 0
      fi
    fi
    
    # Tìm kiếm choice trong danh sách
    local selected_name=""
    local selected_file=""
    
    for item in "${templates[@]}"; do
      local id=$(echo "$item" | cut -d'|' -f1)
      if [ "$id" == "$choice" ]; then
        selected_name=$(echo "$item" | cut -d'|' -f2)
        selected_file=$(echo "$item" | cut -d'|' -f3)
        break
      fi
    done
    
    if [[ -z "$selected_name" ]]; then
      echo -e "${RED}[!] Lựa chọn không hợp lệ (ID: $choice).${NC}"
      if [[ "$NON_INTERACTIVE" == "true" ]]; then return 1; fi
      sleep 1
      continue
    fi
    
    echo -e "\n${YELLOW}[*] Bạn đã chọn: ${CYAN}${selected_name}${NC}"
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
      read -p "Phiên bản này sẽ được tải xuống và Import trực tiếp vào N8N. Tiếp tục? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Đã hủy."
        sleep 1
        continue
      fi
    fi
    
    local BASE_URL="https://raw.githubusercontent.com/NCHQ02/n8n-script-2026/main/templates"
    local TARGET_URL="${BASE_URL}/${selected_file}"
    local TEMP_JSON="/tmp/n8n_marketplace_template_$$.json"
    
    start_spinner "Đang tải dữ liệu mẫu từ GitHub..."
    if curl -sSL --fail "$TARGET_URL" -o "$TEMP_JSON"; then
      stop_spinner
      echo -e "${GREEN}[+] Tải thành công file cấu hình!${NC}"
      
      start_spinner "Đang cài đặt Workflow vào N8N..."
      local container_temp_import_dir="/home/node/.n8n/temp_marketplace_$$"
      
      # Tạo folder tạm trong container
      sudo docker exec -u node "${N8N_CONTAINER_NAME}" mkdir -p "${container_temp_import_dir}"
      
      # Copy file json vào container
      sudo docker cp "${TEMP_JSON}" "${N8N_CONTAINER_NAME}:${container_temp_import_dir}/template.json"
      
      # Import workflow
      local import_result
      import_result=$(sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n import:workflow --input="${container_temp_import_dir}/template.json" 2>&1)
      local import_exit_code=$?
      
      # Xoá folder tạm
      sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_import_dir}"
      sudo rm -f "$TEMP_JSON"
      
      stop_spinner
      
      if [ $import_exit_code -eq 0 ]; then
        echo -e "${GREEN}[+] Khởi tạo thành công! Workflow đã được đưa vào Database của N8N.${NC}"
        echo -e "${YELLOW}Lưu ý: Bạn hãy đăng nhập vào N8N để cấu hình Credentials (Api key, Token) cho luồng chạy nhé!${NC}"
      else
        echo -e "${RED}[!] Cài đặt thất bại! Chi tiết lỗi:${NC}"
        echo "$import_result"
      fi
    else
      stop_spinner
      echo -e "${RED}[!] Lỗi: Không thể tải file ${selected_file} từ GitHub.${NC}"
      echo -e "${YELLOW}File mẫu này có thể chưa được tác giả NCHQ02 upload lên kho chứa.${NC}"
      sudo rm -f "$TEMP_JSON"
    fi
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      return 0
    else
      echo ""
      read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại MarketPlace..."
    fi
  done
}
