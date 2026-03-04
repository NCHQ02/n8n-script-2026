# --- Hàm Tắt Xác thực 2 bước (2FA/MFA) ---
disable_mfa() {
    check_root
    echo -e "\n${CYAN}--- Tắt Xác Thực 2 Bước (2FA/MFA) cho User N8N ---${NC}"

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    local user_email
    if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_EMAIL" ]]; then
        user_email="$CLI_EMAIL"
    else
        echo -n -e "Nhập địa chỉ email của tài khoản N8N cần tắt 2FA: "
        read -r user_email

        if [[ -z "$user_email" ]]; then
            echo -e "${RED}Email không được để trống. Huỷ bỏ thao tác.${NC}"
            read -r -p "Nhấn Enter để quay lại menu..."
            return 0
        fi
    fi

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Bạn có chắc chắn muốn tắt 2FA cho tài khoản với email ${GREEN}${user_email}${NC} không?${NC}"
        local confirmation_prompt
        confirmation_prompt=$(echo -e "Nhập '${GREEN}ok${NC}' để xác nhận, hoặc bất kỳ phím nào khác để huỷ bỏ: ")
        local confirmation
        read -r -p "$confirmation_prompt" confirmation

        if [[ "$confirmation" != "ok" ]]; then
            echo -e "\n${GREEN}Huỷ bỏ thao tác tắt 2FA.${NC}"
            read -r -p "Nhấn Enter để quay lại menu..."
            return 0
        fi
    fi

    trap 'RC=$?; stop_spinner; if [[ $RC -ne 0 && $RC -ne 130 ]]; then echo -e "\n${RED}Đã xảy ra lỗi (Mã lỗi: $RC).${NC}"; fi; read -r -p "Nhấn Enter để quay lại menu..."; return 0;' ERR SIGINT SIGTERM

    start_spinner "Đang tắt 2FA cho user ${user_email}..."

    local disable_mfa_log="/tmp/n8n_disable_mfa.log"
    local cli_command="docker exec -u node ${N8N_CONTAINER_NAME} n8n umfa:disable --email \"${user_email}\""

    if sudo bash -c "${cli_command}" > "${disable_mfa_log}" 2>&1; then
        stop_spinner
        echo -e "\n${GREEN}Lệnh tắt 2FA đã được thực thi.${NC}"
        cat "${disable_mfa_log}"
        if grep -q -i "disabled MFA for user with email" "${disable_mfa_log}"; then
            echo -e "${GREEN}2FA đã được tắt thành công cho user ${user_email}.${NC}"
        elif grep -q -i "does not exist" "${disable_mfa_log}"; then
            echo -e "${RED}Lỗi: Không tìm thấy user với email ${user_email}.${NC}"
        elif grep -q -i "MFA is not enabled" "${disable_mfa_log}"; then
            echo -e "${YELLOW}Thông báo: 2FA chưa được kích hoạt cho user ${user_email}.${NC}"
        else
            echo -e "${YELLOW}Vui lòng kiểm tra output ở trên để biết kết quả chi tiết.${NC}"
        fi
    else
        stop_spinner
        echo -e "\n${RED}Lỗi khi thực thi lệnh tắt 2FA.${NC}"
        cat "${disable_mfa_log}"
        echo -e "${YELLOW}Kiểm tra log Docker của container ${N8N_CONTAINER_NAME} để biết thêm chi tiết.${NC}"
    fi
    sudo rm -f "${disable_mfa_log}"

    trap - ERR SIGINT SIGTERM
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}

# --- Hàm Đặt lại thông tin đăng nhập ---
reset_user_login() {
    check_root
    echo -e "\n${CYAN}--- Đặt Lại Thông Tin Đăng Nhập User Owner N8N ---${NC}"

    if [[ ! -f "${ENV_FILE}" || ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE} hoặc ${DOCKER_COMPOSE_FILE}.${NC}"
        echo -e "${YELLOW}Có vẻ như N8N chưa được cài đặt. Vui lòng cài đặt trước.${NC}"
        read -r -p "Nhấn Enter để quay lại menu..."
        return 0
    fi

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}CẢNH BÁO: Hành động này sẽ reset toàn bộ thông tin tài khoản owner (người dùng chủ sở hữu).${NC}"
        echo -e "${YELLOW}Sau khi reset, bạn sẽ cần phải tạo lại tài khoản owner khi truy cập N8N lần đầu.${NC}"
        local confirmation_prompt
        confirmation_prompt=$(echo -e "Bạn có chắc chắn muốn tiếp tục?\nNhập '${GREEN}ok${NC}' để xác nhận, hoặc bất kỳ phím nào khác để huỷ bỏ: ")
        local confirmation
        read -r -p "$confirmation_prompt" confirmation

        if [[ "$confirmation" != "ok" ]]; then
            echo -e "\n${GREEN}Huỷ bỏ thao tác đặt lại thông tin đăng nhập.${NC}"
            read -r -p "Nhấn Enter để quay lại menu..."
            return 0
        fi
    fi

    trap 'RC=$?; stop_spinner; if [[ $RC -ne 0 && $RC -ne 130 ]]; then echo -e "\n${RED}Đã xảy ra lỗi (Mã lỗi: $RC).${NC}"; fi; read -r -p "Nhấn Enter để quay lại menu..."; return 0;' ERR SIGINT SIGTERM

    start_spinner "Đang reset thông tin đăng nhập owner..."

    local reset_log="/tmp/n8n_reset_owner.log"
    local cli_command="docker exec -u node ${N8N_CONTAINER_NAME} n8n user-management:reset"

    local cli_exit_code=0
    sudo bash -c "${cli_command}" > "${reset_log}" 2>&1 || cli_exit_code=$?

    stop_spinner

    if [[ $cli_exit_code -eq 0 ]]; then
        echo -e "\n${GREEN}Lệnh reset thông tin owner đã được thực thi.${NC}"
        echo -e "${CYAN}Output từ lệnh:${NC}"
        cat "${reset_log}"

        if grep -q -i "User data for instance owner has been reset" "${reset_log}"; then
             echo -e "${GREEN}Thông tin tài khoản owner đã được reset thành công.${NC}"
             echo -e "${YELLOW}Lần truy cập N8N tiếp theo, bạn sẽ được yêu cầu tạo lại tài khoản owner.${NC}"

             start_spinner "Đang khởi động lại N8N service..."
             cd "${N8N_DIR}" || { stop_spinner; echo -e "${RED}Không thể truy cập ${N8N_DIR}.${NC}"; return 1; }
             if ! sudo $DOCKER_COMPOSE_CMD restart ${N8N_SERVICE_NAME} > /tmp/n8n_restart_after_reset.log 2>&1; then
                 stop_spinner
                 echo -e "${RED}Lỗi khi khởi động lại N8N service. Kiểm tra /tmp/n8n_restart_after_reset.log${NC}"
             else
                 stop_spinner
                 echo -e "${GREEN}N8N service đã được khởi động lại.${NC}"
             fi
             cd - > /dev/null
        else
            echo -e "${YELLOW}Reset có thể không thành công. Vui lòng kiểm tra output ở trên.${NC}"
        fi
    else
        echo -e "\n${RED}Lỗi khi thực thi lệnh reset thông tin owner.${NC}"
        echo -e "${YELLOW}Output từ lệnh (nếu có):${NC}"
        cat "${reset_log}"
        echo -e "${YELLOW}Kiểm tra log Docker của container ${N8N_CONTAINER_NAME} để biết thêm chi tiết.${NC}"
    fi
    sudo rm -f "${reset_log}"

    trap - ERR SIGINT SIGTERM
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
