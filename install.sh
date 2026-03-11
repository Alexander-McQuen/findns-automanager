#!/bin/bash
# Findns Auto-Manager v5.0 - Smart Notifier Edition

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
    echo -e "${GREEN}    Findns Auto-Manager v5.0 (Smart TG)   ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) Full Setup"
    echo -e "2) Set Scanner Config"
    echo -e "3) Start Scanner"
    echo -e "4) View Found Results"
    echo -e "5) Stop Scanner"
    echo -e "8) Telegram Setup"
    echo -e "11) Test Telegram Message"
    echo -e "9) View Progress (Safe)"
    echo -e "10) Check Settings"
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

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    sleep 1

    cat << 'INNER_EOF' > worker.sh
#!/bin/bash
trap '' INT SIGINT SIGTERM
while true; do
    source .findns_config
    [ -f "valid_resolvers.txt" ] || touch "valid_resolvers.txt"
    
    # اجرای اسکنر
    ./findns-repo/findns e2e dnstt --domain "$DOMAIN" --pubkey "$PUBKEY" --workers "$WORKERS" -i ./findns-repo/ir-resolvers.txt -o current_found.json > temp_live.log 2>&1
    
    # استخراج آی‌پی‌ها (ترکیبی: هم از JSON هم از Log)
    raw_ips=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" current_found.json 2>/dev/null)
    if [ -z "$raw_ips" ]; then
        raw_ips=$(grep "OK" temp_live.log | awk '{print $2}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    fi

    # بررسی تک‌تک آی‌پی‌های پیدا شده
    if [ -n "$raw_ips" ]; then
        echo "$raw_ips" | while read -r ip; do
            if ! grep -q "$ip" "valid_resolvers.txt"; then
                # اگر آی‌پی جدید است: ارسال و ذخیره
                if [ -n "$TG_TOKEN" ]; then
                    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🎯 New Resolver Found: $ip" > /dev/null
                fi
                echo "$ip" >> "valid_resolvers.txt"
            fi
        done
        sort -u "valid_resolvers.txt" -o "valid_resolvers.txt"
    fi
    
    rm -f current_found.json
    sleep 5
done
INNER_EOF
    chmod +x worker.sh
    screen -dmS findns_worker ./worker.sh
    echo -e "${GREEN}Scanner is now running with Smart Notifications!${NC}"; sleep 2; main_menu
}

# سایر توابع کمکی
test_tg() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_ID" -d "text=🔔 Manual Test: Working!"
    main_menu
}

full_setup() {
    sudo apt update && sudo apt install git golang-go screen curl -y
    rm -rf findns-repo && git clone https://github.com/SamNet-dev/findns.git findns-repo
    cd findns-repo && go build -o findns ./cmd && cd ..
    go install www.bamsoftware.com/git/dnstt.git/dnstt-client@latest
    cp ~/go/bin/dnstt-client ./findns-repo/
    main_menu
}

setup_config() {
    read -p "Domain: " DOMAIN; read -p "Pubkey: " PUBKEY; read -p "Workers: " WORKERS
    echo "DOMAIN=\"$DOMAIN\"" > "$CONFIG_FILE"; echo "PUBKEY=\"$PUBKEY\"" >> "$CONFIG_FILE"; echo "WORKERS=\"${WORKERS:-50}\"" >> "$CONFIG_FILE"
    echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"
    main_menu
}

view_results() { clear; cat "valid_resolvers.txt" 2>/dev/null; read -p "Enter..."; main_menu; }
stop_scanner() { screen -S findns_worker -X quit; pkill -f worker.sh; main_menu; }
view_progress() { screen -r findns_worker || main_menu; }
setup_telegram() { read -p "Token: " TG_TOKEN; read -p "ID: " TG_ID; echo "TG_TOKEN=\"$TG_TOKEN\"" >> "$CONFIG_FILE"; echo "TG_ID=\"$TG_ID\"" >> "$CONFIG_FILE"; main_menu; }
show_config() { clear; echo -e "Domain: $DOMAIN\nTG ID: $TG_ID"; read -p "Enter..."; main_menu; }
uninstall_all() { rm -rf ~/findns-work; screen -S findns_worker -X quit; exit 0; }

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
