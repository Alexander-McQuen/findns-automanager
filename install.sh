#!/bin/bash
# Findns Ultimate Manager - Alex Edition

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
    echo -e "${GREEN}    Findns Auto-Manager (Alex Edition)    ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) Full Setup (Install & Build)"
    echo -e "2) Set Config (Domain, Pubkey)"
    echo -e "3) Start Scanner (Background)"
    echo -e "4) View Found Results (File)"
    echo -e "5) Stop Scanner"
    echo -e "8) Telegram Setup"
    echo -e "9) ${YELLOW}Safe Dashboard (Ctrl+C is Safe here)${NC}"
    echo -e "7) Uninstall Everything"
    echo -e "6) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select [1-9]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 8) setup_telegram ;; 
        9) safe_dashboard ;; 7) uninstall_all ;; 6) exit 0 ;; *) main_menu ;;
    esac
}

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    # ذخیره تنظیمات در فایل محیطی برای جلوگیری از خطای No such file
    cat << ENV_EOF > .env
DOMAIN="$DOMAIN"
PUBKEY="$PUBKEY"
WORKERS="$WORKERS"
TG_TOKEN="$TG_TOKEN"
TG_ID="$TG_ID"
RESULT_FILE="$RESULT_FILE"
ENV_EOF

    screen -dmS findns_worker bash -c '
        source .env
        while true; do
            old_count=$(wc -l < "$RESULT_FILE" 2>/dev/null || echo 0)
            # اجرای اسکنر و هدایت خروجی به فایل برای نمایش در داشبورد
            ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json > temp_live.log 2>&1
            
            # استخراج نتایج
            grep "OK" temp_live.log | awk "{print \$2}" >> "$RESULT_FILE"
            sort -u "$RESULT_FILE" -o "$RESULT_FILE"
            
            new_count=$(wc -l < "$RESULT_FILE")
            if [ "$new_count" -gt "$old_count" ]; then
                new_ips=$(comm -13 <(sort temp_old.txt 2>/dev/null) <(sort "$RESULT_FILE"))
                [ -n "$TG_TOKEN" ] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New Resolvers:%0A$new_ips" > /dev/null
            fi
            cp "$RESULT_FILE" temp_old.txt
            sleep 5
        done
    '
    echo -e "${GREEN}Scanner is running in background!${NC}"; sleep 2; main_menu
}

safe_dashboard() {
    clear
    echo -e "${YELLOW}Entering Safe Dashboard...${NC}"
    echo -e "${RED}Press Ctrl+C anytime to return to Menu. Scanner will NOT stop.${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    sleep 2
    # نمایش زنده فایل لاگ
    tail -f temp_live.log
    main_menu
}

# (سایر توابع سیستمی مثل قبل...)
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
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    main_menu
}

view_results() {
    clear; cat "$RESULT_FILE" 2>/dev/null || echo "Empty."; read -p "Back..."; main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1; echo "Stopped."; sleep 2; main_menu
}

setup_telegram() {
    read -p "Token: " TG_TOKEN; read -p "Chat ID: " TG_ID
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Active"; main_menu
}

uninstall_all() {
    rm -rf ~/findns-work; screen -S findns_worker -X quit > /dev/null 2>&1; exit 0
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
