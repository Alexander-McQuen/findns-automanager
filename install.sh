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
    echo -e "${GREEN}    Findns Ultimate Auto-Manager          ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) ${CYAN}[FULL SETUP]${NC} Install & Build"
    echo -e "2) Set Config (Domain, Pubkey, Workers)"
    echo -e "3) Start Scanner (Background)"
    echo -e "4) View & Copy Results"
    echo -e "5) Stop Scanner"
    echo -e "6) Exit"
    echo -e "7) ${RED}[UNINSTALL]${NC} Remove Everything"
    echo -e "${BLUE}------------------------------------------${NC}"
    read -p "Select option [1-7]: " choice
    case $choice in
        1) full_setup ;;
        2) setup_config ;;
        3) start_scanner ;;
        4) view_results ;;
        5) stop_scanner ;;
        6) exit 0 ;;
        7) uninstall_all ;;
        *) main_menu ;;
    esac
}

full_setup() {
    echo -e "${YELLOW}Installing...${NC}"
    sudo apt update && sudo apt install git golang-go screen -y
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
    echo -e "${GREEN}Saved!${NC}"; sleep 1; main_menu
}

start_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    screen -dmS findns_worker bash -c "
        while true; do
            ./findns-repo/findns e2e dnstt --domain $DOMAIN --pubkey $PUBKEY --workers $WORKERS -i ./findns-repo/ir-resolvers.txt > temp_res.txt
            cat temp_res.txt >> $RESULT_FILE
            sort -u $RESULT_FILE -o $RESULT_FILE
            sleep 30
        done
    "
    echo -e "${GREEN}Scanner is running in background!${NC}"; sleep 2; main_menu
}

view_results() {
    clear
    if [ -s "$RESULT_FILE" ]; then
        echo -e "${GREEN}--- Found Resolvers ---${NC}"
        cat "$RESULT_FILE"
    else
        echo -e "${RED}No results yet.${NC}"
    fi
    echo ""
    read -p "Press Enter to back..."
    main_menu
}

stop_scanner() {
    screen -S findns_worker -X quit > /dev/null 2>&1
    echo -e "${RED}Scanner Stopped.${NC}"; sleep 2; main_menu
}

uninstall_all() {
    read -p "Are you sure you want to remove everything? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        screen -S findns_worker -X quit > /dev/null 2>&1
        cd ~
        rm -rf ~/findns-work
        echo -e "${RED}All files and scanner removed successfully.${NC}"
        exit 0
    else
        main_menu
    fi
}

main_menu
EOF

chmod +x super_manager.sh
./super_manager.sh
