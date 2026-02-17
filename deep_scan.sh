#!/bin/bash

echo -e "\n\033[1;33m[!] RECOMMENDED: Use portscan script first to identify the open ports\033[0m\n"

if [[ $# != 2 ]]; then
    echo -e "\033[1;31m[ERROR] Missing arguments\033[0m"
    echo -e "\033[1;32mUSAGE:\033[0m $0 <ip_address> <ports>"
    echo -e "\033[1;32mEXAMPLE:\033[0m $0 192.168.1.1 22,80"
    exit 1
fi

target="$1"
ports="$2"

echo -e "\033[1;34m[*]\033[0m \033[1mStarting deep scan on\033[0m \033[1;33m$target\033[0m"
echo -e "\033[1;34m[*]\033[0m \033[1mTarget ports:\033[0m \033[1;36m$ports\033[0m\n"

sudo nmap -sC -sV "$target" -p "$ports" -oN "deep_scan_${target}.txt"

echo -e "\n\033[1;32m[✓]\033[0m \033[1mScan complete!\033[0m"
echo -e "\033[1;34m[*]\033[0m \033[1mResults saved to:\033[0m \033[1;33mdeep_scan_${target}.txt\033[0m\n"