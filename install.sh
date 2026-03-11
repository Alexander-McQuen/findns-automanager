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

if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Ultimate Auto-Manager (TG)     ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) ${CYAN}[FULL SETUP]${NC} Install & Build"
    echo -e "2) Set Scanner Config (Domain, Pubkey)"
    echo -e "3) Start Scanner (Background)"
    echo -e "4) View & Copy Found Results (File)"
    echo -e "5) Stop Scanner"
    echo -e "6) Exit"
    echo -e "7) ${RED}[UNINSTALL]${NC} Remove Everything"
    echo -e "8) ${YELLOW}[TELEGRAM]${NC} Setup Notifications"
    echo -e "9) ${BLUE}[PROGRESS]${NC} View Live Scanner Output"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select option [1-9]: " choice
    case $choice in
        1) full_setup ;;
        2) setup_config ;;
        3) start_scanner ;;
        4) view_results ;;
        5) stop_scanner ;;
        6) exit 0 ;;
        7) uninstall_all ;;
        8) setup_telegram ;;
        9) view_progress ;;
        *) main_menu ;;
    esac
}

view_progress() {
    if screen -list | grep -q "findns_worker"; then
        echo -e "${YELLOW}Attaching to scanner session...${NC}"
        echo -e "${RED}IMPORTANT:${NC} Press ${GREEN}CTRL + A${NC} then ${GREEN}D${NC} to exit progress view."
        echo -e "Wait 3 seconds..."
        sleep 3
        screen -r findns_worker
    else
        echo -e "${RED}Scanner is not running! Start it first (Option 3).${NC}"
        sleep 2
        main_menu
    fi
}

full_setup() {
    echo -e "${YELLOW}Installing...${NC}"
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo
    git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}✔ Setup Completed!${NC}"; sleep 2; main_menu
}

setup_config() {
    echo -e "\n${YELLOW}--- Config ---${NC}"
    read -p "Domain: " input_domain
    DOMAIN=${input_domain:-$DOMAIN}
    read -p "Public Key: " input_pubkey
    PUBKEY=${input_pubkey:-$PUBKEY}
    read -p "Workers (50): " input_workers
    WORKERS=${input_workers:-50}
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    echo -e "${GREEN}Saved!${NC}"; sleep 1; main_menu
}

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    screen -dmS findns_worker bash -c '
        source .findns_config
        while true; do
            old_count=$(wc -l < "$RESULT_FILE" 2>/dev/null || echo 0)
            ./findns-repo/findns e2e dnstt --domain $DOMAIN --pubkey $PUBKEY --workers $WORKERS -i ./findns-repo/ir-resolvers.txt > temp_res.txt
            cat temp_res.txt >> "$RESULT_FILE"
            sort -u "$RESULT_FILE" -o "$RESULT_FILE"
            new_count=$(wc -l < "$RESULT_FILE")
            if [ "$new_count" -gt "$old_count" ]; then
                new_ips=$(comm -13 <(sort temp_old_results.txt 2>/dev/null) <(sort "$RESULT_FILE"))
                curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New Resolvers Found:%0A$new_ips" > /dev/null
            fi
            cp "$RESULT_FILE" temp_old_results.txt
            sleep 10
        done
    '
    echo -e "${GREEN}Scanner started! Use Option 9 to see live progress.${NC}"; sleep 2; main_menu
}

# (سایر توابع مثل قبل باقی می‌مانند...)
view_results() {
    clear
    [ -s "$RESULT_FILE" ] && cat "$RESULT_FILE" || echo "No results yet."
    read -p "Press Enter to back..."
    main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    echo -e "${RED}Stopped.${NC}"; sleep 2; main_menu
}

uninstall_all() {
    read -p "Are you sure? (y/n): " confirm
    [[ $confirm == [yY] ]] && rm -rf ~/findns-work && screen -S findns_worker -X quit && exit 0
    main_menu
}

setup_telegram() {
    read -p "Bot Token: " TG_TOKEN
    read -p "Chat ID: " TG_ID
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Notification Active"
    main_menu
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
