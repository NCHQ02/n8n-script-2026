# --- Dọn dẹp Hệ thống (System Cleanup) ---

# Dọn dẹp rác Docker
docker_prune() {
  clear
  echo -e "${CYAN}=== DỌN DẸP HỆ THỐNG (DOCKER) ===${NC}"
  echo -e "${YELLOW}[!] Tính năng này sẽ dọn dẹp không gian ổ đĩa bằng cách xóa:${NC}"
  echo "- Tất cả Docker container đã dừng lại."
  echo "- Tất cả Networks không được sử dụng bởi ít nhất 1 container."
  echo "- Tất cả Docker Images lủng lẳng (dangling) không có thẻ tên."
  echo "- Tất cả Build Cache không được sử dụng."
  echo ""
  echo -e "${RED}Lưu ý: Dữ liệu N8N của bạn sẽ không bị ảnh hưởng (vì chúng nằm trong Volume).${NC}"
  echo ""
  
  read -p "Bạn có muốn tiếp tục dọn dẹp hệ thống không? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Đã hủy thao tác."
    sleep 1
    return 0
  fi

  # Chạy lệnh
  run_silent_command "Đang dọn dẹp Docker system" "docker system prune -a -f --volumes" false
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Đã dọn dẹp hệ thống thành công!${NC}"
    
    # Check current disk space
    echo -e "\n${YELLOW}Tình trạng ổ cứng hiện tại:${NC}"
    df -h / | tail -n 1 | awk '{print "Tổng: " $2 "\nĐã dùng: " $3 " (" $5 ")\nCòn trống: " $4}'
  fi
  
  echo ""
  read -n 1 -s -r -p "Nhấn phím bất kỳ để quay lại menu..."
}
