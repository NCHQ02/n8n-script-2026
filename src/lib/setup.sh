# --- Các bước Cài đặt ---

install_prerequisites() {
  start_spinner "Kiểm tra và cài đặt các gói phụ thuộc..."

  run_silent_command "Cập nhật danh sách gói" "apt-get update -y" "false"
  if [ $? -ne 0 ]; then return 1; fi

  if ! is_package_installed nginx; then
    run_silent_command "Cài đặt Nginx" "apt-get install -y nginx" "false"
    if [ $? -ne 0 ]; then return 1; fi
    sudo systemctl enable nginx >/dev/null 2>&1
    sudo systemctl start nginx >/dev/null 2>&1
  fi

  if ! command_exists docker; then
    if ! curl -fsSL https://get.docker.com -o get-docker.sh; then
        echo -e "${RED}Lỗi tải script cài đặt Docker.${NC}"
        return 1
    fi
    run_silent_command "Cài đặt Docker từ script" "sh get-docker.sh" "false"
    if [ $? -ne 0 ]; then rm get-docker.sh; return 1; fi
    sudo usermod -aG docker "$(whoami)" >/dev/null 2>&1
    rm get-docker.sh
  fi

  if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
  elif command_exists docker-compose; then
    DOCKER_COMPOSE_CMD="docker-compose"
  else
    # Tải phiên bản mới nhất của Docker Compose từ GitHub
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$LATEST_COMPOSE_VERSION" ]]; then
        LATEST_COMPOSE_VERSION="1.29.2"
    fi
    run_silent_command "Tải Docker Compose v${LATEST_COMPOSE_VERSION}" \
      "curl -L \"https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "false"
    if [ $? -ne 0 ]; then return 1; fi
    sudo chmod +x /usr/local/bin/docker-compose
    DOCKER_COMPOSE_CMD="docker-compose"
  fi

  if ! command_exists certbot; then
    run_silent_command "Cài đặt Certbot và plugin Nginx" "apt-get install -y certbot python3-certbot-nginx" "false"
    if [ $? -ne 0 ]; then return 1; fi
  fi

  if ! command_exists dig; then
    run_silent_command "Cài đặt dnsutils (cho lệnh dig)" "apt-get install -y dnsutils" "false"
    if [ $? -ne 0 ]; then return 1; fi
  fi

  if ! command_exists curl; then
    run_silent_command "Cài đặt curl" "apt-get install -y curl" "false"
    if [ $? -ne 0 ]; then return 1; fi
  fi

  if command_exists ufw; then
    sudo ufw allow http > /dev/null
    sudo ufw allow https > /dev/null
  fi

  stop_spinner
  echo -e "${GREEN}Kiểm tra và cài đặt gói phụ thuộc hoàn tất.${NC}"
}

setup_directories_and_env_file() {
  start_spinner "Thiết lập thư mục và file .env..."
  if [ ! -d "${N8N_DIR}" ]; then
    sudo mkdir -p "${N8N_DIR}"
  fi
  if [ ! -f "${ENV_FILE}" ]; then
    sudo touch "${ENV_FILE}"
    sudo chmod 600 "${ENV_FILE}"  # chỉ root mới đọc được
  fi
  sudo mkdir -p "${NGINX_EXPORT_INCLUDE_DIR}"
  sudo mkdir -p "${TEMPLATE_DIR}"

  stop_spinner
  echo -e "${GREEN}Thiết lập thư mục và file .env hoàn tất.${NC}"
}

get_domain_and_dns_check_reusable() {
  local result_var_name="$1"
  local current_domain_to_avoid="${2:-}"
  local prompt_message="${3:-Nhập tên miền bạn muốn sử dụng cho n8n (ví dụ: n8n.example.com)}"

  trap 'echo -e "\n${YELLOW}Huỷ bỏ nhập tên miền.${NC}"; return 1;' SIGINT SIGTERM

  echo -e "${CYAN}---> Nhập thông tin tên miền (Nhấn Ctrl+C để huỷ)...${NC}"
  local new_domain_input
  local server_ip
  local resolved_ip

  server_ip=$(get_public_ip)
  if [ $? -ne 0 ]; then
    trap - SIGINT SIGTERM
    return 1
  fi

  echo -e "Địa chỉ IP public của server là: ${GREEN}${server_ip}${NC}"

  while true; do
    local prompt_string
    prompt_string=$(echo -e "${prompt_message}: ")
    echo -n "$prompt_string"

    if ! read -r new_domain_input; then
        echo -e "\n${YELLOW}Huỷ bỏ nhập tên miền.${NC}"
        trap - SIGINT SIGTERM
        return 1
    fi

    if [[ -z "$new_domain_input" ]]; then
      echo -e "${RED}Tên miền không được để trống. Vui lòng nhập lại.${NC}"
      continue
    fi

    if [[ -n "$current_domain_to_avoid" && "$new_domain_input" == "$current_domain_to_avoid" ]]; then
      echo -e "${YELLOW}Tên miền mới (${new_domain_input}) trùng với tên miền hiện tại (${current_domain_to_avoid}).${NC}"
      echo -e "${YELLOW}Vui lòng nhập một tên miền khác.${NC}"
      continue
    fi

    start_spinner "Kiểm tra DNS cho ${new_domain_input}..."
    resolved_ip=$(timeout 5 dig +short A "$new_domain_input" @1.1.1.1 | tail -n1)
    if [[ -z "$resolved_ip" ]]; then
        # Thử tra cứu CNAME nếu không có bản ghi A
        local cname_target
        cname_target=$(timeout 5 dig +short CNAME "$new_domain_input" @1.1.1.1 | tail -n1)
        if [[ -n "$cname_target" ]]; then
             resolved_ip=$(timeout 5 dig +short A "$cname_target" @1.1.1.1 | tail -n1)
        fi
    fi
    stop_spinner

    if [[ "$resolved_ip" == "$server_ip" ]]; then
      echo -e "${GREEN}DNS cho ${new_domain_input} đã được trỏ về IP server chính xác (${resolved_ip}).${NC}"
      printf -v "$result_var_name" "%s" "$new_domain_input"
      trap - SIGINT SIGTERM
      break
    else
      echo -e "${RED}Lỗi: Tên miền ${new_domain_input} (trỏ về ${resolved_ip:-'không tìm thấy bản ghi A/CNAME hoặc timeout'}) chưa được trỏ về IP server (${server_ip}).${NC}"
      echo -e "${YELLOW}Vui lòng trỏ DNS A record của tên miền ${new_domain_input} về địa chỉ IP ${server_ip} và đợi DNS cập nhật.${NC}"

      trap 'echo -e "\n${YELLOW}Huỷ bỏ nhập tên miền.${NC}"; return 1;' SIGINT SIGTERM
      local choice_prompt
      choice_prompt=$(echo -e "Nhấn Enter để kiểm tra lại, hoặc '${CYAN}s${NC}' để bỏ qua, '${CYAN}0${NC}' để huỷ bỏ: ")
      echo -n "$choice_prompt"
      if ! read -r dns_choice; then
          echo -e "\n${YELLOW}Huỷ bỏ nhập lựa chọn.${NC}"
          trap - SIGINT SIGTERM
          return 1
      fi

      if [[ "$dns_choice" == "s" || "$dns_choice" == "S" ]]; then
        echo -e "${YELLOW}Bỏ qua kiểm tra DNS. Đảm bảo bạn đã trỏ DNS chính xác.${NC}"
        printf -v "$result_var_name" "%s" "$new_domain_input"
        trap - SIGINT SIGTERM
        break
      elif [[ "$dns_choice" == "0" ]]; then
        echo -e "${YELLOW}Huỷ bỏ nhập tên miền.${NC}"
        trap - SIGINT SIGTERM
        return 1
      fi
    fi
  done
  trap - SIGINT SIGTERM
  return 0
}

prompt_database_configuration() {
  local db_type="local"
  if [[ "$NON_INTERACTIVE" == "true" && -n "$CLI_EXTERNAL_DB" ]]; then
    db_type="external"
  elif [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo -e "\n${CYAN}--- Cấu hình Database & Redis ---${NC}"
    echo -e "1) Cài đặt Database Local (Tự động cấp phát Postgres & Redis qua Docker)"
    echo -e "2) Sử dụng Database External (Supabase, AWS RDS, Redis Cloud...)"
    local db_choice
    read -p "Nhập lựa chọn của bạn (1-2) [Mặc định: 1]: " db_choice
    if [[ "$db_choice" == "2" ]]; then
      db_type="external"
    fi
  fi

  update_env_file "DB_SETUP_TYPE" "$db_type"

  if [[ "$db_type" == "external" ]]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      update_env_file "POSTGRES_HOST" "${CLI_DB_HOST:-}"
      update_env_file "POSTGRES_PORT" "${CLI_DB_PORT:-5432}"
      update_env_file "POSTGRES_DB" "${CLI_DB_NAME:-}"
      update_env_file "POSTGRES_USER" "${CLI_DB_USER:-}"
      update_env_file "POSTGRES_PASSWORD" "${CLI_DB_PASSWORD:-}"
      update_env_file "REDIS_HOST" "${CLI_REDIS_HOST:-}"
      update_env_file "REDIS_PORT" "${CLI_REDIS_PORT:-6379}"
      update_env_file "REDIS_PASSWORD" "${CLI_REDIS_PASSWORD:-}"
    else
      echo -e "\n${CYAN}[1/2] Cấu hình PostgreSQL External${NC}"
      local pg_host pg_port pg_db pg_user pg_pass
      read -p "Host (VD: db.supabase.co): " pg_host
      read -p "Port [5432]: " pg_port
      pg_port=${pg_port:-5432}
      read -p "Database Name: " pg_db
      read -p "User: " pg_user
      read -p "Password: " -s pg_pass
      echo ""

      echo -e "\n${CYAN}[2/2] Cấu hình Redis External (Tuỳ chọn)${NC}"
      local redis_host redis_port redis_pass
      read -p "Host (Để rỗng nếu không dùng Redis): " redis_host
      if [[ -n "$redis_host" ]]; then
        read -p "Port [6379]: " redis_port
        redis_port=${redis_port:-6379}
        read -p "Password: " -s redis_pass
        echo ""
      fi

      update_env_file "POSTGRES_HOST" "$pg_host"
      update_env_file "POSTGRES_PORT" "$pg_port"
      update_env_file "POSTGRES_DB" "$pg_db"
      update_env_file "POSTGRES_USER" "$pg_user"
      update_env_file "POSTGRES_PASSWORD" "$pg_pass"
      if [[ -n "$redis_host" ]]; then
        update_env_file "REDIS_HOST" "$redis_host"
        update_env_file "REDIS_PORT" "$redis_port"
        update_env_file "REDIS_PASSWORD" "$redis_pass"
      fi
    fi
  fi
}

generate_credentials() {
  start_spinner "Tạo thông tin đăng nhập và cấu hình..."
  update_env_file "N8N_ENCRYPTION_KEY" "$(generate_random_string 64)"

  local system_timezone
  system_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null)
  update_env_file "GENERIC_TIMEZONE" "${system_timezone:-Asia/Ho_Chi_Minh}"

  local db_setup_type
  if [ -f "${ENV_FILE}" ]; then
    db_setup_type=$(grep "^DB_SETUP_TYPE=" "${ENV_FILE}" | cut -d'=' -f2)
  fi

  if [[ "$db_setup_type" != "external" ]]; then
    update_env_file "POSTGRES_DB" "n8n_db_$(generate_random_string 6 | tr '[:upper:]' '[:lower:]')"
    update_env_file "POSTGRES_USER" "n8n_user_$(generate_random_string 8 | tr '[:upper:]' '[:lower:]')"
    update_env_file "POSTGRES_PASSWORD" "$(generate_random_string 32)"

    update_env_file "REDIS_PASSWORD" "$(generate_random_string 32)"
  fi

  stop_spinner
  echo -e "${GREEN}Thông tin đăng nhập và cấu hình đã được lưu vào ${ENV_FILE}.${NC}"
  echo -e "${YELLOW}Quan trọng: Vui lòng sao lưu file ${ENV_FILE}.${NC}"
}

create_docker_compose_config() {
  start_spinner "Tạo file docker-compose.yml..."
  local n8n_encryption_key_val postgres_user_val postgres_password_val postgres_db_val postgres_host_val postgres_port_val redis_password_val redis_host_val redis_port_val db_setup_type_val
  local domain_name_val generic_timezone_val

  if [ -f "${ENV_FILE}" ]; then
    n8n_encryption_key_val=$(grep "^N8N_ENCRYPTION_KEY=" "${ENV_FILE}" | cut -d'=' -f2)
    postgres_user_val=$(grep "^POSTGRES_USER=" "${ENV_FILE}" | cut -d'=' -f2)
    postgres_password_val=$(grep "^POSTGRES_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)
    postgres_db_val=$(grep "^POSTGRES_DB=" "${ENV_FILE}" | cut -d'=' -f2)
    postgres_host_val=$(grep "^POSTGRES_HOST=" "${ENV_FILE}" | cut -d'=' -f2)
    postgres_port_val=$(grep "^POSTGRES_PORT=" "${ENV_FILE}" | cut -d'=' -f2)
    redis_password_val=$(grep "^REDIS_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)
    redis_host_val=$(grep "^REDIS_HOST=" "${ENV_FILE}" | cut -d'=' -f2)
    redis_port_val=$(grep "^REDIS_PORT=" "${ENV_FILE}" | cut -d'=' -f2)
    domain_name_val=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
    generic_timezone_val=$(grep "^GENERIC_TIMEZONE=" "${ENV_FILE}" | cut -d'=' -f2)
    db_setup_type_val=$(grep "^DB_SETUP_TYPE=" "${ENV_FILE}" | cut -d'=' -f2)
  fi

  local n8n_db_host="postgres"
  local n8n_db_port="5432"

  if [[ "$db_setup_type_val" == "external" ]]; then
    n8n_db_host="${postgres_host_val}"
    n8n_db_port="${postgres_port_val}"
  fi

  local services_postgres=""
  local services_redis=""
  local volumes_postgres=""
  local volumes_redis=""
  local n8n_depends_on=""

  if [[ "$db_setup_type_val" != "external" ]]; then
services_postgres="
  postgres:
    image: postgres:15-alpine
    restart: always
    container_name: n8n_postgres
    environment:
      - POSTGRES_USER=\${POSTGRES_USER:-${postgres_user_val}}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-${postgres_password_val}}
      - POSTGRES_DB=\${POSTGRES_DB:-${postgres_db_val}}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U \${POSTGRES_USER:-${postgres_user_val}} -d \${POSTGRES_DB:-${postgres_db_val}}\"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging:
      driver: \"json-file\"
      options:
        max-size: \"10m\"
        max-file: \"3\"
"
services_redis="
  redis:
    image: redis:7-alpine
    restart: always
    container_name: n8n_redis
    command: redis-server --save 60 1 --loglevel warning --requirepass \${REDIS_PASSWORD:-${redis_password_val}}
    ports:
      - \"127.0.0.1:6379:6379\"
    volumes:
      - redis_data:/data
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"-a\", \"\${REDIS_PASSWORD:-${redis_password_val}}\", \"ping\"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging:
      driver: \"json-file\"
      options:
        max-size: \"10m\"
        max-file: \"3\"
"
volumes_postgres="  postgres_data:"
volumes_redis="  redis_data:"
n8n_depends_on="
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy"
  fi

  sudo bash -c "cat > ${DOCKER_COMPOSE_FILE}" <<EOF
# version: '3.8'

services:${services_postgres}${services_redis}
  ${N8N_SERVICE_NAME}:
    image: n8nio/n8n:latest
    restart: always
    container_name: ${N8N_CONTAINER_NAME}
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=\${POSTGRES_HOST:-${n8n_db_host}}
      - DB_POSTGRESDB_PORT=\${POSTGRES_PORT:-${n8n_db_port}}
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB:-${postgres_db_val}}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER:-${postgres_user_val}}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD:-${postgres_password_val}}
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-${n8n_encryption_key_val}}
      - GENERIC_TIMEZONE=\${GENERIC_TIMEZONE:-${generic_timezone_val}}
      - N8N_HOST=\${DOMAIN_NAME:-${domain_name_val}}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${DOMAIN_NAME:-${domain_name_val}}/
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_RUNNERS_ENABLED=true
    volumes:
      - n8n_data:/home/node/.n8n${n8n_depends_on}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
${volumes_postgres}
${volumes_redis}
  n8n_data:
EOF
  stop_spinner
}

start_docker_containers() {
  start_spinner "Khởi chạy N8N Cloud..."
  cd "${N8N_DIR}" || { return 1; }

  run_silent_command "Tải Docker images" "$DOCKER_COMPOSE_CMD pull" "false"

  run_silent_command "Khởi chạy container qua docker-compose" "$DOCKER_COMPOSE_CMD up -d --force-recreate" "false"
  if [ $? -ne 0 ]; then return 1; fi

  # Chờ container sẵn sàng bằng cách polling healthcheck thay vì sleep cố định
  local max_wait=60
  local elapsed=0
  local interval=3
  stop_spinner
  echo -n -e "${CYAN}Chờ container N8N khởi động${NC}"
  while [[ $elapsed -lt $max_wait ]]; do
    local health
    health=$(sudo docker inspect --format='{{.State.Health.Status}}' "${N8N_CONTAINER_NAME}" 2>/dev/null || echo "")
    if [[ "$health" == "healthy" ]] || sudo docker exec "${N8N_CONTAINER_NAME}" echo "" &>/dev/null 2>&1; then
      echo -e " ${GREEN}OK${NC}"
      break
    fi
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  if [[ $elapsed -ge $max_wait ]]; then
    echo -e " ${YELLOW}(timeout — container có thể vẫn đang khởi động)${NC}"
  fi

  echo -e "${GREEN}N8N Cloud đã khởi chạy.${NC}"
  cd - > /dev/null
}

configure_nginx_and_ssl() {
  start_spinner "Cấu hình Nginx và SSL với Certbot..."
  local domain_name
  local user_email
  domain_name=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)
  user_email=$(grep "^LETSENCRYPT_EMAIL=" "${ENV_FILE}" | cut -d'=' -f2)
  local webroot_path="/var/www/html"

  if [[ -z "$domain_name" || -z "$user_email" ]]; then
    echo -e "${RED}Không tìm thấy DOMAIN_NAME hoặc LETSENCRYPT_EMAIL trong file .env.${NC}"
    return 1
  fi

  local nginx_conf_file="/etc/nginx/sites-available/${domain_name}.conf"

  sudo mkdir -p "${webroot_path}/.well-known/acme-challenge"
  sudo chown www-data:www-data "${webroot_path}" -R

  # Tạo cấu hình Nginx tạm để Let's Encrypt xác minh qua HTTP
  run_silent_command "Tạo cấu hình Nginx ban đầu cho HTTP challenge" \
    "bash -c \"cat > ${nginx_conf_file}\" <<EOF
server {
    listen 80;
    server_name ${domain_name};

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
        allow all;
    }
}
EOF" "false" || return 1

  sudo ln -sfn "${nginx_conf_file}" "/etc/nginx/sites-enabled/${domain_name}.conf"

  run_silent_command "Kiểm tra cấu hình Nginx HTTP" "nginx -t" "false" || return 1

  sudo systemctl reload nginx >/dev/null 2>&1

  if ! sudo certbot certonly --webroot -w "${webroot_path}" -d "${domain_name}" \
        --agree-tos --email "${user_email}" --non-interactive --quiet \
        --preferred-challenges http > /tmp/certbot_obtain.log 2>&1; then
    echo -e "${RED}Lấy chứng chỉ SSL thất bại.${NC}"
    echo -e "${YELLOW}Kiểm tra log Certbot tại /var/log/letsencrypt/ và /tmp/certbot_obtain.log.${NC}"
    return 1
  fi

  sudo mkdir -p /etc/letsencrypt
  if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    run_silent_command "Tải tuỳ chọn SSL của Let's Encrypt" \
    "curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -o /etc/letsencrypt/options-ssl-nginx.conf" "false" || return 1
  fi
  if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    run_silent_command "Tạo tham số SSL DH (2048-bit)" "openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048" "false" || return 1
  fi

  # Tạo cấu hình Nginx hoàn chỉnh với SSL, proxy pass và security headers
  run_silent_command "Tạo cấu hình Nginx cuối cùng với SSL và proxy" \
  "bash -c \"cat > ${nginx_conf_file}\" <<EOF
server {
    listen 80;
    server_name ${domain_name};

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
        allow all;
    }

    location / {
        return 301 https://\\\$host\\\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${domain_name};

    ssl_certificate /etc/letsencrypt/live/${domain_name}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain_name}/privkey.pem;

    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /.well-known/acme-challenge/ {
        root ${webroot_path};
        allow all;
    }

    include ${NGINX_EXPORT_INCLUDE_DIR}/${NGINX_EXPORT_INCLUDE_FILE_BASENAME}_*.conf;

    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;
    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains; preload\" always;

    client_max_body_size 100M;

    access_log /var/log/nginx/${domain_name}.access.log;
    error_log /var/log/nginx/${domain_name}.error.log;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 7200s;
        proxy_send_timeout 7200s;
    }

    location ~ /\\\\. {
        deny all;
    }
}
EOF" "false" || return 1

  if [ ! -f "${NGINX_EXPORT_INCLUDE_DIR}/${NGINX_EXPORT_INCLUDE_FILE_BASENAME}.conf" ]; then
    sudo touch "${NGINX_EXPORT_INCLUDE_DIR}/${NGINX_EXPORT_INCLUDE_FILE_BASENAME}.conf"
  fi

  run_silent_command "Kiểm tra cấu hình Nginx cuối cùng" "nginx -t" "false" || return 1

  sudo systemctl reload nginx >/dev/null 2>&1

  # Bật tự động gia hạn SSL qua systemd timer
  if ! sudo systemctl list-timers | grep -q 'certbot.timer'; then
      sudo systemctl enable certbot.timer >/dev/null 2>&1
      sudo systemctl start certbot.timer >/dev/null 2>&1
  fi
  run_silent_command "Kiểm tra gia hạn SSL (dry-run)" "certbot renew --dry-run" "false"

  stop_spinner
  echo -e "${GREEN}Cấu hình Nginx và SSL hoàn tất.${NC}"
}

final_checks_and_message() {
  start_spinner "Thực hiện kiểm tra cuối cùng..."
  local domain_name
  domain_name=$(grep "^DOMAIN_NAME=" "${ENV_FILE}" | cut -d'=' -f2)

  sleep 10  # đợi N8N hoàn toàn sẵn sàng sau khi Nginx reload

  local http_status
  http_status=$(curl -L -s -o /dev/null -w "%{http_code}" "https://${domain_name}")

  stop_spinner

  if [[ "$http_status" == "200" ]]; then
    echo -e "${GREEN}N8N Cloud đã được cài đặt thành công!${NC}"
    echo -e "Bạn có thể truy cập n8n tại: ${GREEN}https://${domain_name}${NC}"
  else
    echo -e "${RED}Lỗi! Không thể truy cập n8n tại https://${domain_name} (HTTP Status: ${http_status}).${NC}"
    echo -e "${YELLOW}Vui lòng kiểm tra các bước sau:${NC}"
    echo -e "  1. Log Docker của container n8n: sudo ${DOCKER_COMPOSE_CMD} -f ${DOCKER_COMPOSE_FILE} logs ${N8N_CONTAINER_NAME}"
    echo -e "  2. Log Nginx: sudo tail -n 50 /var/log/nginx/${domain_name}.error.log"
    echo -e "  3. Trạng thái Certbot: sudo certbot certificates"
    echo -e "  4. Đảm bảo DNS đã trỏ đúng và không có firewall nào chặn port 80/443."
    return 1
  fi

  echo -e "${YELLOW}Quan trọng: Hãy lưu trữ file ${ENV_FILE} ở một nơi an toàn!${NC}"
  echo -e "Bạn nên tạo user đầu tiên cho n8n ngay sau khi truy cập."
}
