# --- Hàm Lấy thông tin kết nối CSDL PostgreSQL ---
get_database_info() {
    check_root
    echo -e "\n${CYAN}--- Lấy Thông Tin Kết Nối PostgreSQL ---${NC}"

    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}Lỗi: File cấu hình ${ENV_FILE} không tìm thấy.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước (chọn mục 1).${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
        return 0
    fi

    local db_host="127.0.0.1" # Mặc định Docker chạy ở local
    local db_port="5432"
    local db_name
    db_name=$(grep "^POSTGRES_DB=" "${ENV_FILE}" | cut -d'=' -f2)
    local db_user
    db_user=$(grep "^POSTGRES_USER=" "${ENV_FILE}" | cut -d'=' -f2)
    local db_password
    db_password=$(grep "^POSTGRES_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)

    if [[ -z "$db_name" || -z "$db_user" || -z "$db_password" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy đầy đủ thông tin kết nối Database trong file ${ENV_FILE}.${NC}"
        echo -e "${YELLOW}File cấu hình có thể bị lỗi hoặc Database chưa được cấu hình đúng.${NC}"
    else
        echo -e "${GREEN}Thông tin kết nối PostgreSQL (Mặc định chỉ được truy cập nội bộ Docker):${NC}"
        echo -e "  ${CYAN}Host:${NC}     postgres (hoặc 127.0.0.1 nếu map port)"
        echo -e "  ${CYAN}Port:${NC}     ${db_port}"
        echo -e "  ${CYAN}Database:${NC} ${db_name}"
        echo -e "  ${CYAN}User:${NC}     ${db_user}"
        echo -e "  ${CYAN}Password:${NC} ${YELLOW}${db_password}${NC}"
        echo -e "\n${YELLOW}Lưu ý: Mặc định kịch bản Dymanic Host không mở cổng 5432 ra public internet để bảo mật.${NC}"
        echo -e "${YELLOW}Bạn cần cấu hình docker-compose nếu muốn map ports 5432:5432 ra ngoài.${NC}"
    fi
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
