# --- Hàm Nâng cấp phiên bản N8N ---
upgrade_n8n_version() {
    check_root
    echo -e "\n${CYAN}--- Nâng Cấp Phiên Bản N8N ---${NC}"

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    local current_image_tag="latest"
    if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
        current_image_tag=$(awk '/services:/ {in_services=1} /^  [^ ]/ {if(in_services) in_n8n_service=0} /'${N8N_SERVICE_NAME}':/ {if(in_services) in_n8n_service=1} /image: n8nio\/n8n:/ {if(in_n8n_service) {gsub("n8nio/n8n:", ""); print $2; exit}}' "${DOCKER_COMPOSE_FILE}")
        if [[ -z "$current_image_tag" ]]; then
            current_image_tag="latest (không xác định)"
        fi
    fi
    echo -e "Phiên bản N8N hiện tại (theo tag image): ${GREEN}${current_image_tag}${NC}"
    echo -e "${YELLOW}Chức năng này sẽ nâng cấp N8N lên phiên bản '${GREEN}latest${YELLOW}' mới nhất từ Docker Hub.${NC}"

    local confirmation_prompt
    confirmation_prompt=$(echo -e "Bạn có chắc chắn muốn tiếp tục nâng cấp không?\nNhập '${GREEN}ok${NC}' để xác nhận, hoặc bất kỳ phím nào khác để huỷ bỏ: ")
    local confirmation
    read -r -p "$confirmation_prompt" confirmation

    if [[ "$confirmation" != "ok" ]]; then
        echo -e "\n${GREEN}Huỷ bỏ nâng cấp phiên bản.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    trap 'RC=$?; stop_spinner; if [[ $RC -ne 0 && $RC -ne 130 ]]; then echo -e "\n${RED}Đã xảy ra lỗi trong quá trình nâng cấp (Mã lỗi: $RC).${NC}"; fi; read -r -p "Nhấn Enter để quay lại menu..."; return 0;' ERR SIGINT SIGTERM

    start_spinner "Đang nâng cấp N8N lên phiên bản mới nhất..."

    cd "${N8N_DIR}" || { return 1; }

    stop_spinner; start_spinner "Đảm bảo cấu hình Docker Compose sử dụng tag :latest..."
    if ! create_docker_compose_config; then return 1; fi
    stop_spinner; start_spinner "Tiếp tục nâng cấp..."

    run_silent_command "Tải image N8N mới nhất (service ${N8N_SERVICE_NAME})" "$DOCKER_COMPOSE_CMD pull ${N8N_SERVICE_NAME}" "false"
    if [ $? -ne 0 ]; then cd - > /dev/null; return 1; fi

    run_silent_command "Khởi động lại N8N với phiên bản mới (service ${N8N_SERVICE_NAME})" "$DOCKER_COMPOSE_CMD up -d --force-recreate ${N8N_SERVICE_NAME}" "false"
    if [ $? -ne 0 ]; then cd - > /dev/null; return 1; fi

    cd - > /dev/null
    stop_spinner

    echo -e "\n${GREEN}Nâng cấp N8N hoàn tất! - HQ${NC}"
    echo -e "${YELLOW}N8N đã được cập nhật lên phiên bản '${GREEN}latest${YELLOW}' mới nhất.${NC}"
    echo -e "Vui lòng kiểm tra giao diện web của N8N để xác nhận phiên bản."

    trap - ERR SIGINT SIGTERM
    echo -e "${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
    read -r
}
