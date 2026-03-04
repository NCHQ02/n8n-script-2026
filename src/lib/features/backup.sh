# --- Sao lưu & Phục hồi Toàn Hệ thống ---
BACKUP_DIR="${N8N_DIR}/backups"

# Tạo bản sao lưu (Backup)
backup_server() {
  clear
  echo -e "${CYAN}=== BACKUP TOÀN BỘ HỆ THỐNG N8N ===${NC}"
  if [ ! -d "$N8N_DIR" ]; then
    echo -e "${RED}[!] Thư mục cài đặt ${N8N_DIR} không tồn tại.${NC}"
    read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
    return 1
  fi
  
  # Tạo thư mục gốc cho Backup nếu chưa có
  mkdir -p "$BACKUP_DIR"
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="${BACKUP_DIR}/n8n_backup_${timestamp}.tar.gz"
  
  echo -e "${YELLOW}[*] Hệ thống sẽ tạo một bản nén thư mục N8N (kèm Data) tại:${NC}"
  echo "- File: ${backup_file}"
  echo ""
  
  read -p "Bạn có muốn tiếp tục Backup không? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Đã hủy thao tác."
    sleep 1
    return 0
  fi
  
  # Chạy lệnh
  # Exclude các thư mục backups (.tar.gz) hoặc logs khổng lồ (nếu có) để tránh lồng nhau
  run_silent_command "Đang tạo bản ghi Backup (tùy dung lượng sẽ tốn vài phút)" "cd / && tar --exclude='${BACKUP_DIR}' -czf ${backup_file} ${N8N_DIR:1}" false
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Đã sao lưu thành công vào file: ${backup_file}!${NC}"
    echo -e "${YELLOW}[*] Bạn nên tải tệp tin này về máy cá nhân hoặc Cloud khác để lưu trữ an toàn.${NC}"
  fi
  
  echo ""
  read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
}

# Phục hồi (Restore)
restore_server() {
  clear
  echo -e "${CYAN}=== RESTORE HỆ THỐNG (TỪ FILE BACKUP) ===${NC}"
  
  if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A ${BACKUP_DIR}/*.tar.gz 2>/dev/null)" ]; then
    echo -e "${RED}[!] Không tìm thấy bất kỳ file Backup nào trong thư mục ${BACKUP_DIR}${NC}"
    echo -e "${YELLOW}[*] Xin vui lòng upload file .tar.gz vào thư mục ${BACKUP_DIR} trước, hoặc chạy lệnh Backup trước.${NC}"
    read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
    return 1
  fi
  
  echo -e "${YELLOW}[*] Danh sách các bản Backup có trên Server:${NC}"
  echo "--------------------------------------------------------"
  
  # Liệt kê file
  local files=(${BACKUP_DIR}/*.tar.gz)
  local num_files=${#files[@]}
  for ((i=0; i<num_files; i++)); do
    local size=$(du -h "${files[i]}" | cut -f1)
    local filename=$(basename "${files[i]}")
    printf " %-[%s]  %-40s %s\n" "$((i+1))" "$filename" "(Size: $size)"
  done
  
  echo "--------------------------------------------------------"
  echo " [0]  Hủy bỏ và quay lại"
  echo ""
  
  read -p "Chọn số tương ứng với file bạn muốn Restore (0-${num_files}): " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "$num_files" ]; then
     echo -e "${RED}[!] Lựa chọn không hợp lệ.${NC}"
     sleep 1
     return 1
  fi
  
  if [ "$choice" -eq 0 ]; then
    echo "Đã hủy thao tác."
    sleep 1
    return 0
  fi
  
  # Lấy tên file Restore
  local selected_file=${files[$((choice-1))]}
  
  echo -e "\n${RED}[!!!] CẢNH BÁO NGUY HIỂM [!!!]${NC}"
  echo "Bạn đang yêu cầu phục hồi dữ liệu từ file: $(basename $selected_file)"
  echo "Điều này sẽ XÓA TOÀN BỘ dữ liệu hiện tại trong N8N (Database, Workflow mới) và GHI ĐÈ dữ liệu từ Backup!"
  echo ""
  
  read -p "Bạn có CHẮC CHẮN MUỐN PHỤC HỒI hệ thống từ bản sao này không? Kể cả việc ghi đè tất cả? (Thay vì 'y', nhập chữ 'RESTORE' để đồng ý): " confirm_word
  if [[ "$confirm_word" != "RESTORE" ]]; then
    echo -e "${YELLOW}[*] Không trùng khớp (bạn không nhập từ RESTORE). Đã hủy thao tác.${NC}"
    sleep 2
    return 0
  fi
  
  # Bước 1: Dừng các service N8N
  run_silent_command "Đang dừng hệ thống N8N" "cd ${N8N_DIR} && ${DOCKER_COMPOSE_CMD} down" false
  
  # Bước 2: Dọn dẹp thư mục cũ (Ngoại trừ thư mục backups)
  run_silent_command "Đang dọn dẹp thư mục ${N8N_DIR} hiện tại" "find ${N8N_DIR} -mindepth 1 -maxdepth 1 ! -name 'backups' -exec rm -rf {} +" false
  
  # Bước 3: Giải nén
  run_silent_command "Đang giải nén file sao lưu / Phục hồi dữ liệu..." "tar -xzf ${selected_file} -C /" false
  
  # Bước 4: Khởi động lại
  run_silent_command "Đang gọi system khởi động lại N8N..." "cd ${N8N_DIR} && ${DOCKER_COMPOSE_CMD} up -d" false
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}[+] Chúc mừng! Quá trình phục hồi (Restore) đã thành công!${NC}"
    echo -e "${YELLOW}[*] Hãy chờ 1-2 phút cho các Container load Database và bạn có thể truy cập lại N8N.${NC}"
  fi
  
  echo ""
  read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
}
