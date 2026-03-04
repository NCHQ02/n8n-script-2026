# --- System & Security Audit ---

system_audit() {
  local is_json="false"
  if [[ "$NON_INTERACTIVE" == "true" && "$CLI_ACTION" == "audit-json" ]]; then
    is_json="true"
  fi

  if [[ "$is_json" == "false" ]]; then
    clear
    echo -e "${CYAN}=== SYSTEM & SECURITY AUDIT ===${NC}"
    echo -e "${YELLOW}[*] Đang tiến hành quét lỗ hổng và kiểm tra tài nguyên hệ thống...${NC}\n"
  fi

  local issue_count=0

  # 1. Kiểm tra Permission file .env
  local env_status="unknown"
  if [[ "$is_json" == "false" ]]; then
    echo -n -e "1. Kiểm tra cấu hình bảo mật (.env): "
  fi
  if [ -f "${ENV_FILE}" ]; then
    local env_perms
    env_perms=$(stat -c "%a" "${ENV_FILE}")
    if [[ "$env_perms" == "777" || "$env_perms" == "666" || "$env_perms" == "644" ]]; then
      if [[ "$is_json" == "false" ]]; then
        echo -e "${RED}CẢNH BÁO [Mức độ: Cao]${NC}"
        echo -e "   -> File ${ENV_FILE} đang có quyền ${env_perms} (không an toàn)."
        echo -e "   -> Đang tự động sửa lỗi (chmod 600)..."
      fi
      sudo chmod 600 "${ENV_FILE}"
      if [[ "$is_json" == "false" ]]; then
        echo -e "   ${GREEN}[+] Đã fix quyền file .env thành 600.${NC}"
      fi
      env_status="fixed_to_600"
      issue_count=$((issue_count+1))
    else
      if [[ "$is_json" == "false" ]]; then echo -e "${GREEN}An toàn (${env_perms})${NC}"; fi
      env_status="safe_${env_perms}"
    fi
  else
    if [[ "$is_json" == "false" ]]; then echo -e "${YELLOW}Bỏ qua (Chưa cài đặt N8N)${NC}"; fi
    env_status="not_installed"
  fi

  # 2. Kiểm tra Dung lượng ổ cứng (Disk Space)
  if [[ "$is_json" == "false" ]]; then echo -n -e "2. Kiểm tra dung lượng ổ đĩa phân vùng gốc (/): "; fi
  local disk_usage
  disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' | tr -dc '0-9')
  # Đảm bảo rỗng thì = 0
  if [[ -z "$disk_usage" ]]; then disk_usage=0; fi
  local disk_status="ok"
  if [ "$disk_usage" -ge 80 ]; then
    if [[ "$is_json" == "false" ]]; then
      echo -e "${RED}CẢNH BÁO [Mức độ: Cao]${NC}"
      echo -e "   -> Ổ đĩa đã sử dụng ${disk_usage}%. Nếu đạt 100%, Database PostgreSQL sẽ Crash!"
      echo -e "   -> Vui lòng dùng tính năng [16] Dọn rác máy chủ hoặc xóa bớt file thừa."
    fi
    disk_status="warning_high"
    issue_count=$((issue_count+1))
  else
    if [[ "$is_json" == "false" ]]; then echo -e "${GREEN}Tốt (${disk_usage}%)${NC}"; fi
  fi

  # 3. Kiểm tra Thời hạn SSL
  local ssl_status="unknown"
  local ssl_days_left="-1"
  if [[ "$is_json" == "false" ]]; then echo -n -e "3. Kiểm tra chứng chỉ SSL/HTTPS: "; fi
  if [ -f "${ENV_FILE}" ]; then
    local domain_name
    domain_name=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
    if [[ -n "$domain_name" ]]; then
      local expiry_date
      expiry_date=$(echo | openssl s_client -servername "${domain_name}" -connect "${domain_name}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
      if [[ -n "$expiry_date" ]]; then
        # Chuyển đổi định dạng thời gian để tính toán
        local expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -D "%b %d %H:%M:%S %Y %Z" -d "${expiry_date}" +%s 2>/dev/null)
        local current_epoch=$(date +%s)
        if [[ -n "$expiry_epoch" ]]; then
          local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
          ssl_days_left=$days_left
          if [ "$days_left" -lt 15 ]; then
             if [[ "$is_json" == "false" ]]; then
               echo -e "${RED}CẢNH BÁO [Mức độ: Thấp]${NC}"
               echo -e "   -> SSL cho ${domain_name} sẽ hết hạn trong ${days_left} ngày tới (${expiry_date})."
               echo -e "   -> Vui lòng gia hạn Let's Encrypt hoặc Cloudflare."
             fi
             ssl_status="warning_expiring"
             issue_count=$((issue_count+1))
          else
             if [[ "$is_json" == "false" ]]; then echo -e "${GREEN}An toàn (Cấp cho ${domain_name}, còn ${days_left} ngày)${NC}"; fi
             ssl_status="safe"
          fi
        else
          if [[ "$is_json" == "false" ]]; then echo -e "${YELLOW}Không thể tính toán (${expiry_date})${NC}"; fi
          ssl_status="error_parsing_date"
        fi
      else
        if [[ "$is_json" == "false" ]]; then echo -e "${YELLOW}Không lấy được (Trang web có bật HTTPS không?)${NC}"; fi
        ssl_status="error_fetching"
      fi
    else
      if [[ "$is_json" == "false" ]]; then echo -e "${YELLOW}Bỏ qua (Chưa có tên miền)${NC}"; fi
      ssl_status="no_domain"
    fi
  else
    if [[ "$is_json" == "false" ]]; then echo -e "${YELLOW}Bỏ qua (Chưa cài đặt N8N)${NC}"; fi
    ssl_status="not_installed"
  fi

  if [[ "$is_json" == "true" ]]; then
    # In ra dạng JSON cơ bản thông qua jq nếu có, hoặc dùng echo
    echo "{"
    echo "  \"issueCount\": ${issue_count},"
    echo "  \"envFileStatus\": \"${env_status}\","
    echo "  \"diskUsagePercent\": ${disk_usage},"
    echo "  \"diskStatus\": \"${disk_status}\","
    echo "  \"sslStatus\": \"${ssl_status}\","
    echo "  \"sslDaysLeft\": ${ssl_days_left}"
    echo "}"
    return 0
  fi

  echo -e "\n--------------------------------------------------------"
  if [ $issue_count -eq 0 ]; then
    echo -e "${GREEN}[+] Hệ thống hiện tại AN TOÀN và TUYỆT VỜI. Bạn không cần lo lắng gì cả!${NC}"
  else
    echo -e "${YELLOW}[!] Phát hiện ${issue_count} rủi ro. Vui lòng kiểm tra lại theo hướng dẫn bên trên.${NC}"
  fi
  
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo ""
    read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
  fi
}
