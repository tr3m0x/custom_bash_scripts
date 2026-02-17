#!/bin/bash

# color codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' 
BOLD='\033[1m'

if [[ $# != 1 ]]; then
    echo -e "\n${RED}[ERROR]${NC} Missing IP address"
    echo -e "${GREEN}USAGE:${NC} $0 <ip_address>"
    echo -e "${GREEN}EXAMPLE:${NC} $0 192.168.1.1\n"
    exit 1
fi

target="$1"
output_file="port_scan_${target}.txt"

echo -e "\n${BLUE}[*]${NC} ${BOLD}Starting port scan on${NC} ${YELLOW}${target}${NC}"
echo -e "${BLUE}[*]${NC} ${BOLD}Scanning all ports (1-65535)${NC}\n"

sudo nmap -p- "$target" --min-rate 5000 -oN "$output_file"

echo -e "\n${BLUE}[*]${NC} ${BOLD}Extracting open ports...${NC}"
open_ports=$(grep '^[0-9]' "$output_file" | grep 'open' | cut -d '/' -f 1 | tr '\n' ',' | sed 's/,$//')

if [[ -n "$open_ports" ]]; then
    echo -e "\n${GREEN}[✓]${NC} ${BOLD}Open ports found:${NC} ${CYAN}${open_ports}${NC}"
    echo -e "${BLUE}[*]${NC} ${BOLD}Full results saved to:${NC} ${YELLOW}${output_file}${NC}"
    echo -e "\n${YELLOW}[!]${NC} ${BOLD}Recommend:${NC} ./deep_scan.sh $target $open_ports"
else
    echo -e "\n${RED}[!]${NC} ${BOLD}No open ports found on ${target}${NC}"
fi

echo -e "\n${GREEN}[✓]${NC} ${BOLD}Scan completed${NC}\n"