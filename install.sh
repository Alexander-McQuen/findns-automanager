#!/bin/bash
# Findns Ultimate Manager v6.5 - Alex Speed Edition

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

load_config() { [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"; }
load_config

main_menu() {
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}    Findns Ultimate Manager v6.5 (Pro)    ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) [SETUP] Install & Build"
    echo -e "2) [CONFIG] Set Domain/Pubkey"
    echo -e "3) [START] Run Background Scanner"
    echo -e "4) [VIEW] List Found Resolvers"
    echo -e "5) [STOP] Kill Scanner Session"
    echo -e "------------------------------------------"
    echo -e "12) ${YELLOW}[SPEED]${NC} Ping Test & Find Fastest IPs"
    echo -e "8) [TG] Setup Telegram Bot"
    echo -e "9) [PROGRESS] Visual Progress Bar"
    echo -e "10) [CHECK] Show All Settings"
    echo -e "11) [TEST] Send Test Msg to TG"
    echo -e "------------------------------------------"
    echo -e "7) Uninstall Everything"
    echo -e "6) Exit"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select [1-12]: " choice
    case $choice in
        1) full_setup ;; 2) setup_config ;; 3) start_scanner ;; 
        4) view_results ;; 5) stop_scanner ;; 12) speed_test ;;
        8) setup_telegram ;; 9) view_progress ;; 10) show_config ;; 
        11) test_tg ;; 7) uninstall_all ;; 6) exit 0 ;; *) main_menu ;;
    esac
}

speed_test() {
    clear
    if [ ! -s "$RESULT_FILE" ]; then
        echo -e "${RED}No IPs found yet! Start scanner first.${NC}"
        sleep 2; main_menu; return
    fi
    echo -e "${YELLOW}>>> Testing Latency for Found IPs (3 Pings each) <<<${NC}"
    echo -e "--------------------------------------------------------"
    echo -e "${CYAN}IP Address${NC} \t\t | ${CYAN}Avg Latency${NC}"
    echo -e "--------------------------------------------------------"
    
    # فایل موقت برای ذخیره نتایج تست
    temp_speed=".speed_results"
    > $temp_speed

    while read -r ip; do
        # پینگ ۳ تایی با تایم‌اوت ۱ ثانیه برای سرعت بالاتر
        ping_res=$(ping -c 3 -W 1 "$ip" | tail -1 | awk -F '/' '{print $5}')
        if [ -n "$ping_res" ]; then
            echo -e "${GREEN}$ip${NC} \t | ${YELLOW}${ping_res}ms${NC}"
            echo "$ping_res $ip" >> $temp_speed
        else
            echo -e "${RED}$ip${NC} \t | ${RED}Timed Out${NC}"
        fi
    done < "$RESULT_FILE"

    echo -e "--------------------------------------------------------"
    echo -e "${GREEN}Top 3 Fastest IPs:${NC}"
    sort -n $temp_speed | head -n 3 | awk '{print "🚀 " $2 " (" $1 "ms)"}'
    echo -e "--------------------------------------------------------"
    rm -f $temp_speed
    read -p "Press Enter to return..."
    main_menu
}

# --- بخش شروع اسکنر بدون تغییر ---
start_scanner() {
    load_config
    if [[ -z "$DOMAIN" || -z "$PUBKEY" ]]; then
        echo -e "${RED}Error: Setup config first!${NC}"; sleep 2; main_menu; return
    fi
    screen -S findns_worker -X quit > /dev/null 2>&1
    sleep 1
    cat << 'WORKER_EOF' > worker.sh
#!/bin/bash
while true; do
    source .findns_config
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json
    if [ -f "current_found.json" ]; then
        new_found=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json)
        for ip in $new_found; do
            if ! grep -q "$ip" "valid_resolvers.txt" 2>/dev/null; then
                echo "$ip" >> "valid_resolvers.txt"
                [ -n "$TG_TOKEN" ] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New IP Found: $ip" > /dev/null
            fi
        done
        rm current_found.json
    fi
    sleep 5
done
WORKER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner is active.${NC}"; sleep 2; main_menu
}

# --- سایر توابع سیستمی (بدون تغییر) ---
full_setup() { sudo apt update && sudo apt install git golang-go screen curl -y; rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo; cd findns-repo && go build -o findns ./cmd && cd ..; go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest; cp ~/go/bin/dnstt-client ./findns-repo/; main_menu; }
setup_config() { read -p "Domain: " DOMAIN; read -p "Pubkey: " PUBKEY; read -p "Workers: " WORKERS; echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"; echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"; main_menu; }
setup_telegram() { read -p "Token: " TG_TOKEN; read -p "ID: " TG_ID; echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"$WORKERS\"" >> "$CONFIG_FILE"; echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"; main_menu; }
show_config() { clear; load_config; echo -e "Domain: $DOMAIN\nPubkey: $PUBKEY\nTG ID: $TG_ID"; read -p "Enter..."; main_menu; }
view_results() { clear; cat "$RESULT_FILE" 2>/dev/null || echo "None."; read -p "Enter..."; main_menu; }
stop_scanner() { screen -S findns_worker -X quit; pkill -f worker.sh; main_menu; }
view_progress() { screen -r findns_worker || main_menu; }
test_tg() { load_config; curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Test Msg"; main_menu; }
uninstall_all() { rm -rf ~/findns-work; screen -S findns_worker -X quit; exit 0; }
main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
