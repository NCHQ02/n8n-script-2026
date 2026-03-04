# --- System & Security Audit ---

system_audit() {
  clear
  echo -e "${CYAN}=== SYSTEM & SECURITY AUDIT ===${NC}"
  echo -e "${YELLOW}[*] Đang tiến hành quét lỗ hổng và kiểm tra tài nguyên hệ thống...${NC}\n"

  local issue_count=0

  # 1. Kiểm tra Permission file .env
  echo -n -e "1. Kiểm tra cấu hình bảo mật (.env): "
  if [ -f "${ENV_FILE}" ]; then
    local env_perms
    env_perms=$(stat -c "%a" "${ENV_FILE}")
    if [[ "$env_perms" == "777" || "$env_perms" == "666" || "$env_perms" == "644" ]]; then
      echo -e "${RED}CẢNH BÁO [Mức độ: Cao]${NC}"
      echo -e "   -> File ${ENV_FILE} đang có quyền ${env_perms} (không an toàn)."
      echo -e "   -> Đang tự động sửa lỗi (chmod 600)..."
      sudo chmod 600 "${ENV_FILE}"
      echo -e "   ${GREEN}[+] Đã fix quyền file .env thành 600.${NC}"
      issue_count=$((issue_count+1))
    else
      echo -e "${GREEN}An toàn (${env_perms})${NC}"
    fi
  else
    echo -e "${YELLOW}Bỏ qua (Chưa cài đặt N8N)${NC}"
  fi

  # 2. Kiểm tra Dung lượng ổ cứng (Disk Space)
  echo -n -e "2. Kiểm tra dung lượng ổ đĩa phân vùng gốc (/): "
  local disk_usage
  disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
  if [ "$disk_usage" -ge 80 ]; then
    echo -e "${RED}CẢNH BÁO [Mức độ: Cao]${NC}"
    echo -e "   -> Ổ đĩa đã sử dụng ${disk_usage}%. Nếu đạt 100%, Database PostgreSQL sẽ Crash!"
    echo -e "   -> Vui lòng dùng tính năng [16] Dọn rác máy chủ hoặc xóa bớt file thừa."
    issue_count=$((issue_count+1))
  else
    echo -e "${GREEN}Tốt (${disk_usage}%)${NC}"
  fi

  # 3. Kiểm tra Thời hạn SSL
  echo -n -e "3. Kiểm tra chứng chỉ SSL/HTTPS: "
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
          if [ "$days_left" -lt 15 ]; then
             echo -e "${RED}CẢNH BÁO [Mức độ: Thấp]${NC}"
             echo -e "   -> SSL cho ${domain_name} sẽ hết hạn trong ${days_left} ngày tới (${expiry_date})."
             echo -e "   -> Vui lòng gia hạn Let's Encrypt hoặc Cloudflare."
             issue_count=$((issue_count+1))
          else
             echo -e "${GREEN}An toàn (Cấp cho ${domain_name}, còn ${days_left} ngày)${NC}"
          fi
        else
          echo -e "${YELLOW}Không thể tính toán (${expiry_date})${NC}"
        fi
      else
        echo -e "${YELLOW}Không lấy được (Trang web có bật HTTPS không?)${NC}"
      fi
    else
      echo -e "${YELLOW}Bỏ qua (Chưa có tên miền)${NC}"
    fi
  else
    echo -e "${YELLOW}Bỏ qua (Chưa cài đặt N8N)${NC}"
  fi

  echo -e "\n--------------------------------------------------------"
  if [ $issue_count -eq 0 ]; then
    echo -e "${GREEN}[+] Hệ thống hiện tại AN TOÀN và TUYỆT VỜI. Bạn không cần lo lắng gì cả!${NC}"
  else
    echo -e "${YELLOW}[!] Phát hiện ${issue_count} rủi ro. Vui lòng kiểm tra lại theo hướng dẫn bên trên.${NC}"
  fi
  
  echo ""
  read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
}
