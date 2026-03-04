# --- Hàm chính để Cài đặt N8N ---
install() {
  check_root
  if [ -d "${N8N_DIR}" ] && [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    echo -e "\n${YELLOW}[CẢNH BÁO] Phát hiện thư mục ${N8N_DIR} và file ${DOCKER_COMPOSE_FILE} đã tồn tại.${NC}"
    local existing_containers
    if command_exists $DOCKER_COMPOSE_CMD && [ -f "${DOCKER_COMPOSE_FILE}" ]; then
        pushd "${N8N_DIR}" > /dev/null || { echo -e "${RED}Không thể truy cập thư mục ${N8N_DIR}${NC}"; return 1; }
        existing_containers=$(sudo $DOCKER_COMPOSE_CMD ps -q 2>/dev/null)
        popd > /dev/null
    fi

    if [[ -n "$existing_containers" ]] || [ -f "${DOCKER_COMPOSE_FILE}" ]; then
        echo -e "${YELLOW}    Có vẻ như N8N đã được cài đặt hoặc đã có một phần cấu hình trước đó.${NC}"
        echo -e "${YELLOW}    Nếu bạn muốn cài đặt lại từ đầu, vui lòng chọn mục '9) Xóa N8N và cài đặt lại' từ menu chính.${NC}"
        echo -e "${YELLOW}    Nhấn Enter để quay lại menu chính...${NC}"
        read -r
        return 0
    fi
  fi

  echo -e "\n${CYAN}===================================================${NC}"
  echo -e "${CYAN}    Bắt đầu quá trình cài đặt N8N Cloud - BMSG        ${NC}"
  echo -e "${CYAN}===================================================${NC}\n"

  trap 'RC=$?; stop_spinner; if [[ $RC -ne 0 && $RC -ne 130 ]]; then echo -e "\n${RED}Đã xảy ra lỗi trong quá trình cài đặt (Mã lỗi: $RC).${NC}"; fi; read -r -p "Nhấn Enter để quay lại menu..."; return 0;' ERR SIGINT SIGTERM

  install_prerequisites
  setup_directories_and_env_file

  local domain_name_for_install
  if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_DOMAIN" ]]; then
    domain_name_for_install="$CLI_DOMAIN"
  else
    if ! get_domain_and_dns_check_reusable domain_name_for_install "" "Nhập tên miền bạn muốn sử dụng cho N8N"; then
      return 0
    fi
  fi
  update_env_file "DOMAIN_NAME" "$domain_name_for_install"

  # Hỏi email thực để nhận thông báo khi chứng chỉ SSL sắp hết hạn
  local letsencrypt_email
  if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_EMAIL" ]]; then
    letsencrypt_email="$CLI_EMAIL"
  elif [[ "$NON_INTERACTIVE" == "true" && -z "$CLI_EMAIL" ]]; then
    letsencrypt_email="admin@${domain_name_for_install}"
  else
    while true; do
      echo -n -e "${CYAN}Nhập email để nhận thông báo SSL (Let's Encrypt): ${NC}"
      read -r letsencrypt_email
      if [[ -z "$letsencrypt_email" ]]; then
        echo -e "${RED}Email không được để trống.${NC}"
      elif [[ ! "$letsencrypt_email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        echo -e "${RED}Email không hợp lệ. Vui lòng nhập lại.${NC}"
      else
        break
      fi
    done
  fi
  update_env_file "LETSENCRYPT_EMAIL" "$letsencrypt_email"

  prompt_database_configuration
  generate_credentials
  create_docker_compose_config
  start_docker_containers
  configure_nginx_and_ssl
  final_checks_and_message

  trap - ERR SIGINT SIGTERM

  echo -e "\n${GREEN}===================================================${NC}"
  echo -e "${GREEN}      Hoàn tất quá trình cài đặt N8N Cloud!       ${NC}"
  echo -e "${GREEN}===================================================${NC}\n"
  
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo -e "${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
    read -r
  fi
}

# --- Hàm Xóa N8N và Cài đặt lại ---
reinstall_n8n() {
    check_root
    echo -e "\n${RED}======================= CẢNH BÁO XÓA DỮ LIỆU =======================${NC}"
    echo -e "${YELLOW}Bạn đã chọn chức năng XÓA TOÀN BỘ N8N và CÀI ĐẶT LẠI.${NC}"
    echo -e "${RED}HÀNH ĐỘNG NÀY SẼ XÓA VĨNH VIỄN:${NC}"
    echo -e "${RED}  - Toàn bộ dữ liệu n8n (workflows, credentials, executions,...).${NC}"
    echo -e "${RED}  - Database PostgreSQL của n8n.${NC}"
    echo -e "${RED}  - Dữ liệu cache Redis (nếu có).${NC}"
    echo -e "${RED}  - Cấu hình Nginx và SSL cho tên miền hiện tại của n8n.${NC}"
    echo -e "${RED}  - Toàn bộ thư mục cài đặt ${N8N_DIR}.${NC}"
    echo -e "\n${YELLOW}ĐỀ NGHỊ: Nếu bạn có dữ liệu quan trọng, hãy sử dụng chức năng${NC}"
    echo -e "${YELLOW}  '6) Export tất cả (workflow & credentials)'${NC}"
    echo -e "${YELLOW}để SAO LƯU dữ liệu trước khi tiếp tục.${NC}"
    echo -e "${RED}Hành động này KHÔNG THỂ HOÀN TÁC.${NC}"

    local confirm_prompt
    confirm_prompt=$(echo -e "${YELLOW}Nhập '${NC}${RED}delete${NC}${YELLOW}' để xác nhận xóa, hoặc nhập '${NC}${CYAN}0${NC}${YELLOW}' để quay lại menu: ${NC}")
    local confirmation
    echo -n "$confirm_prompt"
    read -r confirmation

    if [[ "$confirmation" == "0" ]]; then
        echo -e "\n${GREEN}Huỷ bỏ thao tác. Quay lại menu chính...${NC}"
        sleep 1
        return 0
    elif [[ "$confirmation" != "delete" ]]; then
        echo -e "\n${RED}Xác nhận không hợp lệ. Huỷ bỏ thao tác.${NC}"
        echo -e "${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
        return 0
    fi

    echo -e "\n${CYAN}Bắt đầu quá trình xóa N8N...${NC}"
    trap 'stop_spinner; echo -e "\n${RED}Đã xảy ra lỗi hoặc huỷ bỏ trong quá trình xóa N8N.${NC}"; read -r -p "Nhấn Enter để quay lại menu..."; return 0;' ERR SIGINT SIGTERM

    start_spinner "Đang xóa N8N..."

    if [ -d "${N8N_DIR}" ]; then
        if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
            stop_spinner
            start_spinner "Đang tiến hành xóa dữ liệu..."
            pushd "${N8N_DIR}" > /dev/null || { stop_spinner; echo -e "${RED}Lỗi: Không thể truy cập ${N8N_DIR}.${NC}"; return 1; }
            if ! sudo $DOCKER_COMPOSE_CMD down -v --remove-orphans > /tmp/n8n_reinstall_docker_down.log 2>&1; then
                stop_spinner
                echo -e "${RED}Lỗi khi dừng/xóa Docker. Kiểm tra /tmp/n8n_reinstall_docker_down.log.${NC}"
            fi
            popd > /dev/null
            stop_spinner
            start_spinner "Tiếp tục xóa N8N..."
        else
            echo -e "\r\033[K ${YELLOW}Không tìm thấy file ${DOCKER_COMPOSE_FILE}. Bỏ qua bước xóa Docker.${NC}"
        fi

        local domain_to_remove
        if [ -f "${ENV_FILE}" ]; then
            domain_to_remove=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
        fi

        if [[ -n "$domain_to_remove" ]]; then
            local nginx_conf_avail="/etc/nginx/sites-available/${domain_to_remove}.conf"
            local nginx_conf_enabled="/etc/nginx/sites-enabled/${domain_to_remove}.conf"

            if [ -f "$nginx_conf_avail" ] || [ -L "$nginx_conf_enabled" ]; then
                 stop_spinner
                 start_spinner "Xóa cấu hình Nginx cho ${domain_to_remove}..."
                 sudo rm -f "$nginx_conf_avail"
                 sudo rm -f "$nginx_conf_enabled"
                 sudo systemctl reload nginx > /tmp/n8n_reinstall_nginx_reload.log 2>&1
                 stop_spinner
                 start_spinner "Tiếp tục xóa N8N..."
            fi

            stop_spinner
            start_spinner "Xóa chứng chỉ SSL cho ${domain_to_remove} (nếu có)..."
            if sudo certbot certificates -d "${domain_to_remove}" 2>/dev/null | grep -q "Certificate Name:"; then
                 local cert_name_to_delete
                 cert_name_to_delete=$(sudo certbot certificates -d "${domain_to_remove}" 2>/dev/null | grep "Certificate Name:" | head -n 1 | awk '{print $3}')
                 if [[ -n "$cert_name_to_delete" ]]; then
                    if ! sudo certbot delete --cert-name "${cert_name_to_delete}" --non-interactive > /tmp/n8n_reinstall_cert_delete.log 2>&1; then
                        stop_spinner
                        echo -e "${RED}Lỗi khi xóa chứng chỉ SSL. Kiểm tra /tmp/n8n_reinstall_cert_delete.log.${NC}"
                    else
                        stop_spinner
                    fi
                 else
                    stop_spinner
                    echo -e "${YELLOW}Không thể xác định tên chứng chỉ SSL cho ${domain_to_remove}.${NC}"
                 fi
            else
                 stop_spinner
                 echo -e "${YELLOW}Không tìm thấy chứng chỉ SSL cho ${domain_to_remove} để xóa.${NC}"
            fi
            start_spinner "Tiếp tục xóa N8N..."
        else
             echo -e "\r\033[K ${YELLOW}Không tìm thấy tên miền trong ${ENV_FILE}. Bỏ qua xóa Nginx/SSL.${NC}"
        fi

        if [ -d "${NGINX_EXPORT_INCLUDE_DIR}" ]; then
            stop_spinner; start_spinner "Xóa thư mục cấu hình export Nginx tạm thời..."
            sudo rm -rf "${NGINX_EXPORT_INCLUDE_DIR}"
            stop_spinner; start_spinner "Tiếp tục xóa N8N..."
        fi

        stop_spinner
        start_spinner "Xóa thư mục cài đặt ${N8N_DIR}..."
        if ! sudo rm -rf "${N8N_DIR}"; then
            stop_spinner
            echo -e "${RED}Lỗi khi xóa thư mục ${N8N_DIR}.${NC}"
        else
            stop_spinner
        fi
    else
        echo -e "\r\033[K ${YELLOW}Thư mục ${N8N_DIR} không tồn tại. Bỏ qua bước xóa.${NC}"
    fi

    stop_spinner
    echo -e "${GREEN}Quá trình gỡ cài đặt và xóa dữ liệu N8N hoàn tất.${NC}"
    echo -e "\n${CYAN}Tiến hành cài đặt lại N8N...${NC}"

    trap - ERR SIGINT SIGTERM

    install
}
