#!/bin/bash
# Findns Auto-Manager v4.5 - Telegram Debug Edition

mkdir -p ~/findns-work && cd ~/findns-work

cat << 'EOF' > super_manager.sh
#!/bin/bash
CONFIG_FILE=".findns_config"
RESULT_FILE="valid_resolvers.txt"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Auto-Manager v4.5 (Debug TG)   ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) Full Setup"
    echo -e "2) Set Scanner Config"
    echo -e "3) Start Scanner"
    echo -e "4) View Results"
    echo -e "5) Stop Scanner"
    echo -e "8) Telegram Setup"
    echo -e "11) ${YELLOW}[TEST]${NC} Send Test Message to TG"
    echo -e "9) View Progress"
    echo -e "10) Check Current Settings"
    echo -e "7) Uninstall"
    echo -e "6) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select [1-11]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 8) setup_telegram ;; 
        11) test_tg ;; 9) view_progress ;; 10) show_config ;; 
        7) uninstall_all ;; 6) exit 0 ;; *) main_menu ;;
    esac
}

test_tg() {
    echo -e "${YELLOW}Sending test message to Telegram...${NC}"
    if [[ -z "$TG_TOKEN" || -z "$TG_ID" ]]; then
        echo -e "${RED}Error: Telegram not set!${NC}"; sleep 2; main_menu; return
    fi
    # تست مستقیم با نمایش خطا
    curl -v -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Test from Server: $(date)"
    echo -e "\n${GREEN}Check your Telegram!${NC}"; sleep 3; main_menu
}

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    # ایجاد اسکریپت کارگر جدید با سیستم اطلاع‌رسانی قوی‌تر
    cat << 'INNER_EOF' > worker.sh
#!/bin/bash
# لود مجدد تنظیمات در هر چرخه
trap '' INT SIGINT SIGTERM
while true; do
    source .findns_config
    old_count=$(wc -l < "valid_resolvers.txt" 2>/dev/null || echo 0)
    
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    
    # استخراج آی‌پی (روش جدید و ساده‌تر)
    if [ -f "current_found.json" ]; then
        grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json >> "valid_resolvers.txt"
        sort -u "valid_resolvers.txt" -o "valid_resolvers.txt"
        rm current_found.json
    fi
    
    new_count=$(wc -l < "valid_resolvers.txt")
    if [ "$new_count" -gt "$old_count" ]; then
        # استخراج دقیق آی‌پی‌های جدید
        new_ips=$(comm -13 <(sort temp_old.txt 2>/dev/null) <(sort "valid_resolvers.txt"))
        if [[ -n "$TG_TOKEN" && -n "$new_ips" ]]; then
            # ارسال تکی برای اطمینان
            echo "$new_ips" | while read -r ip; do
                curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 Found: $ip"
            done
        fi
    fi
    cp "valid_resolvers.txt" temp_old.txt
    sleep 10
done
INNER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner restarted with better notifications!${NC}"; sleep 2; main_menu
}

# (سایر توابع مثل قبل...)
full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}✔ Done!${NC}"; sleep 2; main_menu
}

setup_config() {
    read -p "Domain: " DOMAIN; read -p "Pubkey: " PUBKEY; read -p "Workers: " WORKERS
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"${WORKERS:-50}\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    main_menu
}

show_config() {
    clear; echo -e "Token: $TG_TOKEN\nID: $TG_ID\nDomain: $DOMAIN"; read -p "Enter..."; main_menu
}

view_results() {
    clear; cat "$RESULT_FILE" 2>/dev/null || echo "No results."; read -p "Enter..."; main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1; pkill -f worker.sh; sleep 2; main_menu
}

view_progress() {
    screen -r findns_worker || main_menu
}

setup_telegram() {
    read -p "Token: " TG_TOKEN; read -p "Chat ID: " TG_ID
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ System Active!"; main_menu
}

uninstall_all() {
    rm -rf ~/findns-work; screen -S findns_worker -X quit > /dev/null 2>&1; exit 0
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
