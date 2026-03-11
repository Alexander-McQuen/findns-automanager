#!/bin/bash
# Findns Ultimate Manager v6.0 - Alex Pro Edition

mkdir -p ~/findns-work && cd ~/findns-work

cat << 'EOF' > super_manager.sh
#!/bin/bash
# --- Configuration & Colors ---
CONFIG_FILE=".findns_config"
RESULT_FILE="valid_resolvers.txt"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to Load Data Safely
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}
load_config

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Ultimate Manager v6.0 (Pro)    ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) ${CYAN}[SETUP]${NC} Install & Build System"
    echo -e "2) ${CYAN}[CONFIG]${NC} Set Scanner (Domain/Pubkey)"
    echo -e "3) ${GREEN}[START]${NC} Run Scanner in Background"
    echo -e "4) ${GREEN}[VIEW]${NC} List Found Resolvers"
    echo -e "5) ${RED}[STOP]${NC} Kill Scanner Session"
    echo -e "------------------------------------------"
    echo -e "8) ${YELLOW}[TG]${NC} Setup Telegram Bot"
    echo -e "9) ${YELLOW}[PROGRESS]${NC} Visual Progress Bar (Live)"
    echo -e "10) ${YELLOW}[CHECK]${NC} Show All Current Settings"
    echo -e "11) ${YELLOW}[TEST]${NC} Send Test Msg to Telegram"
    echo -e "------------------------------------------"
    echo -e "7) Uninstall Everything"
    echo -e "6) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select option [1-11]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 8) setup_telegram ;; 
        9) view_progress ;; 10) show_config ;; 11) test_tg ;;
        7) uninstall_all ;; 6) exit 0 ;; *) main_menu ;;
    esac
}

show_config() {
    clear
    load_config
    echo -e "${YELLOW}>>> Current System Configuration <<<${NC}"
    echo -e "------------------------------------"
    echo -e "Scanner Domain:  ${CYAN}${DOMAIN:-[EMPTY]}${NC}"
    echo -e "Public Key:      ${CYAN}${PUBKEY:-[EMPTY]}${NC}"
    echo -e "Workers Count:   ${CYAN}${WORKERS:-50}${NC}"
    echo -e "------------------------------------"
    echo -e "Telegram Token:  ${CYAN}${TG_TOKEN:-[EMPTY]}${NC}"
    echo -e "Telegram ID:     ${CYAN}${TG_ID:-[EMPTY]}${NC}"
    echo -e "------------------------------------"
    read -p "Press Enter to return..."
    main_menu
}

setup_config() {
    echo -e "\n${YELLOW}--- Enter Scanner Settings ---${NC}"
    read -p "Domain (e.g. t.iranmotor.biz): " input_domain
    DOMAIN=${input_domain:-$DOMAIN}
    read -p "Public Key: " input_pubkey
    PUBKEY=${input_pubkey:-$PUBKEY}
    read -p "Workers (Default 50): " input_workers
    WORKERS=${input_workers:-50}
    
    # Save precisely
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    
    echo -e "${GREEN}Scanner settings saved!${NC}"
    sleep 2; main_menu
}

setup_telegram() {
    echo -e "\n${YELLOW}--- Enter Telegram Settings ---${NC}"
    read -p "Bot Token: " input_token
    TG_TOKEN=${input_token:-$TG_TOKEN}
    read -p "Chat ID: " input_id
    TG_ID=${input_id:-$TG_ID}

    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"

    echo -e "${GREEN}Telegram settings saved! Sending test...${NC}"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Telegram Linked to Alex Manager" > /dev/null
    sleep 2; main_menu
}

start_scanner() {
    load_config
    if [[ -z "$DOMAIN" || -z "$PUBKEY" ]]; then
        echo -e "${RED}Error: Complete settings (Option 2) first!${NC}"; sleep 2; main_menu; return
    fi
    
    screen -S findns_worker -X quit > /dev/null 2>&1
    sleep 1

    # Create a robust worker script
    cat << 'WORKER_EOF' > worker.sh
#!/bin/bash
while true; do
    source .findns_config
    # Run scanner and catch results
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    
    # Extract IPs from JSON
    if [ -f "current_found.json" ]; then
        new_found=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json)
        for ip in $new_found; do
            if ! grep -q "$ip" "valid_resolvers.txt" 2>/dev/null; then
                echo "$ip" >> "valid_resolvers.txt"
                # Send to Telegram immediately
                if [ -n "$TG_TOKEN" ]; then
                    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New IP Found: $ip" > /dev/null
                fi
            fi
        done
        rm current_found.json
    fi
    sleep 5
done
WORKER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner is now active in background.${NC}"; sleep 2; main_menu
}

view_progress() {
    if screen -list | grep -q "findns_worker"; then
        echo -e "${YELLOW}Attaching to session...${NC}"
        echo -e "To return to menu, press ${GREEN}Ctrl+A${NC} then ${GREEN}D${NC}."
        sleep 2
        screen -r findns_worker
    else
        echo -e "${RED}Scanner is not running!${NC}"; sleep 2; main_menu
    fi
}

# --- Standard Functions ---
test_tg() {
    load_config
    echo -e "Sending test to ID: $TG_ID"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Manual Test Message"
    sleep 2; main_menu
}

full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}Installation Completed!${NC}"; sleep 2; main_menu
}

view_results() { clear; echo -e "${GREEN}Found IPs:${NC}"; cat "valid_resolvers.txt" 2>/dev/null || echo "None."; read -p "Enter..."; main_menu; }
stop_scanner() { screen -S findns_worker -X quit; pkill -f worker.sh; echo "Stopped."; sleep 2; main_menu; }
uninstall_all() { rm -rf ~/findns-work; screen -S findns_worker -X quit; exit 0; }

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
