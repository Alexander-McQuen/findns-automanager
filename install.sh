#!/bin/bash

# Preparation
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
    echo -e "${GREEN}    Findns Ultimate Auto-Manager (TG)     ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) ${CYAN}[FULL SETUP]${NC} Install & Build"
    echo -e "2) Set Scanner Config (Domain, Pubkey)"
    echo -e "3) Start Scanner (Background)"
    echo -e "4) View & Copy Found Results"
    echo -e "5) Stop Scanner"
    echo -e "6) Exit"
    echo -e "7) ${RED}[UNINSTALL]${NC} TOTAL Wipe-out"
    echo -e "8) ${YELLOW}[TELEGRAM]${NC} Setup Notifications"
    echo -e "9) ${BLUE}[PROGRESS]${NC} View Live Output"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select [1-9]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 6) exit 0 ;;
        7) uninstall_all ;; 8) setup_telegram ;; 9) view_progress ;;
        *) main_menu ;;
    esac
}

uninstall_all() {
    echo -e "${RED}!!! WARNING: This will remove EVERYTHING (App, Configs, Go, Tools) !!!${NC}"
    read -p "Are you absolutely sure? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        # توقف اسکنر
        screen -S findns_worker -X quit > /dev/null 2>&1
        # حذف تمام پوشه‌ها و فایل‌های مرتبط
        rm -rf ~/findns-work ~/go ~/.cache/go-build
        rm -f ~/.findns_config ~/.env ~/super_manager.sh
        # حذف پکیج‌های سیستم
        echo -e "${YELLOW}Removing system packages...${NC}"
        sudo apt purge golang-go git screen -y > /dev/null 2>&1
        sudo apt autoremove -y > /dev/null 2>&1
        echo -e "${GREEN}Server is clean. Like it was never here.${NC}"
        exit 0
    fi
    main_menu
}

# --- سایر توابع (بدون تغییر) ---
full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo
    git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}✔ Setup Done!${NC}"; sleep 2; main_menu
}

setup_config() {
    read -p "Domain: " input_domain
    DOMAIN=${input_domain:-$DOMAIN}
    read -p "Pubkey: " input_pubkey
    PUBKEY=${input_pubkey:-$PUBKEY}
    read -p "Workers (50): " input_workers
    WORKERS=${input_workers:-50}
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    main_menu
}

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    echo "DOMAIN=\"$DOMAIN\"" > .env
    echo "PUBKEY=\"$PUBKEY\"" >> .env
    echo "WORKERS=\"$WORKERS\"" >> .env
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> .env
    echo "TG_ID=\"$TG_ID\"" >> .env
    echo "RESULT_FILE=\"$RESULT_FILE\"" >> .env
    screen -dmS findns_worker bash -c '
        source .env
        while true; do
            old_count=$(wc -l < "$RESULT_FILE" 2>/dev/null || echo 0)
            ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json > temp_live.txt
            grep "OK" temp_live.txt | awk "{print \$2}" >> "$RESULT_FILE" 2>/dev/null
            sort -u "$RESULT_FILE" -o "$RESULT_FILE"
            new_count=$(wc -l < "$RESULT_FILE")
            if [ "$new_count" -gt "$old_count" ]; then
                new_ips=$(comm -13 <(sort temp_old.txt 2>/dev/null) <(sort "$RESULT_FILE"))
                [ -n "$TG_TOKEN" ] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New Resolvers Found:%0A$new_ips" > /dev/null
            fi
            cp "$RESULT_FILE" temp_old.txt
            sleep 10
        done
    '
    main_menu
}

view_results() {
    clear; [ -s "$RESULT_FILE" ] && cat "$RESULT_FILE" || echo "Empty."; read -p "Back..."; main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1; main_menu
}

view_progress() {
    screen -r findns_worker || main_menu
}

setup_telegram() {
    read -p "Bot Token: " TG_TOKEN
    read -p "Chat ID: " TG_ID
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Active"
    main_menu
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
