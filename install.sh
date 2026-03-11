#!/bin/bash
# Findns Ultimate Manager v4.0 - Anti Ctrl+C Edition

mkdir -p ~/findns-work && cd ~/findns-work

cat << 'EOF' > super_manager.sh
#!/bin/bash
CONFIG_FILE=".findns_config"
RESULT_FILE="valid_resolvers.txt"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Auto-Manager v4.0 (Anti-Kill)  ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) Full Setup (Install & Build)"
    echo -e "2) Set Config (Domain, Pubkey)"
    echo -e "3) Start Scanner (Background)"
    echo -e "4) View Found Results"
    echo -e "5) ${RED}Stop Scanner${NC}"
    echo -e "8) Telegram Setup"
    echo -e "9) ${YELLOW}View Progress (Safe to Ctrl+C)${NC}"
    echo -e "10) Check Current Settings"
    echo -e "7) Uninstall Everything"
    echo -e "6) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select [1-10]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 8) setup_telegram ;; 
        9) view_progress ;; 10) show_config ;; 7) uninstall_all ;; 
        6) exit 0 ;; *) main_menu ;;
    esac
}

start_scanner() {
    if [[ -z "$DOMAIN" || -z "$PUBKEY" ]]; then
        echo -e "${RED}Error: Setup config first!${NC}"; sleep 2; main_menu; return
    fi
    
    screen -S findns_worker -X quit > /dev/null 2>&1
    sleep 1

    # ایجاد اسکریپت داخلی که در برابر Ctrl+C مقاوم است
    cat << 'INNER_EOF' > worker.sh
#!/bin/bash
source .findns_config
# این خط باعث می‌شود اسکریپت سیگنال Ctrl+C را نادیده بگیرد
trap '' INT SIGINT SIGTERM

while true; do
    old_count=$(wc -l < "valid_resolvers.txt" 2>/dev/null || echo 0)
    
    # اجرای اسکنر (بدون هدایت خروجی به فایل تا نوار پیشرفت دیده شود)
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    
    if [ -f "current_found.json" ]; then
        grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json >> "valid_resolvers.txt"
        sort -u "valid_resolvers.txt" -o "valid_resolvers.txt"
        rm current_found.json
    fi
    
    new_count=$(wc -l < "valid_resolvers.txt")
    if [ "$new_count" -gt "$old_count" ]; then
        new_ips=$(comm -13 <(sort temp_old.txt 2>/dev/null) <(sort "valid_resolvers.txt"))
        if [ -n "$TG_TOKEN" ] && [ -n "$new_ips" ]; then
            curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New Resolvers Found:%0A$new_ips" > /dev/null
        fi
    fi
    cp "valid_resolvers.txt" temp_old.txt
    echo "Wait 10s for next round..."
    sleep 10
done
INNER_EOF
    chmod +x worker.sh

    # اجرای اسکریپت مقاوم در Screen
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner started! Now it is safe to use Option 9.${NC}"; sleep 2; main_menu
}

view_progress() {
    if screen -list | grep -q "findns_worker"; then
        echo -e "${YELLOW}Entering Scanner View...${NC}"
        echo -e "${GREEN}NOTE:${NC} Even if you press ${RED}Ctrl+C${NC}, the scanner will ${GREEN}STAY ALIVE${NC}."
        echo -e "To return to menu, press ${CYAN}Ctrl+C${NC} then run the manager again."
        sleep 3
        screen -r findns_worker
    else
        echo -e "${RED}Scanner is not running!${NC}"; sleep 2; main_menu
    fi
}

show_config() {
    clear
    echo -e "${YELLOW}--- Settings ---${NC}"
    echo -e "Domain: ${GREEN}${DOMAIN:-N/A}${NC}"
    echo -e "Pubkey: ${GREEN}${PUBKEY:-N/A}${NC}"
    echo -e "TG Chat: ${CYAN}${TG_ID:-N/A}${NC}"
    read -p "Press Enter..." ; main_menu
}

full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}✔ Done!${NC}"; sleep 2; main_menu
}

setup_config() {
    read -p "Domain: " DOMAIN; read -p "Pubkey: " PUBKEY; read -p "Workers (50): " WORKERS
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"${WORKERS:-50}\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    main_menu
}

view_results() {
    clear; cat "$RESULT_FILE" 2>/dev/null || echo "No results."; read -p "Enter..."; main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    pkill -f worker.sh
    echo -e "${RED}Scanner Stopped.${NC}"; sleep 2; main_menu
}

setup_telegram() {
    read -p "Token: " TG_TOKEN; read -p "Chat ID: " TG_ID
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Notification Active!"; main_menu
}

uninstall_all() {
    rm -rf ~/findns-work; screen -S findns_worker -X quit > /dev/null 2>&1; exit 0
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
