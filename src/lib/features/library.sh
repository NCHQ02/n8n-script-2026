# --- Hàm Quản lý N8N Library ---

library_menu() {
  while true; do
    clear
    echo -e "${CYAN}===================================================${NC}"
    echo -e "${CYAN}             QUẢN LÝ N8N LIBRARY                  ${NC}"
    echo -e "${CYAN}===================================================${NC}"
    echo -e "1) Cài đặt / Cập nhật N8N Library"
    echo -e "2) Gỡ bỏ N8N Library"
    echo -e "3) Xem Log N8N Library"
    echo -e "0) Quay lại menu chính"
    echo -e "${CYAN}---------------------------------------------------${NC}"
    read -p "Chọn một chức năng (0-3): " library_choice

    case $library_choice in
      1) setup_n8n_library ;;
      2) remove_n8n_library ;;
      3) view_library_logs ;;
      0) break ;;
      *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}"; sleep 1 ;;
    esac
  done
}

setup_n8n_library() {
  check_root
  
  if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    echo -e "${RED}Lỗi: Bạn cần cài đặt n8n Cloud trước khi cài đặt N8N Library.${NC}"
    read -p "Nhấn Enter để quay lại..."
    return 1
  fi

  echo -e "\n${CYAN}--- Cấu hình N8N Library ---${NC}"
  
  local library_domain
  if ! get_domain_and_dns_check_reusable library_domain "" "Nhập tên miền cho N8N Library (ví dụ: lib.example.com)"; then
    return 0
  fi

  start_spinner "Đang tải mã nguồn N8N Library..."
  if [ ! -d "${N8N_DIR}/n8n-library" ]; then
    sudo git clone https://github.com/LPilic/n8n-library.git "${N8N_DIR}/n8n-library" > /dev/null 2>&1
  else
    cd "${N8N_DIR}/n8n-library" && sudo git pull > /dev/null 2>&1 && cd - > /dev/null
  fi
  
  start_spinner "Đang cấu hình N8N Library..."
  
  # Tạo Session Secret nếu chưa có
  local session_secret
  session_secret=$(grep "^LIBRARY_SESSION_SECRET=" "${ENV_FILE}" | cut -d'=' -f2)
  if [[ -z "$session_secret" ]]; then
    session_secret=$(openssl rand -hex 32)
  fi
  
  # Cập nhật file .env
  update_env_file "ENABLE_N8N_LIBRARY" "true"
  update_env_file "LIBRARY_DOMAIN_NAME" "$library_domain"
  update_env_file "LIBRARY_SESSION_SECRET" "$session_secret"
  
  # Tạo lại file docker-compose.yml
  create_docker_compose_config
  
  # Tạo Schema n8n_library trong Postgres nếu chưa có
  local pg_user pg_db
  pg_user=$(grep "^DB_POSTGRESDB_USER=" "${ENV_FILE}" | cut -d'=' -f2)
  pg_db=$(grep "^DB_POSTGRESDB_DATABASE=" "${ENV_FILE}" | cut -d'=' -f2)
  
  start_spinner "Đang khởi tạo cơ sở dữ liệu cho Library..."
  sudo docker exec -t n8n_postgres psql -U "${pg_user}" -d "${pg_db}" -c "CREATE SCHEMA IF NOT EXISTS n8n_library;" > /dev/null 2>&1
  
  # Khởi chạy lại container
  cd "${N8N_DIR}" || return 1
  sudo $DOCKER_COMPOSE_CMD up -d --remove-orphans
  cd - > /dev/null
  
  # Cấu hình Nginx & SSL cho Library Domain (Chỉ cho Standard Nginx)
  local proxy_type
  proxy_type=$(grep "^PROXY_SETUP_TYPE=" "${ENV_FILE}" | cut -d'=' -f2)
  
  if [[ "$proxy_type" == "npm" ]]; then
    stop_spinner
    show_library_npm_reminder "$library_domain"
  else
    configure_library_nginx_ssl "$library_domain"
    stop_spinner
    echo -e "${GREEN}Cài đặt N8N Library hoàn tất!${NC}"
    echo -e "Truy cập tại: ${GREEN}https://${library_domain}${NC}"
  fi
  read -p "Nhấn Enter để tiếp tục..."
}

show_library_npm_reminder() {
  local domain="$1"
  local server_ip
  server_ip=$(get_public_ip)
  
  echo -e "\n${YELLOW}---------------------------------------------------${NC}"
  echo -e "${CYAN}    HƯỚNG DẪN CẤU HÌNH NGINX PROXY MANAGER (NPM)   ${NC}"
  echo -e "${YELLOW}---------------------------------------------------${NC}"
  echo -e "Bạn đang sử dụng NPM, vui lòng thêm Proxy Host thủ công:"
  echo -e "1. Truy cập: ${GREEN}http://${server_ip}:81${NC}"
  echo -e "2. Thêm Proxy Host mới:"
  echo -e "   - Domains:       ${GREEN}${domain}${NC}"
  echo -e "   - Scheme:        ${CYAN}http${NC}"
  echo -e "   - Forward Host:  ${CYAN}${N8N_LIBRARY_CONTAINER_NAME}${NC}"
  echo -e "   - Forward Port:  ${CYAN}3100${NC}"
  echo -e "3. Tại tab SSL, chọn 'Request a new SSL Certificate'."
  echo -e "${YELLOW}---------------------------------------------------${NC}"
}

configure_library_nginx_ssl() {
  local domain="$1"
  local user_email
  user_email=$(grep "^LETSENCRYPT_EMAIL=" "${ENV_FILE}" | cut -d'=' -f2)
  local webroot_path="/var/www/html"

  if [[ "$domain" == "localhost" ]]; then
    return 0 # Không hỗ trợ SSL cho localhost trong scope này
  fi

  start_spinner "Cấu hình Nginx và SSL cho ${domain}..."
  
  local nginx_conf_file="/etc/nginx/sites-available/${domain}.conf"

  # Tạo cấu hình Nginx tạm cho challenge
  sudo bash -c "cat > ${nginx_conf_file}" <<EOF
server {
    listen 80;
    server_name ${domain};

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
        allow all;
    }
}
EOF

  sudo ln -sfn "${nginx_conf_file}" "/etc/nginx/sites-enabled/${domain}.conf"
  sudo systemctl reload nginx

  # Lấy SSL
  if ! sudo certbot certonly --webroot -w "${webroot_path}" -d "${domain}" \
        --agree-tos --email "${user_email}" --non-interactive --quiet \
        --preferred-challenges http; then
    echo -e "${RED}Lấy chứng chỉ SSL cho ${domain} thất bại.${NC}"
    return 1
  fi

  # Cấu hình Full SSL
  sudo bash -c "cat > ${nginx_conf_file}" <<EOF
server {
    listen 80;
    server_name ${domain};

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
        allow all;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3100;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';

        proxy_buffering off;
        proxy_cache off;
    }
}
EOF

  sudo systemctl reload nginx
  stop_spinner
}

remove_n8n_library() {
  check_root
  echo -e "${YELLOW}Bạn có chắc chắn muốn gỡ bỏ N8N Library? (y/n)${NC}"
  read -r confirm
  if [[ "$confirm" != "y" ]]; then return 0; fi

  start_spinner "Đang gỡ bỏ N8N Library..."
  
  local domain
  domain=$(grep "^LIBRARY_DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)

  # Cập nhật file .env
  update_env_file "ENABLE_N8N_LIBRARY" "false"
  
  # Tạo lại file docker-compose.yml
  create_docker_compose_config
  
  # Khởi chạy lại container (sẽ xóa n8n-library service)
  cd "${N8N_DIR}" || return 1
  sudo $DOCKER_COMPOSE_CMD up -d --remove-orphans
  cd - > /dev/null

  # Xóa Nginx config
  if [[ -n "$domain" ]]; then
    sudo rm -f "/etc/nginx/sites-available/${domain}.conf"
    sudo rm -f "/etc/nginx/sites-enabled/${domain}.conf"
    sudo systemctl reload nginx
  fi

  stop_spinner
  echo -e "${GREEN}Đã gỡ bỏ N8N Library.${NC}"
  read -p "Nhấn Enter để tiếp tục..."
}

view_library_logs() {
  sudo docker logs -f "${N8N_LIBRARY_CONTAINER_NAME}"
}
