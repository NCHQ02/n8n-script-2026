#!/bin/bash

# install.sh - Cài đặt công cụ N8N Host

# --- Định nghĩa màu sắc và biến ---
RED='\e[38;5;217m'      # pastel pink
GREEN='\e[38;5;151m'    # pastel green
YELLOW='\e[38;5;229m'   # pastel yellow
CYAN='\e[38;5;159m'     # pastel blue
NC='\e[0m'              # reset
# !!! THAY ĐỔI URL NÀY THÀNH LINK TẢI SCRIPT CỦA BẠN !!!
SCRIPT_URL="https://raw.githubusercontent.com/NCHQ02/n8n-panel/main/n8n-host.sh" # VI DU: Link raw GitHub

SCRIPT_NAME="n8n-host" #path/to/script/name
# Khuyến nghị dùng /usr/local/bin cho script tùy chỉnh
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
TEMP_SCRIPT="/tmp/${SCRIPT_NAME}.sh.$$" 
TEMPLATE_FILE_NAME="import-workflow-credentials.json" 

# --- Hàm kiểm tra quyền root ---
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "\n${RED}[!] Lỗi: Bạn cần chạy script cài đặt này với quyền root (sudo).${NC}\n"
    exit 1
  fi
}

# --- Hàm kiểm tra lệnh (curl hoặc wget) ---
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

# --- Hàm tải script ---
download_script() {
    echo -e "${YELLOW}[*] Đang tải script từ: ${SCRIPT_URL}${NC}"
    if [[ "$DOWNLOADER" == "curl" ]]; then
        # Tải file bằng curl, theo dõi redirect (-L), báo lỗi nếu fail (-f), im lặng (-s), output vào file tạm (-o)
        curl -fsSL -o "$TEMP_SCRIPT" "$SCRIPT_URL"
        local download_status=$?
    else # wget
        # Tải file bằng wget, output vào file tạm (-O), im lặng (-q)
        wget -qO "$TEMP_SCRIPT" "$SCRIPT_URL"
        local download_status=$?
    fi

    if [[ $download_status -ne 0 ]]; then
        echo -e "${RED}[!] Lỗi: Tải script thất bại (kiểm tra URL hoặc kết nối mạng).${NC}"
        rm -f "$TEMP_SCRIPT" # Xóa file tạm nếu có lỗi
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

# --- Hàm cài đặt ---
install_script() {
    echo -e "${YELLOW}[*] Bắt đầu quá trình cài đặt...${NC}"

    # 1. Kiểm tra quyền root
    check_root

    # 2. Kiểm tra công cụ tải file
    check_downloader

    # 3. Tải script vào file tạm
    download_script

    # 4. Tạo thư mục cài đặt nếu chưa có
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}[*] Tạo thư mục cài đặt: ${INSTALL_DIR}${NC}"
        # Sử dụng sudo vì tạo thư mục trong hệ thống
        if ! sudo mkdir -p "$INSTALL_DIR"; then
            echo -e "${RED}[!] Lỗi: Không thể tạo thư mục ${INSTALL_DIR}.${NC}"
            rm -f "$TEMP_SCRIPT"
            exit 1
        fi
    fi

    # 5. Di chuyển script vào thư mục cài đặt
    echo -e "${YELLOW}[*] Di chuyển script đến: ${INSTALL_PATH}${NC}"
    if ! sudo mv "$TEMP_SCRIPT" "$INSTALL_PATH"; then
        echo -e "${RED}[!] Lỗi: Không thể di chuyển script đến ${INSTALL_PATH}.${NC}"
        rm -f "$TEMP_SCRIPT" # Vẫn cố gắng xóa file tam
        exit 1
    fi

    # 6. Cấp quyền thực thi cho script
    echo -e "${YELLOW}[*] Cấp quyền thực thi cho script...${NC}"
    if ! sudo chmod +x "$INSTALL_PATH"; then
        echo -e "${RED}[!] Lỗi: Không thể cấp quyền thực thi cho ${INSTALL_PATH}.${NC}"
        # Co the can go bo file da copy neu khong cap quyen duoc? Tuy chon.
        # sudo rm -f "$INSTALL_PATH"
        exit 1
    fi

    # 7. Tạo thư mục n8n-templates ngang hàng với root và tải về file template
    echo -e "${YELLOW}[*] Tạo thư mục n8n-templates...${NC}"
    if [[ ! -d "/n8n-templates" ]]; then
        sudo mkdir -p "/n8n-templates"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}[!] Lỗi: Không thể tạo thư mục /n8n-templates.${NC}"
            exit 1
        fi
    fi
    echo -e "${YELLOW}[*] Tải về file template...${NC}"

    curl -fsSL -o "/n8n-templates/${TEMPLATE_FILE_NAME}" "https://cloudfly.vn/download/n8n-host/templates/${TEMPLATE_FILE_NAME}"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] Lỗi: Không thể tải về file template.${NC}"
        exit 1
    fi
    
    # 8. Kiểm tra lại
    if [[ -f "$INSTALL_PATH" && -x "$INSTALL_PATH" ]]; then
        echo -e "\n${GREEN}[+++] Cài đặt thành công! ${NC}"
        echo -e "Bạn có thể chạy công cụ bằng lệnh: ${CYAN}${SCRIPT_NAME}${NC}"
        echo -e "Để gỡ bỏ, chạy lệnh: ${CYAN}${SCRIPT_NAME} --uninstall${NC}"
    else
        echo -e "\n${RED}[!] Cài đặt thất bại. Không tìm thấy file thực thi tại ${INSTALL_PATH}.${NC}"
        exit 1
    fi
}

# Kiểm tra xem script đã được cài đặt chưa
if [[ -f "$INSTALL_PATH" ]]; then
    echo -e "${YELLOW}[!] Công cụ '${SCRIPT_NAME}' được đặt tại '${INSTALL_PATH}'.${NC}"
    echo -e "Nếu bạn muốn cài đặt lại, hãy chạy: ${CYAN}bash $0 --force-install${NC}"
    echo -e "Nếu bạn muốn gỡ bỏ, hãy chạy: ${CYAN}${SCRIPT_NAME} --uninstall${NC}"
    exit 1
else
    # Nếu chưa cài đặt, tiến hành cài đặt
    install_script
fi

exit 0
