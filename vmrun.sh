#!/bin/bash

# --- CONFIGURATION ---
# Path to your Kali VMX
KALI_VMX="$HOME/Documents/VMs/kali-linux-2026.1-vmware-amd64.vmwarevm/kali-linux-2026.1-vmware-amd64.vmx"

# Path to your Ubuntu VMX (Ensure the filename ubuntu.vmx is correct)
UBUNTU_VMX="$HOME/vmware/ubuntu/ubuntu.vmx"

# Static IPs we configured
KALI_IP="192.168.74.60"
UBUNTU_IP="192.168.74.50"

# Default Usernames
KALI_USER="kali"
UBUNTU_USER="ubuntu"

# --- ARGUMENT CHECK ---
if [ $# -lt 2 ]; then
    echo "Usage: lab [kali|ubuntu] [start|stop|ssh|status]"
    exit 1
fi

VM_TARGET=$1
ACTION=$2

# --- DATA ASSIGNMENT ---
case $VM_TARGET in
    kali)
        VMX_PATH="$KALI_VMX"
        IP_ADDR="$KALI_IP"
        VM_USER="$KALI_USER"
        ;;
    ubuntu)
        VMX_PATH="$UBUNTU_VMX"
        IP_ADDR="$UBUNTU_IP"
        VM_USER="$UBUNTU_USER"
        ;;
    *)
        echo "Error: Invalid VM target. Use 'kali' or 'ubuntu'."
        exit 1
        ;;
esac

# --- ACTION EXECUTION ---
case $ACTION in
    start)
        echo "Starting $VM_TARGET in headless mode..."
        vmrun -T ws start "$VMX_PATH" nogui
        ;;
    stop)
        echo "Stopping $VM_TARGET..."
        vmrun -T ws stop "$VMX_PATH" soft
        ;;
    ssh)
        echo "Connecting to $VM_TARGET at $IP_ADDR..."
        ssh "$VM_USER@$IP_ADDR"
        ;;
    status)
        vmrun list | grep -q "$VMX_PATH" && echo "$VM_TARGET status: RUNNING" || echo "$VM_TARGET status: STOPPED"
        ;;
    *)
        echo "Error: Invalid action. Use 'start', 'stop', 'ssh', or 'status'."
        exit 1
        ;;
esac
