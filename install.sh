#!/bin/bash

# install.sh — Cài đặt công cụ N8N Host lên hệ thống

# --- Định nghĩa màu sắc và biến ---
RED='\e[38;5;217m'      # hồng nhạt
GREEN='\e[38;5;151m'    # xanh lá nhạt
YELLOW='\e[38;5;229m'   # vàng nhạt
CYAN='\e[38;5;159m'     # xanh dương nhạt
NC='\e[0m'              # reset màu

# !!! THAY ĐỔI URL NÀY THÀNH LINK TẢI SCRIPT CỦA BẠN !!!
SCRIPT_URL="https://raw.githubusercontent.com/NCHQ02/n8n-script-2026/main/dist/n8n-host.sh"

SCRIPT_NAME="n8n-host"
INSTALL_DIR="/usr/local/bin"          # Khuyến nghị dùng /usr/local/bin cho script tùy chỉnh
INSTALL_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
TEMP_SCRIPT="/tmp/${SCRIPT_NAME}.sh.$$"           # File tạm với PID để tránh xung đột
TEMPLATE_FILE_NAME="import-workflow-credentials.json"

# --- Kiểm tra quyền root ---
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "\n${RED}[!] Lỗi: Bạn cần chạy script cài đặt này với quyền root (sudo).${NC}\n"
    exit 1
  fi
}

# --- Phát hiện công cụ tải file (curl hoặc wget) ---
check_downloader() {
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
    elif command -v wget &> /dev/null; then
        DOWNLOADER="wget"
    else
        echo -e "${RED}[!] Lỗi: Không tìm thấy 'curl' hoặc 'wget'. Vui lòng cài đặt một trong hai công cụ này.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[*] Sử dụng '$DOWNLOADER' để tải file.${NC}"
}

# --- Tải script về file tạm ---
download_script() {
    echo -e "${YELLOW}[*] Đang tải script từ: ${SCRIPT_URL}${NC}"
    local download_status
    if [[ "$DOWNLOADER" == "curl" ]]; then
        # Tải file bằng curl: theo dõi redirect (-L), báo lỗi nếu fail (-f), im lặng (-s)
        curl -fsSL -o "$TEMP_SCRIPT" "$SCRIPT_URL"
        download_status=$?
    else # wget
        # Tải file bằng wget: output vào file tạm (-O), im lặng (-q)
        wget -qO "$TEMP_SCRIPT" "$SCRIPT_URL"
        download_status=$?
    fi

    if [[ $download_status -ne 0 ]]; then
        echo -e "${RED}[!] Lỗi: Tải script thất bại (kiểm tra URL hoặc kết nối mạng).${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 1
    fi

    # Kiểm tra xem file tải về có nội dung không
    if [[ ! -s "$TEMP_SCRIPT" ]]; then
        echo -e "${RED}[!] Lỗi: File tải về rỗng (kiểm tra URL).${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 1
    fi

    echo -e "${GREEN}[+] Tải script thành công.${NC}"
}

# --- Cài đặt script và template ---
install_script() {
    echo -e "${YELLOW}[*] Bắt đầu quá trình cài đặt...${NC}"

    check_root
    check_downloader
    download_script

    # Tạo thư mục cài đặt nếu chưa có
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}[*] Tạo thư mục cài đặt: ${INSTALL_DIR}${NC}"
        if ! sudo mkdir -p "$INSTALL_DIR"; then
            echo -e "${RED}[!] Lỗi: Không thể tạo thư mục ${INSTALL_DIR}.${NC}"
            rm -f "$TEMP_SCRIPT"
            exit 1
        fi
    fi

    # Di chuyển script vào thư mục cài đặt
    echo -e "${YELLOW}[*] Di chuyển script đến: ${INSTALL_PATH}${NC}"
    if ! sudo mv "$TEMP_SCRIPT" "$INSTALL_PATH"; then
        echo -e "${RED}[!] Lỗi: Không thể di chuyển script đến ${INSTALL_PATH}.${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 1
    fi

    # Cấp quyền thực thi
    echo -e "${YELLOW}[*] Cấp quyền thực thi cho script...${NC}"
    if ! sudo chmod +x "$INSTALL_PATH"; then
        echo -e "${RED}[!] Lỗi: Không thể cấp quyền thực thi cho ${INSTALL_PATH}.${NC}"
        exit 1
    fi

    # Tải file template về /n8n-templates/
    echo -e "${YELLOW}[*] Tạo thư mục /n8n-templates/...${NC}"
    if [[ ! -d "/n8n-templates" ]]; then
        sudo mkdir -p "/n8n-templates"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}[!] Lỗi: Không thể tạo thư mục /n8n-templates.${NC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}[*] Tải về file template...${NC}"
    local template_url="https://cloudfly.vn/download/n8n-host/templates/${TEMPLATE_FILE_NAME}"
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL -o "/n8n-templates/${TEMPLATE_FILE_NAME}" "$template_url"
    else
        wget -qO "/n8n-templates/${TEMPLATE_FILE_NAME}" "$template_url"
    fi
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] Lỗi: Không thể tải về file template.${NC}"
        exit 1
    fi

    # Xác nhận cài đặt thành công
    if [[ -f "$INSTALL_PATH" && -x "$INSTALL_PATH" ]]; then
        echo -e "\n${GREEN}[+++] Cài đặt thành công!${NC}"
        echo -e "Bạn có thể chạy công cụ bằng lệnh: ${CYAN}${SCRIPT_NAME}${NC}"
        echo -e "Để gỡ bỏ, chạy lệnh: ${CYAN}${SCRIPT_NAME} --uninstall${NC}"
    else
        echo -e "\n${RED}[!] Cài đặt thất bại. Không tìm thấy file thực thi tại ${INSTALL_PATH}.${NC}"
        exit 1
    fi
}

# Xử lý tham số --force-install (cài đè nếu đã tồn tại)
if [[ "$1" == "--force-install" ]]; then
    echo -e "${YELLOW}[*] Chế độ cài đặt bắt buộc (force). Ghi đè nếu đã tồn tại.${NC}"
    install_script
    exit 0
fi

# Kiểm tra xem script đã được cài đặt chưa
if [[ -f "$INSTALL_PATH" ]]; then
    echo -e "${YELLOW}[!] Công cụ '${SCRIPT_NAME}' đã được đặt tại '${INSTALL_PATH}'.${NC}"
    echo -e "Nếu bạn muốn cài đặt lại, hãy chạy: ${CYAN}bash $0 --force-install${NC}"
    echo -e "Nếu bạn muốn gỡ bỏ, hãy chạy: ${CYAN}${SCRIPT_NAME} --uninstall${NC}"
    exit 1
else
    install_script
fi

exit 0
