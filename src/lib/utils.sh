# --- Hàm Kiểm Tra ---
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "\n${RED}[!] Lỗi: Bạn cần chạy script với quyền quản trị viên (root).${NC}\n"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_package_installed() {
  # Kiểm tra gói đã cài chưa — hỗ trợ cả Debian/Ubuntu (dpkg) và RHEL/CentOS (rpm)
  if command_exists dpkg; then
    dpkg -s "$1" &> /dev/null
  elif command_exists rpm; then
    rpm -q "$1" &> /dev/null
  else
    # Fallback: kiểm tra qua tên lệnh
    command_exists "$1"
  fi
}

# --- Hàm Phụ Trợ ---
get_public_ip() {
  local ip
  ip=$(curl -s --ipv4 https://ifconfig.co) || \
  ip=$(curl -s --ipv4 https://api.ipify.org) || \
  ip=$(curl -s --ipv4 https://icanhazip.com) || \
  ip=$(hostname -I | awk '{print $1}')
  if [[ -z "$ip" ]]; then
    echo -e "${RED}[!] Không thể lấy địa chỉ IP public của server.${NC}"
    return 1
  fi
  echo "$ip"
  return 0
}

generate_random_string() {
  local length="${1:-32}"
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

update_env_file() {
  local key="$1"
  local value="$2"
  if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${RED}Lỗi: File ${ENV_FILE} không tồn tại. Không thể cập nhật.${NC}"
    return 1
  fi
  if grep -q "^${key}=" "${ENV_FILE}"; then
    sudo sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" | sudo tee -a "${ENV_FILE}" > /dev/null
  fi
}

# --- Spinner (hiệu ứng loading) ---
_spinner() {
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis # ẩn con trỏ
    while true; do
        echo -n -e " ${CYAN}${spin_chars[$i]} $1 ${NC}\r"
        i=$(( (i+1) % ${#spin_chars[@]} ))
        sleep 0.1
    done
}

start_spinner() {
    local message="$1"
    if [[ $SPINNER_PID -ne 0 ]]; then
        stop_spinner
    fi
    _spinner "$message" &
    SPINNER_PID=$!
    trap "stop_spinner;" SIGINT SIGTERM
}

stop_spinner() {
    if [[ $SPINNER_PID -ne 0 ]]; then
        kill "$SPINNER_PID" &>/dev/null
        wait "$SPINNER_PID" &>/dev/null
        echo -n -e "\r\033[K" # xóa dòng spinner
        SPINNER_PID=0
    fi
    tput cnorm # hiện lại con trỏ
}

# Chạy lệnh ở chế độ im lặng, hiển thị spinner và log lỗi nếu thất bại
run_silent_command() {
  local message="$1"
  local command_to_run="$2"
  local log_file="/tmp/n8n_manager_cmd_$(date +%s%N).log"
  local show_explicit_processing_message="${3:-true}"

  if [[ "$show_explicit_processing_message" == "false" ]]; then
    if sudo bash -c "${command_to_run}" >> "${log_file}" 2>&1; then
      sudo rm -f "${log_file}"
      return 0
    else
      if [[ $SPINNER_PID -ne 0 ]]; then
          stop_spinner
      fi
      echo -e "\n${RED}Lỗi trong khi [${message}] (xử lý ngầm).${NC}"
      echo -e "${RED}Chi tiết lỗi đã được ghi vào: ${log_file}${NC}"
      echo -e "${RED}5 dòng cuối của log:${NC}"
      tail -n 5 "${log_file}" | sed 's/^/    /'
      return 1
    fi
  else
    if [[ $SPINNER_PID -ne 0 ]]; then
        stop_spinner
    fi

    echo -n -e "${CYAN}Xử lý: ${message}... ${NC}"

    if sudo bash -c "${command_to_run}" > "${log_file}" 2>&1; then
      echo -e "${GREEN}Xong.${NC}"
      sudo rm -f "${log_file}"
      return 0
    else
      echo -e "${RED}Thất bại.${NC}"
      echo -e "${RED}Chi tiết lỗi đã được ghi vào: ${log_file}${NC}"
      echo -e "${RED}5 dòng cuối của log:${NC}"
      tail -n 5 "${log_file}" | sed 's/^/    /'
      return 1
    fi
  fi
}
