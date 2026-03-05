# --- Hàm Export Dữ Liệu ---
export_all_data() {
    check_root
    echo -e "\n${CYAN}--- Export Dữ Liệu N8N (Workflows & Credentials) ---${NC}"

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    local domain_name
    domain_name=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
    if [[ -z "$domain_name" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy DOMAIN_NAME trong file ${ENV_FILE}.${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            read -r -p "Nhấn Enter để quay lại menu..."
        fi
        return 0
    fi

    local backup_base_dir="${CLI_PATH:-${N8N_DIR}/backups}"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local current_backup_dir="${backup_base_dir}/n8n_backup_${timestamp}"
    local container_temp_export_dir="/home/node/.n8n/temp_export_$$"
    local creds_file="credentials.json"
    local workflows_file="workflows.json"
    local temp_nginx_include_file_path_for_trap=""

    trap 'RC=$?; stop_spinner; \
        echo -e "\n${YELLOW}Huỷ bỏ/Lỗi trong quá trình export (Mã lỗi: $RC). Đang dọn dẹp...${NC}"; \
        sudo docker exec -u node ${N8N_CONTAINER_NAME} rm -rf "${container_temp_export_dir}" &>/dev/null; \
        if [ -n "${temp_nginx_include_file_path_for_trap}" ] && [ -f "${temp_nginx_include_file_path_for_trap}" ]; then \
            sudo rm -f "${temp_nginx_include_file_path_for_trap}"; \
            if sudo nginx -t &>/dev/null; then sudo systemctl reload nginx &>/dev/null; fi; \
            echo -e "${YELLOW}Đường dẫn tải xuống tạm thời đã được gỡ bỏ.${NC}"; \
        fi; \
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi; \
        return 0;' ERR SIGINT SIGTERM

    start_spinner "Chuẩn bị export dữ liệu..."

    if ! sudo mkdir -p "${current_backup_dir}"; then
        stop_spinner
        echo -e "${RED}Lỗi: Không thể tạo thư mục backup ${current_backup_dir}.${NC}"
        return 1
    fi
    sudo chmod 755 "${current_backup_dir}"

    if ! sudo docker exec -u node "${N8N_CONTAINER_NAME}" mkdir -p "${container_temp_export_dir}"; then
        stop_spinner
        echo -e "${RED}Lỗi: Không thể tạo thư mục tạm trong container N8N.${NC}"
        return 1
    fi
    stop_spinner

    # Export credentials
    local export_creds_log="/tmp/n8n_export_creds.log"
    local export_creds_cmd="n8n export:credentials --all --output=${container_temp_export_dir}/${creds_file}"
    local export_creds_success=false

    start_spinner "Đang export credentials..."
    if sudo docker exec -u node "${N8N_CONTAINER_NAME}" ${export_creds_cmd} > "${export_creds_log}" 2>&1; then
        if sudo docker cp "${N8N_CONTAINER_NAME}:${container_temp_export_dir}/${creds_file}" "${current_backup_dir}/${creds_file}"; then
            export_creds_success=true
            echo -e "\r\033[K${GREEN}Export credentials thành công.${NC}"
        else
            echo -e "\r\033[K${RED}Lỗi khi sao chép ${creds_file} từ container.${NC}"
        fi
    else
        if grep -q -i "No credentials found" "${export_creds_log}" || \
           grep -q -i "No items to export" "${export_creds_log}"; then
            echo -e "\r\033[K${YELLOW}Không tìm thấy credentials để export. Tạo file rỗng...${NC}"
            echo "{}" | sudo tee "${current_backup_dir}/${creds_file}" > /dev/null
            export_creds_success=true
        else
            echo -e "\r\033[K${RED}Lỗi khi export credentials.${NC}"
            echo -e "${YELLOW}Output từ lệnh:${NC}"
            cat "${export_creds_log}"
        fi
    fi
    stop_spinner
    sudo rm -f "${export_creds_log}"
    if [[ "$export_creds_success" != true ]]; then return 1; fi

    # Export workflows
    local export_workflows_log="/tmp/n8n_export_workflows.log"
    local export_workflows_cmd="n8n export:workflow --all --output=${container_temp_export_dir}/${workflows_file}"
    local export_workflows_success=false

    start_spinner "Đang export workflows..."
    if sudo docker exec -u node "${N8N_CONTAINER_NAME}" ${export_workflows_cmd} > "${export_workflows_log}" 2>&1; then
        if sudo docker cp "${N8N_CONTAINER_NAME}:${container_temp_export_dir}/${workflows_file}" "${current_backup_dir}/${workflows_file}"; then
            export_workflows_success=true
            echo -e "\r\033[K${GREEN}Export workflows thành công.${NC}"
        else
            echo -e "\r\033[K${RED}Lỗi khi sao chép ${workflows_file} từ container.${NC}"
        fi
    else
        if grep -q -i "No workflows found" "${export_workflows_log}" || \
           grep -q -i "No items to export" "${export_workflows_log}"; then
            echo -e "\r\033[K${YELLOW}Không tìm thấy workflows để export. Tạo file rỗng...${NC}"
            echo "[]" | sudo tee "${current_backup_dir}/${workflows_file}" > /dev/null
            export_workflows_success=true
        else
            echo -e "\r\033[K${RED}Lỗi khi export workflows.${NC}"
            echo -e "${YELLOW}Output từ lệnh:${NC}"
            cat "${export_workflows_log}"
        fi
    fi
    stop_spinner
    sudo rm -f "${export_workflows_log}"
    if [[ "$export_workflows_success" != true ]]; then return 1; fi

    echo -e "Đường dẫn lưu trữ trên server: ${YELLOW}${current_backup_dir}${NC}"

    start_spinner "Dọn dẹp thư mục tạm trong container..."
    sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_export_dir}" &>/dev/null
    stop_spinner

    # Tạo đường dẫn tải xuống tạm thời qua Nginx
    local random_signature
    random_signature=$(generate_random_string 16)
    sudo mkdir -p "${NGINX_EXPORT_INCLUDE_DIR}"
    local temp_nginx_include_file="${NGINX_EXPORT_INCLUDE_DIR}/${NGINX_EXPORT_INCLUDE_FILE_BASENAME}_${random_signature}.conf"
    temp_nginx_include_file_path_for_trap="${temp_nginx_include_file}"
    local download_path_segment="n8n-backup-${random_signature}"

    start_spinner "Tạo đường dẫn tải xuống tạm thời..."

    local nginx_export_content
    nginx_export_content=$(cat <<EOF
location /${download_path_segment}/ {
    alias ${current_backup_dir}/;
    add_header Content-Disposition "attachment";
    autoindex off;
    expires off;
}
EOF
)
    echo "$nginx_export_content" | sudo tee "${temp_nginx_include_file}" > /dev/null
    if [ $? -ne 0 ]; then
        stop_spinner
        echo -e "${RED}Lỗi khi tạo file cấu hình Nginx tạm thời: ${temp_nginx_include_file}.${NC}"
        temp_nginx_include_file_path_for_trap=""
        return 1
    fi

    if ! sudo nginx -t > /tmp/nginx_export_test.log 2>&1; then
        stop_spinner
        echo -e "${RED}Lỗi cấu hình Nginx. Kiểm tra /tmp/nginx_export_test.log.${NC}"
        sudo rm -f "${temp_nginx_include_file}"
        temp_nginx_include_file_path_for_trap=""
        return 1
    fi
    sudo systemctl reload nginx
    stop_spinner
    echo -e "${GREEN}Đường dẫn tải xuống tạm thời đã được tạo.${NC}"

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}--- HƯỚNG DẪN TẢI XUỐNG ---${NC}"
        echo -e "Các file backup đã được export thành công."
        echo -e "Bạn có thể tải xuống qua các đường dẫn sau (chỉ có hiệu lực trong phiên này):"
        echo -e "  Credentials: ${GREEN}https://${domain_name}/${download_path_segment}/${creds_file}${NC}"
        echo -e "  Workflows:   ${GREEN}https://${domain_name}/${download_path_segment}/${workflows_file}${NC}"
        echo -e "\n${RED}QUAN TRỌNG:${NC} Sau khi bạn tải xong, nhấn Enter để vô hiệu hoá các đường dẫn này."

        read -r -p "Nhấn Enter sau khi bạn đã tải xong các file..."

        start_spinner "Vô hiệu hoá đường dẫn tải xuống..."
        sudo rm -f "${temp_nginx_include_file}"
        temp_nginx_include_file_path_for_trap=""
        if ! sudo nginx -t > /tmp/nginx_export_test_remove.log 2>&1; then
            echo -e "\n${YELLOW}Cảnh báo: Có lỗi khi kiểm tra Nginx sau khi xóa file include, nhưng vẫn tiếp tục.${NC}"
        fi
        sudo systemctl reload nginx
        stop_spinner
        echo -e "${GREEN}Đường dẫn tải xuống đã được vô hiệu hoá.${NC}"
    else
        # Xóa ngay Nginx config nếu chạy qua CLI (tránh quên)
        sudo rm -f "${temp_nginx_include_file}"
        temp_nginx_include_file_path_for_trap=""
        sudo systemctl reload nginx &>/dev/null
    fi
    echo -e "Các file backup được lưu trữ tại: ${YELLOW}${current_backup_dir}${NC} trên server."

    trap - ERR SIGINT SIGTERM
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}

# --- Hàm Import Dữ Liệu ---
import_data() {
    check_root

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
        return 0
    fi

    local import_source="1"
    local local_file_path="${CLI_FILE:-}"

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${CYAN}--- Chọn nguồn import dữ liệu ---${NC}"
        echo -e " 1) Từ template mặc định trên GitHub (Tự động tải credentials.json & workflows.json)"
        echo -e " 2) Từ file Local trên server"
        read -p "$(echo -e ${CYAN}'Nhập lựa chọn của bạn (1-2) [Mặc định: 1]: '${NC})" import_source
        import_source=${import_source:-1}
        
        if [[ "$import_source" == "2" ]]; then
            read -p "Nhập đường dẫn tuyệt đối tới file .json: " local_file_path
        fi
    else
        if [[ -n "$CLI_FILE" ]]; then
            import_source="2"
        fi
    fi

    trap 'RC=$?; stop_spinner; \
        echo -e "\n${YELLOW}Huỷ bỏ/Lỗi trong quá trình import (Mã lỗi: $RC). Đang dọn dẹp...${NC}"; \
        sudo docker exec -u node ${N8N_CONTAINER_NAME} rm -rf "/home/node/.n8n/temp_import_template_$$" &>/dev/null; \
        sudo rm -rf "/tmp/n8n_import_host_$$" &>/dev/null; \
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi; \
        return 0;' ERR SIGINT SIGTERM

    local container_temp_import_dir="/home/node/.n8n/temp_import_template_$$"
    if ! sudo docker exec -u node "${N8N_CONTAINER_NAME}" mkdir -p "${container_temp_import_dir}"; then
        echo -e "${RED}Lỗi: Không thể tạo thư mục tạm trong container N8N.${NC}"
        return 1
    fi

    local import_log="/tmp/n8n_import_template.log"
    > "${import_log}"

    if [[ "$import_source" == "1" ]]; then
        start_spinner "Đang tải và import templates từ GitHub..."
        
        local github_base_url="https://raw.githubusercontent.com/NCHQ02/n8n-script-2026/main/templates"
        local creds_url="${github_base_url}/credentials.json"
        local workflows_url="${github_base_url}/workflows.json"
        
        # Download files to host first using curl, then copy to container
        local host_temp_dir="/tmp/n8n_import_host_$$"
        sudo mkdir -p "${host_temp_dir}"
        
        sudo curl -s -L -o "${host_temp_dir}/credentials.json" "${creds_url}"
        sudo curl -s -L -o "${host_temp_dir}/workflows.json" "${workflows_url}"

        sudo docker cp "${host_temp_dir}/credentials.json" "${N8N_CONTAINER_NAME}:${container_temp_import_dir}/credentials.json"
        sudo docker cp "${host_temp_dir}/workflows.json" "${N8N_CONTAINER_NAME}:${container_temp_import_dir}/workflows.json"

        # Import credentials if file is not empty
        if grep -q "{" "${host_temp_dir}/credentials.json" 2>/dev/null; then
            sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n import:credentials --input="${container_temp_import_dir}/credentials.json" >> "${import_log}" 2>&1 || true
        fi
        
        # Import workflows if file is not empty
        if grep -q "\[\|{" "${host_temp_dir}/workflows.json" 2>/dev/null; then
            sudo docker exec -u node "${N8N_CONTAINER_NAME}" n8n import:workflow --input="${container_temp_import_dir}/workflows.json" >> "${import_log}" 2>&1 || true
        fi

        sudo rm -rf "${host_temp_dir}"
        
        stop_spinner
    else
        if [ ! -f "$local_file_path" ]; then
            echo -e "${RED}Lỗi: File data '${local_file_path}' không tìm thấy trên server.${NC}"
            echo -e "${YELLOW}Vui lòng cấp đúng đường dẫn file JSON có đuôi .json.${NC}"
            sudo docker exec -u node "${N8N_CONTAINER_NAME} rm -rf ${container_temp_import_dir}" &>/dev/null
            if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
            return 0
        fi

        start_spinner "Đang import dữ liệu từ file local..."
        local target_file_name
        target_file_name=$(basename "$local_file_path")
        
        if ! sudo bash -c "docker cp \"${local_file_path}\" \"${N8N_CONTAINER_NAME}:${container_temp_import_dir}/${target_file_name}\"" >/dev/null 2>&1; then
            stop_spinner
            echo -e "${RED}Lỗi khi sao chép file data vào container.${NC}"
            sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_import_dir}" &>/dev/null
            return 1
        fi

        local import_cmd="n8n import:workflow --input=${container_temp_import_dir}/${target_file_name}"
        if [[ "$target_file_name" == *"credential"* ]]; then
            import_cmd="n8n import:credentials --input=${container_temp_import_dir}/${target_file_name}"
        fi

        sudo docker exec -u node "${N8N_CONTAINER_NAME}" ${import_cmd} >> "${import_log}" 2>&1 || true
        stop_spinner
    fi

    # Check log for errors (simplified)
    if grep -q "Error" "${import_log}" || grep -q "failed" "${import_log}"; then
        echo -e "\n${YELLOW}Có thể có lỗi hoặc cảnh báo xuất hiện trong quá trình import (kiểm tra log bên dưới):${NC}"
        cat "${import_log}"
    else
        echo -e "\n${GREEN}[+] Import dữ liệu hoàn tất!${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            echo -e "\n${YELLOW}--- HƯỚNG DẪN SỬ DỤNG ---${NC}"
            echo -e "1. Truy cập vào N8N qua trình duyệt."
            echo -e "2. Kiểm tra lại workflows và credentials mới vừa nạp vào."
            echo -e "3. Đảm bảo cấu hình lại Token & API Key cần thiết."
        fi
    fi

    sudo rm -f "${import_log}"
    sudo docker exec -u node "${N8N_CONTAINER_NAME}" rm -rf "${container_temp_import_dir}" &>/dev/null
    trap - ERR SIGINT SIGTERM

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
