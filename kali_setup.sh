#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Kali Pentesting / HTB / THM Setup Script
# ============================================================

INSTALL_HEAVY_TOOLS=false   # Set to true for BloodHound, Neo4j, Docker, etc.
INSTALL_DOCKER=false        # Set to true if you want Docker installed
INSTALL_GO_TOOLS=false      # Set to true if you want selected Go-based tools

LOG_FILE="/var/log/kali-pentest-setup.log"

# -----------------------------
# Helpers
# -----------------------------

log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

die() {
  log "[!] Error: $1"
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Please run as root: sudo $0"
  fi
}

detect_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  else
    TARGET_USER="$(logname 2>/dev/null || echo root)"
  fi

  HOME_DIR="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

  if [[ -z "$HOME_DIR" || ! -d "$HOME_DIR" ]]; then
    die "Could not detect home directory for user: $TARGET_USER"
  fi
}

apt_update_upgrade() {
  log "\n[+] Updating package lists..."
  apt update -y

  log "\n[+] Upgrading installed packages..."
  DEBIAN_FRONTEND=noninteractive apt upgrade -y
}

install_packages() {
  local packages=("$@")
  local available=()
  local missing=()

  log "\n[+] Checking package availability..."

  for pkg in "${packages[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done

  if [[ "${#available[@]}" -gt 0 ]]; then
    log "[+] Installing available packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y "${available[@]}"
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log "\n[!] Skipped unavailable packages:"
    printf '    - %s\n' "${missing[@]}" | tee -a "$LOG_FILE"
  fi
}

create_directories() {
  log "\n[+] Creating workspace directories..."

  local dirs=(
    "$HOME_DIR/HTB"
    "$HOME_DIR/THM"
    "$HOME_DIR/PNPT"
    "$HOME_DIR/Labs"
    "$HOME_DIR/Tools"
    "$HOME_DIR/Wordlists"
    "$HOME_DIR/VPN"
    "$HOME_DIR/Reports"
    "$HOME_DIR/Screenshots"
    "$HOME_DIR/Notes"
  )

  mkdir -p "${dirs[@]}"

  if [[ "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_USER" "${dirs[@]}"
  fi
}

prepare_wordlists() {
  log "\n[+] Preparing wordlists..."

  if [[ -f /usr/share/wordlists/rockyou.txt.gz && ! -f /usr/share/wordlists/rockyou.txt ]]; then
    log "[+] Extracting rockyou.txt..."
    gunzip -k /usr/share/wordlists/rockyou.txt.gz
  elif [[ -f /usr/share/wordlists/rockyou.txt ]]; then
    log "[*] rockyou.txt already exists."
  else
    log "[!] rockyou.txt.gz not found. Install seclists/wordlists manually if needed."
  fi

  ln -sfn /usr/share/seclists "$HOME_DIR/Wordlists/SecLists" 2>/dev/null || true
  ln -sfn /usr/share/wordlists "$HOME_DIR/Wordlists/KaliWordlists" 2>/dev/null || true

  if [[ "$TARGET_USER" != "root" ]]; then
    chown -h "$TARGET_USER:$TARGET_USER" "$HOME_DIR/Wordlists/SecLists" 2>/dev/null || true
    chown -h "$TARGET_USER:$TARGET_USER" "$HOME_DIR/Wordlists/KaliWordlists" 2>/dev/null || true
  fi
}

install_python_tooling() {
  log "\n[+] Setting up Python tooling..."

  install_packages python3 python3-pip python3-venv pipx

  sudo -u "$TARGET_USER" python3 -m pipx ensurepath >/dev/null 2>&1 || true
}

install_go_tooling() {
  if [[ "$INSTALL_GO_TOOLS" != true ]]; then
    log "\n[*] Skipping Go tools. Set INSTALL_GO_TOOLS=true to enable."
    return
  fi

  log "\n[+] Installing Go tooling..."

  install_packages golang-go

  sudo -u "$TARGET_USER" bash -lc '
    mkdir -p "$HOME/go/bin"

    go install github.com/projectdiscovery/httpx/cmd/httpx@latest
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    go install github.com/tomnomnom/waybackurls@latest
    go install github.com/tomnomnom/assetfinder@latest
  '
}

install_docker() {
  if [[ "$INSTALL_DOCKER" != true ]]; then
    log "\n[*] Skipping Docker. Set INSTALL_DOCKER=true to enable."
    return
  fi

  log "\n[+] Installing Docker..."

  install_packages docker.io docker-compose

  systemctl enable docker || true
  systemctl start docker || true

  if [[ "$TARGET_USER" != "root" ]]; then
    usermod -aG docker "$TARGET_USER"
    log "[*] Added $TARGET_USER to docker group. Log out and back in for it to apply."
  fi
}

configure_zshrc() {
  log "\n[+] Configuring .zshrc aliases and functions..."

  local zshrc="$HOME_DIR/.zshrc"
  local backup="$HOME_DIR/.zshrc.backup.$(date +%Y%m%d-%H%M%S)"

  touch "$zshrc"
  cp "$zshrc" "$backup"

  # Remove old managed block if present
  sed -i '/# >>> kali-pentest-setup >>>/,/# <<< kali-pentest-setup <<</d' "$zshrc"

  cat <<'EOF' >> "$zshrc"

# >>> kali-pentest-setup >>>

# -----------------------------
# Quality of life
# -----------------------------
alias l='ls -lah'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ports-listening='sudo ss -tulpn'
alias myip="hostname -I | awk '{print \$1}'"
alias tunip="ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
alias vpnip='tunip'
alias c='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'

# -----------------------------
# Useful paths
# -----------------------------
export SECLISTS=/usr/share/seclists
export WORDLISTS=/usr/share/wordlists
export ROCKYOU=/usr/share/wordlists/rockyou.txt
export DIR_MEDIUM=/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
export DIR_SMALL=/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt
export COMMON_WEB=$SECLISTS/Discovery/Web-Content/common.txt
export RAFT_MEDIUM=$SECLISTS/Discovery/Web-Content/raft-medium-directories.txt
export RAFT_FILES=$SECLISTS/Discovery/Web-Content/raft-medium-files.txt

# Go tools path
export PATH="$PATH:$HOME/go/bin:$HOME/.local/bin"

# -----------------------------
# Nmap helpers
# -----------------------------

ports() {
  if [[ -z "$1" ]]; then
    echo "Usage: ports <target>"
    return 1
  fi

  mkdir -p scans
  sudo nmap -p- --min-rate 1000 -T4 "$1" -oN scans/ports.nmap

  echo
  echo "[*] Open ports:"
  grep -oP '^\d+(?=/tcp\s+open)' scans/ports.nmap | paste -sd, -
}

deepscan() {
  if [[ -z "$1" ]]; then
    echo "Usage: deepscan <target> [ports]"
    return 1
  fi

  local target="$1"
  local ports_arg="${2:-}"

  mkdir -p scans

  if [[ -z "$ports_arg" ]]; then
    ports_arg="$(grep -oP '^\d+(?=/tcp\s+open)' scans/ports.nmap 2>/dev/null | paste -sd, -)"
  fi

  if [[ -z "$ports_arg" ]]; then
    echo "[!] No ports supplied and scans/ports.nmap not found."
    echo "Usage: deepscan <target> <ports>"
    return 1
  fi

  sudo nmap -sC -sV -p "$ports_arg" "$target" -oN scans/deepscan.nmap
}

udp-scan() {
  if [[ -z "$1" ]]; then
    echo "Usage: udp-scan <target>"
    return 1
  fi

  mkdir -p scans
  sudo nmap -sU --top-ports 100 "$1" -oN scans/udp-top100.nmap
}

vulnscan() {
  if [[ -z "$1" ]]; then
    echo "Usage: vulnscan <target> [ports]"
    return 1
  fi

  local target="$1"
  local ports_arg="${2:-}"

  mkdir -p scans

  if [[ -z "$ports_arg" ]]; then
    ports_arg="$(grep -oP '^\d+(?=/tcp\s+open)' scans/ports.nmap 2>/dev/null | paste -sd, -)"
  fi

  if [[ -z "$ports_arg" ]]; then
    echo "[!] No ports supplied and scans/ports.nmap not found."
    return 1
  fi

  sudo nmap --script vuln -p "$ports_arg" "$target" -oN scans/vulnscan.nmap
}

# -----------------------------
# Web enumeration
# -----------------------------

gobust-medium() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: gobust-medium <url>"
    return 1
  fi

  mkdir -p web
  gobuster dir \
    -u "$1" \
    -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
    -x php,txt,html,js,asp,aspx,jsp \
    -t 50 \
    -o web/gobuster-medium.txt
}

ffuf-medium() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: ffuf-medium <url-with-FUZZ>"
    echo "Example: ffuf-medium http://target/FUZZ"
    return 1
  fi

  mkdir -p web
  ffuf \
    -u "$1" \
    -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
    -e .php,.txt,.html,.js,.asp,.aspx,.jsp \
    -t 50 \
    -o web/ffuf-medium.json
}

ferox() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: ferox <url>"
    return 1
  fi

  mkdir -p web
  feroxbuster \
    -u "$1" \
    -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
    -x php,txt,html,js,asp,aspx,jsp \
    -t 50 \
    -o web/feroxbuster.txt
}

whatweb-scan() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: whatweb-scan <url>"
    return 1
  fi

  mkdir -p web
  whatweb -a 3 "$1" | tee web/whatweb.txt
}

nikto-scan() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: nikto-scan <url>"
    return 1
  fi

  mkdir -p web
  nikto -h "$1" | tee web/nikto.txt
}

# -----------------------------
# SMB / AD helpers
# -----------------------------

smb-null() {
  if [[ -z "$1" ]]; then
    echo "Usage: smb-null <target>"
    return 1
  fi

  smbclient -L "//$1/" -N
}

smb-enum() {
  if [[ -z "$1" ]]; then
    echo "Usage: smb-enum <target>"
    return 1
  fi

  mkdir -p enum
  enum4linux-ng "$1" | tee "enum/enum4linux-ng-$1.txt"
}

ldap-basic() {
  if [[ -z "$1" ]]; then
    echo "Usage: ldap-basic <target>"
    return 1
  fi

  nmap -n -sV --script "ldap* and not brute" -p 389,636,3268,3269 "$1"
}

# -----------------------------
# Reverse shell helpers
# -----------------------------

listen() {
  local port="${1:-4444}"
  rlwrap -cAr nc -lvnp "$port"
}

serve() {
  local port="${1:-8000}"
  python3 -m http.server "$port"
}

# -----------------------------
# Project helpers
# -----------------------------

mkbox() {
  if [[ -z "$1" ]]; then
    echo "Usage: mkbox <box-name>"
    return 1
  fi

  mkdir -p "$1"/{scans,web,loot,exploits,notes,screenshots,creds,enum}
  cd "$1" || return
  touch notes/notes.md
  echo "[+] Created workspace for $1"
}

extract-ports() {
  local file="${1:-scans/ports.nmap}"

  if [[ ! -f "$file" ]]; then
    echo "[!] File not found: $file"
    return 1
  fi

  grep -oP '^\d+(?=/tcp\s+open)' "$file" | paste -sd, -
}

# <<< kali-pentest-setup <<<
EOF

  if [[ "$TARGET_USER" != "root" ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$zshrc" "$backup"
  fi

  log "[*] Backed up .zshrc to: $backup"
}

main() {
  require_root
  detect_user

  log "----------------------------------------------------"
  log "[+] Starting Kali Pentesting Setup"
  log "[+] Target user: $TARGET_USER"
  log "[+] Home dir:    $HOME_DIR"
  log "[+] Log file:    $LOG_FILE"
  log "----------------------------------------------------"

  apt_update_upgrade

  BASE_PACKAGES=(
    build-essential
    git
    curl
    wget
    vim
    neovim
    tmux
    screen
    unzip
    zip
    p7zip-full
    jq
    xclip
    net-tools
    dnsutils
    iproute2
    whois
    traceroute
    openvpn
    wireguard
    resolvconf
    flameshot
    rlwrap
  )

  RECON_PACKAGES=(
    nmap
    masscan
    rustscan
    autorecon
    whatweb
    nikto
    wafw00f
    dnsrecon
    dnsenum
    fierce
    theharvester
    amass
  )

  WEB_PACKAGES=(
    seclists
    wordlists
    gobuster
    feroxbuster
    dirsearch
    ffuf
    wfuzz
    sqlmap
    zaproxy
    burpsuite
  )

  EXPLOIT_PACKAGES=(
    searchsploit
    exploitdb
    metasploit-framework
    netcat-traditional
    socat
    chisel
    ligolo-ng
  )

  PASSWORD_PACKAGES=(
    hydra
    john
    hashcat
    hashid
    hash-identifier
    cewl
    crunch
  )

  SMB_AD_PACKAGES=(
    smbclient
    samba-common-bin
    enum4linux
    enum4linux-ng
    nbtscan
    ldap-utils
    krb5-user
    python3-impacket
    impacket-scripts
    bloodhound.py
    netexec
    crackmapexec
    evil-winrm
    responder
  )

  PRIVESC_PACKAGES=(
    linpeas
    unix-privesc-check
    pspy
  )

  HEAVY_PACKAGES=(
    bloodhound
    neo4j
    maltego
  )

  install_packages "${BASE_PACKAGES[@]}"
  install_packages "${RECON_PACKAGES[@]}"
  install_packages "${WEB_PACKAGES[@]}"
  install_packages "${EXPLOIT_PACKAGES[@]}"
  install_packages "${PASSWORD_PACKAGES[@]}"
  install_packages "${SMB_AD_PACKAGES[@]}"
  install_packages "${PRIVESC_PACKAGES[@]}"

  if [[ "$INSTALL_HEAVY_TOOLS" == true ]]; then
    install_packages "${HEAVY_PACKAGES[@]}"
  else
    log "\n[*] Skipping heavy tools. Set INSTALL_HEAVY_TOOLS=true to enable."
  fi

  install_python_tooling
  install_go_tooling
  install_docker
  create_directories
  prepare_wordlists
  configure_zshrc

  apt autoremove -y
  apt clean

  log "\n----------------------------------------------------"
  log "[+] Setup complete."
  log "[+] Restart your terminal or run:"
  log "    source ~/.zshrc"
  log ""
  log "[*] Useful commands added:"
  log "    mkbox <name>"
  log "    ports <target>"
  log "    deepscan <target>"
  log "    gobust-medium <url>"
  log "    ffuf-medium <url-with-FUZZ>"
  log "    ferox <url>"
  log "    listen 4444"
  log "    serve 8000"
  log "----------------------------------------------------"
}

main "$@"