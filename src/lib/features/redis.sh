# --- Hàm Lấy thông tin Redis ---
get_redis_info() {
    check_root
    echo -e "\n${CYAN}--- Lấy Thông Tin Kết Nối Redis ---${NC}"

    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}Lỗi: File cấu hình ${ENV_FILE} không tìm thấy.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước (chọn mục 1).${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
        return 0
    fi

    local redis_password
    redis_password=$(grep "^REDIS_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)

    local server_ip
    server_ip=$(get_public_ip)

    if [[ -z "$redis_password" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy REDIS_PASSWORD trong file ${ENV_FILE}.${NC}"
        echo -e "${YELLOW}File cấu hình có thể bị lỗi hoặc Redis chưa được cấu hình đúng.${NC}"
    else
        echo -e "${GREEN}Thông tin kết nối Redis:${NC}"
        echo -e "  ${CYAN}Host:${NC}     ${server_ip}"
        echo -e "  ${CYAN}Port:${NC}     6379"
        echo -e "  ${CYAN}User:${NC}     default"
        echo -e "  ${CYAN}Password:${NC} ${YELLOW}${redis_password}${NC}"
    fi
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
