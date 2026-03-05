# --- Hàm Cloudflare Tunnel ---
setup_cloudflare_tunnel() {
    check_root
    echo -e "\n${CYAN}--- Cấu hình Cloudflare Tunnel (Cho Localhost/Homelab) ---${NC}"

    if [[ ! -f "${ENV_FILE}" ]]; then
        echo -e "${RED}Lỗi: Không tìm thấy file cấu hình ${ENV_FILE}.${NC}"
        echo -e "${YELLOW}Vui lòng cài đặt hệ thống N8N ở chế độ Localhost trước.${NC}"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
        return 0
    fi

    # 1. Cài đặt cloudflared nếu chưa có
    if ! command_exists cloudflared; then
        start_spinner "Đang cài đặt cloudflared (Cloudflare Tunnel Client)..."
        local arch
        arch=$(dpkg --print-architecture)
        if [[ "$arch" == "amd64" ]]; then
            curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
        elif [[ "$arch" == "arm64" ]]; then
            curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o cloudflared.deb
        elif [[ "$arch" == "armhf" ]]; then
            curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-armhf.deb -o cloudflared.deb
        else
            stop_spinner
            echo -e "${RED}Kiến trúc $arch không được hỗ trợ tự động. Vui lòng cài đặt thủ công.${NC}"
            return 1
        fi
        
        sudo dpkg -i cloudflared.deb > /dev/null 2>&1
        rm -f cloudflared.deb
        
        if ! command_exists cloudflared; then
            stop_spinner
            echo -e "${RED}Cài đặt cloudflared thất bại.${NC}"
            return 1
        fi
        stop_spinner
        echo -e "${GREEN}[+] Đã cài đặt cloudflared thành công.${NC}"
    fi

    # Kiểm tra chứng chỉ login
    if [[ ! -d "/root/.cloudflared" || -z "$(ls -A /root/.cloudflared/*.pem 2>/dev/null)" ]]; then
        echo -e "\n${YELLOW}[!] Bạn chưa đăng nhập Cloudflare Tunnel.${NC}"
        echo -e "Hãy sao chép đường link bên dưới, dán vào trình duyệt và chọn Domain bạn đang quản lý trên Cloudflare."
        echo -e "Chờ sau khi Authorization Success trên trình duyệt mới nhấn phím bất kỳ ở đây."
        
        # Chạy lệnh login interactive
        sudo cloudflared tunnel login

        echo -e "${GREEN}[+] Xác thực xong.${NC}"
    else
         echo -e "${GREEN}[+] Bỏ qua đăng nhập (Đã có chứng chỉ Cloudflare Account).${NC}"
    fi

    # Kiểm tra tunnel hiện tại
    local tunnel_name="n8n-tunnel"
    local tunnel_uuid=""

    # 2. Xóa tunnel cũ nếu có
    if sudo cloudflared tunnel list | grep -q "$tunnel_name"; then
        echo -e "${YELLOW}Tunnel '$tunnel_name' đã tồn tại.${NC}"
        read -p "$(echo -e ${CYAN}'Bạn có muốn xóa Tunnel cũ và tạo lại? (y/n) [n]: '${NC})" choice_recreate
        if [[ "$choice_recreate" == "y" || "$choice_recreate" == "Y" ]]; then
            sudo cloudflared tunnel cleanup "$tunnel_name" &>/dev/null
            sudo cloudflared tunnel delete "$tunnel_name" &>/dev/null
            sudo rm -f "/root/.cloudflared/${tunnel_name}.json"
            echo -e "${GREEN}[+] Đã xóa Tunnel cũ.${NC}"
        else
            echo -e "${YELLOW}Hủy thao tác cài đặt Tunnel.${NC}"
            if [[ "$NON_INTERACTIVE" != "true" ]]; then read -r -p "Nhấn Enter để quay lại menu..."; fi
            return 0
        fi
    fi

    echo -e "\n${CYAN}Bắt đầu tạo Tunnel mới...${NC}"
    
    # Lấy UUID sau khi tạo
    local create_output
    create_output=$(sudo cloudflared tunnel create "$tunnel_name" 2>&1)
    if echo "$create_output" | grep -q "Created tunnel"; then
        tunnel_uuid=$(echo "$create_output" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
        echo -e "${GREEN}[+] Đã tạo Tunnel thành công. UUID: ${tunnel_uuid}${NC}"
    else
        echo -e "${RED}Lỗi khi tạo tunnel:${NC}"
        echo "$create_output"
        return 1
    fi

    # 3. Yêu cầu nhập domain
    local public_domain=""
    if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_DOMAIN" ]]; then
         public_domain="$CLI_DOMAIN"
    else
         while true; do
            read -p "$(echo -e ${CYAN}'Nhập tên miền public (VD: n8n.domain.com) để trỏ Tunnel: '${NC})" public_domain
            if [[ -z "$public_domain" ]]; then
                echo -e "${RED}Tên miền không được để trống.${NC}"
            else
                break
            fi
         done
    fi

    start_spinner "Tạo DNS Route cho ${public_domain} trên tài khoản Cloudflare..."
    if ! sudo cloudflared tunnel route dns "$tunnel_name" "$public_domain" >/dev/null 2>&1; then
        stop_spinner
        echo -e "${YELLOW}Có thể DNS đã tồn tại. Thử ghi chép đè...${NC}"
        sudo cloudflared tunnel route dns -f "$tunnel_name" "$public_domain" >/dev/null 2>&1
    fi
    stop_spinner
    echo -e "${GREEN}[+] Trỏ DNS thành công.${NC}"

    # Cập nhật file .env cho chuẩn lại tên miền webhook của N8N
    update_env_file "DOMAIN_NAME" "$public_domain"

    # 4. Ghi cấu hình config.yml
    start_spinner "Lưu cấu hình config.yml cho Tunnel..."
    sudo mkdir -p /etc/cloudflared
    sudo bash -c "cat > /etc/cloudflared/config.yml" <<EOF
tunnel: ${tunnel_uuid}
credentials-file: /root/.cloudflared/${tunnel_uuid}.json

ingress:
  - hostname: ${public_domain}
    service: http://127.0.0.1:80
  - service: http_status:404
EOF
    stop_spinner

    # 5. Cài đặt thành Service và chạy
    start_spinner "Cài đặt & khởi động bộ định tuyến hệ thống..."
    sudo cloudflared service uninstall &>/dev/null
    sudo cloudflared service install &>/dev/null
    sudo systemctl enable cloudflared &>/dev/null
    sudo systemctl restart cloudflared &>/dev/null
    
    # Khởi động lại Nginx và N8N Docker để lấy tên miền public nhận webhook chuẩn
    sudo systemctl restart nginx &>/dev/null
    pushd "${N8N_DIR}" > /dev/null
    sudo $DOCKER_COMPOSE_CMD up -d --force-recreate &>/dev/null
    popd > /dev/null

    stop_spinner

    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}      Thiết lập Cloudflare Tunnel Hoàn Tất!       ${NC}"
    echo -e "${GREEN}===================================================${NC}"
    echo -e "Bây giờ bạn có thể truy cập hệ thống tại: ${CYAN}https://${public_domain}${NC}"
    echo -e "N8N Webhook sẽ tự sinh với IP đúng của domain này."
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo -e "\n${YELLOW}Nhấn Enter để quay lại menu chính...${NC}"
        read -r
    fi
}
