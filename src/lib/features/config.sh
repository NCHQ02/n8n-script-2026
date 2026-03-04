# --- Cấu hình Môi trường (Environment Variables) ---

configure_environment() {
  while true; do
    clear
    echo -e "${CYAN}=== CẤU HÌNH BIẾN MÔI TRƯỜNG N8N ===${NC}"
    if [ ! -f "$ENV_FILE" ]; then
      echo -e "${RED}[!] Không tìm thấy cấu hình ${ENV_FILE}. Vui lòng cài đặt N8N trước.${NC}"
      read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
      return 1
    fi

    # Lấy thông tin hiện tại
    local current_tz=$(grep "^GENERIC_TIMEZONE=" "${ENV_FILE}" | cut -d '=' -f2)
    local pkg_allow=$(grep "^NODE_FUNCTION_ALLOW_EXTERNAL=" "${ENV_FILE}" | cut -d '=' -f2)
    local pkg_builtin=$(grep "^NODE_FUNCTION_ALLOW_BUILTIN=" "${ENV_FILE}" | cut -d '=' -f2)
    local payload_size=$(grep "^N8N_PAYLOAD_SIZE_MAX=" "${ENV_FILE}" | cut -d '=' -f2)
    local execution_prune=$(grep "^EXECUTIONS_DATA_PRUNE=" "${ENV_FILE}" | cut -d '=' -f2)

    echo -e "${YELLOW}[*] Cấu hình đang áp dụng hiện tại:${NC}"
    echo "> [1] Múi giờ N8N:            ${current_tz:-'Không xác định'}"
    echo "> [2] Thư viện NPM Module:     External: ${pkg_allow:-'Mặc định'} | Built-in: ${pkg_builtin:-'Mặc định'}"
    echo "> [3] Giới hạn dung lượng tải: ${payload_size:-'Không xác định'} (Mặc định N8N: 16MB)"
    echo "> [4] Tự động xóa lịch sử:     ${execution_prune:-'false'} (Tắt là false)"
    echo "--------------------------------------------------------"
    echo " [5]  Khởi động lại (Restart) N8N để áp dụng cấu hình MỚI"
    echo " [0]  Quay lại Menu Chính"
    echo "--------------------------------------------------------"
    echo -e "${YELLOW}(Lưu ý: Bạn chọn các số từ 1-4 để thay đổi giá trị cấu hình tương ứng)${NC}\n"
    
    read -p "Chọn ID cấu hình bạn muốn thay đổi (0-5): " config_choice

    case "$config_choice" in
      1)
        echo ""
        read -p "Nhập Múi giờ muốn thay đổi (Vd: Asia/Ho_Chi_Minh, UTC, America/New_York): " new_tz
        if [ -n "$new_tz" ]; then
          run_silent_command "Cập nhật Timezone" "update_env_file 'GENERIC_TIMEZONE' '${new_tz}' && update_env_file 'TZ' '${new_tz}'" false
          echo -e "${GREEN}[+] Đã lưu cấu hình. Hãy nhớ khởi động lại N8N (chọn [5]).${NC}"
        fi
        sleep 1
        ;;
      2)
        echo ""
        echo -e "${YELLOW}Theo mặc định, Code Node không thể yêu cầu các thư viện Axios, Moment, Lodash... do bảo mật.${NC}"
        echo -e "${YELLOW}Lưu ý: Việc thêm * có thể tạo rủi ro nếu cho Hacker chạy lệnh.${NC}"
        read -p "Bạn muốn cho phép các thư viện bên ngoài không? (Để '*' là cho tất cả, hoặc 'axios,moment'): " new_ext
        read -p "Bạn muốn cho phép các thư viện built-in Node.js không? (VD: 'fs,crypto,*'): " new_blt
        if [ -n "$new_ext" ]; then run_silent_command "Thêm External NPM" "update_env_file 'NODE_FUNCTION_ALLOW_EXTERNAL' '${new_ext}'" false; fi
        if [ -n "$new_blt" ]; then run_silent_command "Thêm Built-in NPM" "update_env_file 'NODE_FUNCTION_ALLOW_BUILTIN' '${new_blt}'" false; fi
        echo -e "${GREEN}[+] Đã lưu cấu hình. Hãy nhớ khởi động lại N8N (chọn [5]).${NC}"
        sleep 1
        ;;
      3)
        echo ""
        echo -e "${YELLOW}Nếu bạn cần import file json to, tải file lớn qua webhook, hay memory giới hạn, bạn cần đổi cỡ MB này.${NC}"
        read -p "Nhập giới hạn lưu lượng (Vd: 50, 256, 1024) [Tính theo MB]: " new_size
        if [ -n "$new_size" ] && [[ "$new_size" =~ ^[0-9]+$ ]]; then
          run_silent_command "Tăng Payload Max Size" "update_env_file 'N8N_PAYLOAD_SIZE_MAX' '${new_size}'" false
          echo -e "${GREEN}[+] Đã lưu cấu hình N8N_PAYLOAD_SIZE_MAX thành ${new_size}. Nhưng cần kiểm tra Nginx Reverse Proxy xem giới hạn có quá thấp không!${NC}"
        fi
        sleep 2
        ;;
      4)
        echo ""
        echo -e "${YELLOW}Tự xóa dữ liệu (Execution History) giúp nhẹ CSDL.${NC}"
        read -p "Bật tự động xóa History? (true/false): " p_enable
        if [[ "$p_enable" == "true" ]]; then
           read -p "Giữ lại lịch sử History thành công tối đa (VD: 336 giờ = 14 ngày): " max_age
           if [[ -z "$max_age" ]]; then max_age=336; fi
           run_silent_command "Sửa prune" "update_env_file 'EXECUTIONS_DATA_PRUNE' 'true' && update_env_file 'EXECUTIONS_DATA_MAX_AGE' '${max_age}'" false
        elif [[ "$p_enable" == "false" ]]; then
           run_silent_command "Sửa prune" "update_env_file 'EXECUTIONS_DATA_PRUNE' 'false'" false
        fi
        echo -e "${GREEN}[+] Đã lưu cấu hình. Hãy nhớ khởi động lại N8N (chọn [5]).${NC}"
        sleep 1
        ;;
      5)
        echo ""
        run_silent_command "Đang tải lại Server với Cấu hình Mới!" "cd ${N8N_DIR} && ${DOCKER_COMPOSE_CMD} up -d" false
        echo -e "${GREEN}[+] Hệ thống đã được Recreate với Cấu hình môi trường mới!${NC}"
        sleep 2
        ;;
      0)
        return 0
        ;;
      *)
        echo -e "${RED}[!] Lựa chọn không hợp lệ.${NC}"
        sleep 1
        ;;
    esac
  done
}
