#!/bin/bash
# Findns Ultimate Manager v9.3 - The Python JSON Parser Patch

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

load_config() {
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    DOMAIN=${DOMAIN:-""}
    PUBKEY=${PUBKEY:-""}
    WORKERS=${WORKERS:-50}
    TG_TOKEN=${TG_TOKEN:-""}
    TG_ID=${TG_ID:-""}
}

save_all() {
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
}

main_menu() {
    clear
    load_config
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Ultimate Manager v9.3 (Fix)    ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e " 1)  Install & Build System"
    echo -e " 2)  Set Scanner (Domain/Pubkey/Workers)"
    echo -e " 3)  Set Telegram Bot Settings"
    echo -e " 4)  Check Current Settings"
    echo -e " 5)  Start Scanner (Background)"
    echo -e " 6)  View Visual Progress (Live)"
    echo -e " 7)  View Found Resolvers (List)"
    echo -e " 8)  Run Speed/Ping Test"
    echo -e " 9)  Send Test Message to TG"
    echo -e " 10) Stop Scanner Session"
    echo -e " 11) ${RED}Uninstall Everything${NC}"
    echo -e " 12) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select option [1-12]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) setup_telegram ;; 
        4) show_config ;; 5) start_scanner ;; 6) view_progress ;; 
        7) view_results ;; 8) speed_test ;; 9) test_tg ;; 
        10) stop_scanner ;; 11) uninstall_all ;; 12) exit 0 ;; *) main_menu ;;
    esac
}

full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    echo -e "${GREEN}Installation & Build Completed!${NC}"; sleep 2; main_menu
}

start_scanner() {
    load_config
    if [[ -z "$DOMAIN" || -z "$PUBKEY" ]]; then
        echo -e "${RED}Error: Setup Config first!${NC}"; sleep 2; main_menu; return
    fi
    screen -S findns_worker -X quit > /dev/null 2>&1
    sleep 1

    cat << 'WORKER_EOF' > worker.sh
#!/bin/bash
while true; do
    if [ -f .findns_config ]; then source .findns_config; fi
    W_COUNT=${WORKERS:-50}
    if [[ ! "$W_COUNT" =~ ^[0-9]+$ ]]; then W_COUNT=50; fi
    
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$W_COUNT" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    
    added_new=false
    if [ -f "current_found.json" ]; then
        # ---> تنها خطی که تغییر کرد اینجاست (استفاده از پایتون داخلی سرور برای خواندن دقیق لیست passed) <---
        new_ips=$(python3 -c 'import sys, json; d=json.load(sys.stdin); print(" ".join([i["ip"] for i in d.get("passed", [])]))' < current_found.json 2>/dev/null)
        
        for ip in $new_ips; do
            if ! grep -q "$ip" "valid_resolvers.txt" 2>/dev/null; then
                echo "$ip" >> "valid_resolvers.txt"
                added_new=true
                [ -n "$TG_TOKEN" ] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 Passed IP Found: $ip" > /dev/null
            fi
        done
        
        if [ "$added_new" = true ] && [ -s "valid_resolvers.txt" ] && [ -n "$TG_TOKEN" ]; then
            curl -s -F document=@"valid_resolvers.txt" "https://api.telegram.org/bot$TG_TOKEN/sendDocument?chat_id=$TG_ID&caption=📄 Updated Resolver List" > /dev/null
        fi
        rm -f current_found.json
    fi
    sleep 5
done
WORKER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner Started! Progress bar is active (Option 6).${NC}"; sleep 2; main_menu
}

speed_test() {
    clear
    echo -e "${YELLOW}>>> Running Speed Test (Latency) <<<${NC}"
    if [ ! -s "$RESULT_FILE" ]; then 
        echo -e "${RED}No IPs to test.${NC}"; read -p "Press Enter..."; main_menu; return
    fi
    
    temp_speed=".speed_results"
    > $temp_speed
    
    while read -r ip; do
        avg_ping=$(ping -c 2 -W 1 "$ip" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        if [[ -n "$avg_ping" && "$avg_ping" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo -e "${GREEN}$ip${NC} | ${YELLOW}${avg_ping}ms${NC}"
            echo "$avg_ping $ip" >> $temp_speed
        else
            echo -e "${RED}$ip${NC} | ${RED}Timeout/Failed${NC}"
        fi
    done < "$RESULT_FILE"
    
    echo -e "\n${BLUE}--- Top 3 Fastest ---${NC}"
    sort -n $temp_speed | head -n 3 | awk '{print "🚀 " $2 " (" $1 "ms)"}'
    rm -f $temp_speed
    read -p "Press Enter to return..." ; main_menu
}

setup_config() { read -p "Domain: " d; DOMAIN=${d:-$DOMAIN}; read -p "Pubkey: " p; PUBKEY=${p:-$PUBKEY}; read -p "Workers (50): " w; WORKERS=${w:-$WORKERS}; save_all; main_menu; }
setup_telegram() { read -p "Bot Token: " t; TG_TOKEN=${t:-$TG_TOKEN}; read -p "Chat ID: " i; TG_ID=${i:-$TG_ID}; save_all; main_menu; }
show_config() { clear; load_config; echo -e "Domain: $DOMAIN\nPubkey: $PUBKEY\nWorkers: $WORKERS\nTG Token: $TG_TOKEN\nTG ID: $TG_ID"; read -p "Enter..."; main_menu; }
view_progress() { screen -r findns_worker || main_menu; }
view_results() { clear; cat "valid_resolvers.txt" 2>/dev/null || echo "Empty."; read -p "Enter..."; main_menu; }
test_tg() { curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Test Message"; main_menu; }
stop_scanner() { screen -S findns_worker -X quit; pkill -f worker.sh; main_menu; }
uninstall_all() { rm -rf ~/findns-work; screen -S findns_worker -X quit; exit 0; }

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
