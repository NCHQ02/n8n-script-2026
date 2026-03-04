# --- Định nghĩa màu sắc ---
RED='\e[38;5;217m'      # hồng nhạt
GREEN='\e[38;5;151m'    # xanh lá nhạt
YELLOW='\e[38;5;229m'   # vàng nhạt
CYAN='\e[38;5;159m'     # xanh dương nhạt
NC='\e[0m'              # reset màu

# --- Biến toàn cục ---
N8N_DIR="/n8n-cloud"                                        # Thư mục cài đặt N8N
ENV_FILE="${N8N_DIR}/.env"                                  # File biến môi trường
DOCKER_COMPOSE_FILE="${N8N_DIR}/docker-compose.yml"         # File Docker Compose
DOCKER_COMPOSE_CMD="docker compose"                         # Lệnh docker compose (sẽ tự cập nhật)
SPINNER_PID=0                                               # PID của tiến trình spinner
N8N_CONTAINER_NAME="n8n_app"                                # Tên container N8N
N8N_SERVICE_NAME="n8n"                                      # Tên service trong docker-compose
NGINX_EXPORT_INCLUDE_DIR="/etc/nginx/n8n_export_includes"   # Thư mục chứa config Nginx tạm
NGINX_EXPORT_INCLUDE_FILE_BASENAME="n8n_export_location"    # Tên file base cho Nginx include
TEMPLATE_DIR="/n8n-templates"                               # Thư mục chứa file template trên host
TEMPLATE_FILE_NAME="import-workflow-credentials.json"       # Tên file template import
INSTALL_PATH="/usr/local/bin/n8n-host"                      # Đường dẫn cài đặt script
