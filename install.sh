#!/bin/bash
# Findns Ultimate Manager v7.3 - Alex Platinum

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

# تابع لود و ذخیره یکپارچه برای جلوگیری از خالی شدن متغیرها
save_all() {
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"
    echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"
    echo "WORKERS=\"${WORKERS:-50}\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"
    echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
}

load_config() { [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"; }
load_config

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}   Findns Ultimate Manager v7.3 (Platinum) ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e " 1)  Install & Build System"
    echo -e " 2)  Set Scanner (Domain/Pubkey)"
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
    read -p "Select [1-12]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) setup_telegram ;; 
        4) show_config ;; 5) start_scanner ;; 6) view_progress ;; 
        7) view_results ;; 8) speed_test ;; 9) test_tg ;; 
        10) stop_scanner ;; 11) uninstall_all ;; 12) exit 0 ;; *) main_menu ;;
    esac
}

setup_config() {
    load_config
    read -p "Domain ($DOMAIN): " input_domain; DOMAIN=${input_domain:-$DOMAIN}
    read -p "Pubkey ($PUBKEY): " input_pubkey; PUBKEY=${input_pubkey:-$PUBKEY}
    read -p "Workers (${WORKERS:-50}): " input_workers; WORKERS=${input_workers:-$WORKERS}
    save_all; main_menu
}

setup_telegram() {
    load_config
    read -p "Bot Token ($TG_TOKEN): " input_token; TG_TOKEN=${input_token:-$TG_TOKEN}
    read -p "Chat ID ($TG_ID): " input_id; TG_ID=${input_id:-$TG_ID}
    save_all
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=✅ Linked Successfully"
    main_menu
}

show_config() {
    clear; load_config
    echo -e "${YELLOW}>>> Current Settings <<<${NC}"
    echo -e "Domain:    ${CYAN}${DOMAIN:-[NOT SET]}${NC}"
    echo -e "Pubkey:    ${CYAN}${PUBKEY:-[NOT SET]}${NC}"
    echo -e "Workers:   ${CYAN}${WORKERS:-50}${NC}"
    echo -e "TG Token:  ${GREEN}${TG_TOKEN:-[NOT SET]}${NC}"
    echo -e "TG ID:     ${GREEN}${TG_ID:-[NOT SET]}${NC}"
    echo -e "------------------------"
    read -p "Press Enter..." ; main_menu
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
    source .findns_config
    # استفاده از مقدار پیش‌فرض اگر ورکر خالی بود
    W_COUNT=${WORKERS:-50}
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$W_COUNT" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    
    if [ -f "current_found.json" ]; then
        new_ips=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json)
        for ip in $new_ips; do
            if ! grep -q "$ip" "valid_resolvers.txt" 2>/dev/null; then
                echo "$ip" >> "valid_resolvers.txt"
                [ -n "$TG_TOKEN" ] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New IP: $ip" > /dev/null
            fi
        done
        # ارسال فایل لیست کامل در هر چرخه
        [ -s "valid_resolvers.txt" ] && curl -s -F document=@"valid_resolvers.txt" "https://api.telegram.org/bot$TG_TOKEN/sendDocument?chat_id=$TG_ID" > /dev/null
        rm current_found.json
    fi
    sleep 5
done
WORKER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner Active! Check Option 6 in 10 seconds.${NC}"; sleep 2; main_menu
}

# --- بقیه توابع بدون تغییر ---
full_setup() { sudo apt update && sudo apt install git golang-go screen curl -y; rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo; cd findns-repo && go build -o findns ./cmd && cd ..; go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest; cp ~/go/bin/dnstt-client ./findns-repo/; main_menu; }
speed_test() { clear; echo -e ">>> Ping Test <<<"; [ ! -s "$RESULT_FILE" ] && sleep 2 && main_menu && return; temp_speed=".speed_results"; > $temp_speed; while read -r ip; do ping_res=$(ping -c 3 -W 1 "$ip" | tail -1 | awk -F '/' '{print $5}'); [ -n "$ping_res" ] && echo "$ping_res $ip" >> $temp_speed && echo -e "$ip | ${ping_res}ms"; done < "$RESULT_FILE"; sort -n $temp_speed | head -n 3; rm -f $temp_speed; read -p "Done..."; main_menu; }
view_progress() { screen -r findns_worker || main_menu; }
view_results() { clear; cat "valid_resolvers.txt" 2>/dev/null; read -p "Enter..."; main_menu; }
test_tg() { load_config; curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Test"; main_menu; }
stop_scanner() { screen -S findns_worker -X quit; pkill -f worker.sh; main_menu; }
uninstall_all() { rm -rf ~/findns-work; screen -S findns_worker -X quit; exit 0; }
main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
