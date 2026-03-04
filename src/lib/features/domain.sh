# --- Hàm Thay đổi tên miền ---
change_domain() {
    check_root
    echo -e "\n${CYAN}--- Thay Đổi Tên Miền cho N8N ---${NC}"

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    local old_domain_name
    old_domain_name=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
    if [[ -z "$old_domain_name" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy DOMAIN_NAME trong file ${ENV_FILE}.${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
        return 0
    fi
    echo -e "Tên miền hiện tại của N8N là: ${GREEN}${old_domain_name}${NC}"

    local new_domain_for_change
    if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_DOMAIN" ]]; then
        new_domain_for_change="$CLI_DOMAIN"
    else
        if ! get_domain_and_dns_check_reusable new_domain_for_change "$old_domain_name" "Nhập tên miền MỚI bạn muốn sử dụng"; then
            if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
            return 0
        fi
    fi

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        local confirmation_prompt
        confirmation_prompt=$(echo -e "\n${YELLOW}Bạn có chắc chắn muốn thay đổi tên miền từ ${RED}${old_domain_name}${NC} sang ${GREEN}${new_domain_for_change}${NC} không?${NC}\n${RED}Hành động này sẽ yêu cầu cấp lại SSL và khởi động lại các service.${NC}\nNhập '${GREEN}ok${NC}' để xác nhận, hoặc bất kỳ phím nào khác để huỷ bỏ: ")
        local confirmation
        read -r -p "$confirmation_prompt" confirmation

        if [[ "$confirmation" != "ok" ]]; then
            echo -e "\n${GREEN}Huỷ bỏ thay đổi tên miền.${NC}"
            read -r -p "Nhấn Enter để quay lại menu..."
            return 0
        fi
    fi

    trap 'RC=$?; stop_spinner; if [[ $RC -ne 0 && $RC -ne 130 ]]; then echo -e "\n${RED}Đã xảy ra lỗi trong quá trình thay đổi tên miền (Mã lỗi: $RC).${NC}"; update_env_file "DOMAIN_NAME" "$old_domain_name"; update_env_file "LETSENCRYPT_EMAIL" "no-reply@${old_domain_name}"; echo -e "${YELLOW}Đã khôi phục tên miền cũ trong .env.${NC}"; fi; if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi; return 0;' ERR SIGINT SIGTERM

    start_spinner "Đang thay đổi tên miền..."

    stop_spinner; start_spinner "Cập nhật file .env với tên miền mới..."
    if ! update_env_file "DOMAIN_NAME" "$new_domain_for_change"; then return 1; fi
    if ! update_env_file "LETSENCRYPT_EMAIL" "no-reply@${new_domain_for_change}"; then return 1; fi
    stop_spinner; start_spinner "Tiếp tục thay đổi tên miền..."

    stop_spinner; start_spinner "Dừng service N8N..."
    if ! sudo $DOCKER_COMPOSE_CMD -f "${DOCKER_COMPOSE_FILE}" stop ${N8N_SERVICE_NAME} > /tmp/n8n_change_domain_stop.log 2>&1; then
        echo -e "\n${YELLOW}Cảnh báo: Không thể dừng service ${N8N_SERVICE_NAME}. Kiểm tra /tmp/n8n_change_domain_stop.log. Tiếp tục với rủi ro.${NC}"
    fi
    stop_spinner; start_spinner "Tiếp tục thay đổi tên miền..."

    local old_nginx_conf_avail="/etc/nginx/sites-available/${old_domain_name}.conf"
    local old_nginx_conf_enabled="/etc/nginx/sites-enabled/${old_domain_name}.conf"
    if [ -f "$old_nginx_conf_avail" ] || [ -L "$old_nginx_conf_enabled" ]; then
        stop_spinner; start_spinner "Xóa cấu hình Nginx cũ..."
        sudo rm -f "$old_nginx_conf_avail"
        sudo rm -f "$old_nginx_conf_enabled"
        stop_spinner; start_spinner "Tiếp tục thay đổi tên miền..."
    fi

    if sudo certbot certificates -d "${old_domain_name}" 2>/dev/null | grep -q "Certificate Name:"; then
        local old_cert_name
        old_cert_name=$(sudo certbot certificates -d "${old_domain_name}" 2>/dev/null | grep "Certificate Name:" | head -n 1 | awk '{print $3}')
        if [[ -n "$old_cert_name" ]]; then
            stop_spinner; start_spinner "Xóa chứng chỉ SSL cũ (${old_cert_name})..."
            if ! sudo certbot delete --cert-name "${old_cert_name}" --non-interactive > /tmp/n8n_change_domain_cert_delete.log 2>&1; then
                 echo -e "\n${YELLOW}Cảnh báo: Không thể xóa chứng chỉ SSL cũ. Kiểm tra /tmp/n8n_change_domain_cert_delete.log.${NC}"
            fi
            stop_spinner; start_spinner "Tiếp tục thay đổi tên miền..."
        fi
    fi

    stop_spinner
    if ! create_docker_compose_config; then return 1; fi
    if ! configure_nginx_and_ssl; then return 1; fi

    start_spinner "Khởi động lại các service Docker..."
    cd "${N8N_DIR}" || { return 1; }
    if ! sudo $DOCKER_COMPOSE_CMD up -d --force-recreate > /tmp/n8n_change_domain_docker_up.log 2>&1; then
        return 1
    fi
    cd - > /dev/null
    stop_spinner

    echo -e "\n${GREEN}Thay đổi tên miền thành công!${NC}"
    echo -e "N8N hiện có thể truy cập tại: ${GREEN}https://${new_domain_for_change}${NC}"

    trap - ERR SIGINT SIGTERM
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
