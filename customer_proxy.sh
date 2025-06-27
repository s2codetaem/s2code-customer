#!/bin/bash

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Telegram Bot (để thông báo cho admin)
BOT_TOKEN="7562309524:AAHCxitura1Yptb-7-dX9YEMbNLIFbOp_lk"
BOT_CHAT_ID="6072481570"
BOT_API="https://api.telegram.org/bot$BOT_TOKEN"

# File database
CUSTOMERS_FILE="/etc/s2code/customers.txt"
LICENSES_FILE="/etc/s2code/licenses.txt"

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}                        🚀 S2CODE PROXY SERVICE 🚀                           ${CYAN}║${NC}"
echo -e "${CYAN}║${WHITE}                           by TẠ NGỌC LONG - S2CODE                          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Hàm gửi Telegram
send_telegram() {
    local message="$1"
    curl -s -X POST "$BOT_API/sendMessage" \
        -d "chat_id=$BOT_CHAT_ID" \
        -d "text=$message" \
        -d "parse_mode=Markdown" >/dev/null 2>&1
}

echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${RED}                            🔐 ĐĂNG NHẬP KHÁCH HÀNG 🔐                       ${YELLOW}║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Đăng nhập
echo -e "${PURPLE}👤 Username:${NC} "
read -r username

echo -e "${PURPLE}🔒 Password:${NC} "
read -s password
echo ""

echo -e "${PURPLE}🗝️  License Key:${NC} "
read -r license_key
echo ""

echo -e "${CYAN}🔍 Đang xác thực...${NC}"

# Kiểm tra file database
if [ ! -f "$CUSTOMERS_FILE" ] || [ ! -f "$LICENSES_FILE" ]; then
    echo -e "${RED}❌ Hệ thống chưa sẵn sàng!${NC}"
    echo -e "${YELLOW}📞 Liên hệ: 08.77.79.71.75${NC}"
    exit 1
fi

# Xác thực
customer_check=$(grep "|$username|$password|" "$CUSTOMERS_FILE" 2>/dev/null)
license_check=$(grep "^$license_key|$username|" "$LICENSES_FILE" 2>/dev/null)

if [ -n "$customer_check" ] && [ -n "$license_check" ]; then
    # Lấy thông tin
    customer_name=$(echo "$customer_check" | cut -d'|' -f1)
    expiry_date=$(echo "$license_check" | cut -d'|' -f3)
    remaining_uses=$(echo "$license_check" | cut -d'|' -f5)
    
    # Kiểm tra hết hạn
    current_time=$(date +%s)
    expiry_time=$(date -d "$expiry_date" +%s 2>/dev/null)
    
    if [ "$current_time" -gt "$expiry_time" ]; then
        echo -e "${RED}❌ License đã hết hạn!${NC}"
        echo -e "${YELLOW}📞 Liên hệ gia hạn: 08.77.79.71.75${NC}"
        exit 1
    fi
    
    if [ "$remaining_uses" -le 0 ]; then
        echo -e "${RED}❌ Hết lượt tạo proxy!${NC}"
        echo -e "${YELLOW}📞 Liên hệ nạp thêm: 08.77.79.71.75${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Xác thực thành công! Chào $customer_name${NC}"
    echo -e "${GREEN}🎯 Còn lại: $remaining_uses lượt${NC}"
    echo ""
    
    # Giảm lượt sử dụng
    new_remaining=$((remaining_uses - 1))
    temp_file="/tmp/licenses_update.txt"
    while IFS='|' read -r key user expiry total current; do
        if [ "$key" = "$license_key" ] && [ "$user" = "$username" ]; then
            echo "$key|$user|$expiry|$total|$new_remaining"
        else
            echo "$key|$user|$expiry|$total|$current"
        fi
    done < "$LICENSES_FILE" > "$temp_file"
    sudo mv "$temp_file" "$LICENSES_FILE"
    
    echo -e "${BLUE}🚀 Bắt đầu tạo proxy...${NC}"
    
    # Cài đặt Squid
    echo -e "${BLUE}[1/5]${NC} ${WHITE}Cập nhật hệ thống...${NC}"
    sudo apt update -y >/dev/null 2>&1
    
    echo -e "${BLUE}[2/5]${NC} ${WHITE}Cài đặt Squid...${NC}"
    sudo apt install -y squid apache2-utils curl >/dev/null 2>&1
    
    echo -e "${BLUE}[3/5]${NC} ${WHITE}Cấu hình proxy...${NC}"
    sudo rm -f /etc/squid/squid.conf
    
    # Cấu hình Squid
    sudo tee /etc/squid/squid.conf >/dev/null <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_port 6969
EOF
    
    echo -e "${BLUE}[4/5]${NC} ${WHITE}Tạo tài khoản...${NC}"
    echo "1" | sudo htpasswd -ci /etc/squid/passwords s2codetaem
    
    echo -e "${BLUE}[5/5]${NC} ${WHITE}Khởi động dịch vụ...${NC}"
    sudo systemctl restart squid
    sudo systemctl enable squid >/dev/null 2>&1
    
    # Lấy IP
    IP=$(curl -s ipinfo.io/ip)
    PROXY_URL="http://s2codetaem:1@$IP:6969"
    
    sleep 3
    
    # Kiểm tra hoạt động
    if nc -z "$IP" 6969 2>/dev/null; then
        # THÀNH CÔNG
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${WHITE}                        🎉 TẠO PROXY THÀNH CÔNG! 🎉                          ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}🔗 PROXY URL: ${BOLD}$PROXY_URL${NC}"
        echo -e "${YELLOW}🌐 IP: ${GREEN}$IP${NC}"
        echo -e "${YELLOW}🔌 Port: ${GREEN}6969${NC}"
        echo -e "${YELLOW}👤 User: ${GREEN}s2codetaem${NC}"
        echo -e "${YELLOW}🔒 Pass: ${GREEN}1${NC}"
        echo -e "${YELLOW}🎯 Còn lại: ${BLUE}$new_remaining lượt${NC}"
        
        # Thông báo Telegram cho admin
        telegram_msg="🔥 **KHÁCH HÀNG TẠO PROXY**

👤 **User:** $username ($customer_name)
🗝️ **License:** $license_key
🔗 **Proxy:** \`$PROXY_URL\`
🌐 **IP:** $IP
🎯 **Còn lại:** $new_remaining lượt
⏰ **Time:** $(date '+%d/%m/%Y %H:%M:%S')

💰 **Revenue!**"
        
        send_telegram "$telegram_msg"
        
    else
        # LỖI
        echo -e "${RED}❌ Tạo proxy thất bại!${NC}"
        echo -e "${YELLOW}📞 Liên hệ hỗ trợ: 08.77.79.71.75${NC}"
        
        # Hoàn lại lượt
        temp_file="/tmp/licenses_restore.txt"
        while IFS='|' read -r key user expiry total current; do
            if [ "$key" = "$license_key" ] && [ "$user" = "$username" ]; then
                echo "$key|$user|$expiry|$total|$remaining_uses"
            else
                echo "$key|$user|$expiry|$total|$current"
            fi
        done < "$LICENSES_FILE" > "$temp_file"
        sudo mv "$temp_file" "$LICENSES_FILE"
        
        # Thông báo lỗi
        send_telegram "❌ **PROXY ERROR**
👤 User: $username
🚨 Error: Proxy creation failed
⏰ $(date '+%d/%m/%Y %H:%M:%S')"
    fi
    
else
    echo -e "${RED}❌ Thông tin đăng nhập sai!${NC}"
    echo -e "${YELLOW}📞 Hỗ trợ: 08.77.79.71.75${NC}"
    echo -e "${YELLOW}📨 Telegram: @S2codetaem48${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}                       ${YELLOW}📞 HỖ TRỢ S2CODE${NC}                                 ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} ${WHITE}👨‍💻 TẠ NGỌC LONG${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC} ${WHITE}📱 08.77.79.71.75${NC}                                                   ${GREEN}║${NC}"
echo -e "${GREEN}║${NC} ${WHITE}📨 @S2codetaem48${NC}                                                   ${GREEN}║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
