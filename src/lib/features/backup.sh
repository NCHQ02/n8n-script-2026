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
  local current_backup_dir="${BACKUP_DIR}/n8n_backup_${timestamp}"
  
  echo -e "${YELLOW}[*] Hệ thống sẽ tạo một bản nén đầy đủ bao gồm:${NC}"
  echo "- Cấu hình Docker & Môi trường (.env)"
  echo "- Dữ liệu Workflows & Credentials"
  echo "- Dữ liệu Database PostgreSQL"
  echo "- Thư mục cấu hình N8N"
  echo ""
  
  read -p "Bạn có muốn tiếp tục Backup không? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Đã hủy thao tác."
    sleep 1
    return 0
  fi

  sudo mkdir -p "${current_backup_dir}"
  
  # 1. Export Credentials & Workflows (thông qua container n8n)
  start_spinner "Đang trích xuất Workflows & Credentials..."
  local container_temp_export_dir="/home/node/.n8n/temp_export_$$"
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" mkdir -p "${container_temp_export_dir}"
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n export:credentials --all --output="${container_temp_export_dir}/credentials.json" &>/dev/null
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n export:workflow --all --output="${container_temp_export_dir}/workflows.json" &>/dev/null
  sudo docker cp "${N8N_CONTAINER_NAME}:${container_temp_export_dir}/credentials.json" "${current_backup_dir}/credentials.json" &>/dev/null
  sudo docker cp "${N8N_CONTAINER_NAME}:${container_temp_export_dir}/workflows.json" "${current_backup_dir}/workflows.json" &>/dev/null
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_export_dir}" &>/dev/null
  stop_spinner

  # 2. Export Database PostgreSQL
  start_spinner "Đang trích xuất Cơ sở dữ liệu PostgreSQL..."
  local db_user=$(grep "^POSTGRES_USER=" "${ENV_FILE}" | cut -d'=' -f2)
  local db_name=$(grep "^POSTGRES_DB=" "${ENV_FILE}" | cut -d'=' -f2)
  if [[ -n "$db_user" && -n "$db_name" ]]; then
      sudo docker exec n8n_postgres pg_dump -U "$db_user" -d "$db_name" -F c -f "/tmp/database.dump" &>/dev/null
      sudo docker cp "n8n_postgres:/tmp/database.dump" "${current_backup_dir}/database.dump" &>/dev/null
      sudo docker exec n8n_postgres rm -f "/tmp/database.dump" &>/dev/null
  fi
  stop_spinner

  # 3. Copy các file cấu hình quan trọng
  start_spinner "Đang sao lưu cấu hình môi trường..."
  sudo cp "${N8N_DIR}/.env" "${current_backup_dir}/" &>/dev/null
  sudo cp "${N8N_DIR}/docker-compose.yml" "${current_backup_dir}/" &>/dev/null
  stop_spinner
  
  # 4. Gom tất cả lại thành 1 file .tar.gz duy nhất
  local final_backup_file="${BACKUP_DIR}/n8n_full_backup_${timestamp}.tar.gz"
  run_silent_command "Đang nén toàn bộ dữ liệu thành 1 file (tùy dung lượng sẽ tốn vài phút)" "cd ${BACKUP_DIR} && tar -czf ${final_backup_file} $(basename ${current_backup_dir})" false
  
  if [ $? -eq 0 ]; then
    # Xoá thư mục tạm sau khi nén xong
    sudo rm -rf "${current_backup_dir}"
    echo -e "${GREEN}[+] Đã sao lưu TOÀN BỘ hệ thống thành công!${NC}"
    echo -e "${YELLOW}File lưu tại: ${final_backup_file}${NC}"
    echo -e "${YELLOW}[*] Bạn nên tải tệp tin này về máy cá nhân hoặc Cloud khác để lưu trữ an toàn.${NC}"
  else
    echo -e "${RED}[!] Quá trình nén file thất bại.${NC}"
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
    printf " [%2d]  %-40s %s\n" "$((i+1))" "$filename" "(Size: $size)"
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
  
  # Tạo thư mục giải nén tạm thời
  local temp_extract_dir="/tmp/n8n_restore_$$"
  sudo mkdir -p "${temp_extract_dir}"
  run_silent_command "Đang giải nén file backup..." "tar -xzf ${selected_file} -C ${temp_extract_dir}" false

  # Tên folder bên trong file nén (ví dụ n8n_backup_2026...)
  local extracted_folder
  extracted_folder=$(ls -1 "${temp_extract_dir}" | head -n 1)
  local extract_source="${temp_extract_dir}/${extracted_folder}"

  # Khôi phục file cấu hình môi trường (.env, docker-compose.yml)
  start_spinner "Đang khôi phục file cấu hình..."
  if [ -f "${extract_source}/.env" ]; then
    sudo cp "${extract_source}/.env" "${N8N_DIR}/"
  fi
  if [ -f "${extract_source}/docker-compose.yml" ]; then
    sudo cp "${extract_source}/docker-compose.yml" "${N8N_DIR}/"
  fi
  stop_spinner

  # Đảm bảo các hệ thống đang chạy
  run_silent_command "Đảm bảo database đang hoạt động để restore..." "cd ${N8N_DIR} && ${DOCKER_COMPOSE_CMD} up -d postgres" false
  
  # Đợi Postgres sẵn sàng
  sleep 5
  
  # 2. Phục hồi Database PostgreSQL
  if [ -f "${extract_source}/database.dump" ]; then
    start_spinner "Đang khôi phục Cơ sở dữ liệu..."
    local db_user=$(grep "^POSTGRES_USER=" "${N8N_DIR}/.env" | cut -d'=' -f2)
    local db_name=$(grep "^POSTGRES_DB=" "${N8N_DIR}/.env" | cut -d'=' -f2)
    sudo docker cp "${extract_source}/database.dump" n8n_postgres:/tmp/database.dump
    sudo docker exec n8n_postgres pg_restore -U "$db_user" -d "$db_name" --clean --if-exists -1 "/tmp/database.dump" &>/dev/null
    sudo docker exec n8n_postgres rm -f "/tmp/database.dump" &>/dev/null
    stop_spinner
  fi

  # Bước khởi động lại toàn bộ N8N sau khi nạp cấu hình và database
  run_silent_command "Đang khởi động N8N platform..." "cd ${N8N_DIR} && ${DOCKER_COMPOSE_CMD} up -d n8n" false
  
  # Chờ N8N load hoàn chỉnh
  start_spinner "Đang chờ N8N khởi động để nạp Credentials và Workflows..."
  sleep 15
  stop_spinner

  # 3. Phục hồi Credentials & Workflows (thông qua container n8n)
  start_spinner "Đang nạp lại Workflows và Credentials..."
  local container_temp_import_dir="/home/node/.n8n/temp_import_$$"
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" mkdir -p "${container_temp_import_dir}"
  
  if [ -f "${extract_source}/credentials.json" ]; then
    sudo docker cp "${extract_source}/credentials.json" "${N8N_CONTAINER_NAME}:${container_temp_import_dir}/credentials.json"
    sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n import:credentials --input="${container_temp_import_dir}/credentials.json" &>/dev/null
  fi
  
  if [ -f "${extract_source}/workflows.json" ]; then
    sudo docker cp "${extract_source}/workflows.json" "${N8N_CONTAINER_NAME}:${container_temp_import_dir}/workflows.json"
    sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n import:workflow --input="${container_temp_import_dir}/workflows.json" &>/dev/null
  fi
  
  sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_import_dir}" &>/dev/null
  stop_spinner

  # Dọn dẹp thư mục tạm
  sudo rm -rf "${temp_extract_dir}"
  
  echo -e "\n${GREEN}[+] Chúc mừng! Quá trình phục hồi (Restore) TOÀN DIỆN đã thành công!${NC}"
  echo -e "${YELLOW}[*] N8N đã sẵn sàng với bộ dữ liệu Database, Workflows và Credentials cũ.${NC}"
  
  echo ""
  read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
}
