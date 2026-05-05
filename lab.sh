#!/bin/bash

# --- CONFIGURATION ---
ISO_DIR="/home/gritli/Documents/iso_files"
VM_BASE_DIR="/home/gritli/vmware"

KALI_VMX="/home/gritli/Documents/VMs/kali-linux-2026.1-vmware-amd64.vmwarevm/kali-linux-2026.1-vmware-amd64.vmx"
UBUNTU_VMX="/home/gritli/vmware/Ubuntu/Ubuntu.vmx"

KALI_IP="172.16.162.60"
UBUNTU_IP="172.16.162.50"

KALI_USER="kali"
UBUNTU_USER="gritli"

# --- VM CREATION FUNCTION ---
create_vm() {
    local TYPE=$1
    local NAME=$2
    local VM_DIR="$VM_BASE_DIR/$NAME"
    local VMX_FILE="$VM_DIR/$NAME.vmx"
    local VMDK_FILE="$NAME.vmdk"

    if [[ -z "$TYPE" || -z "$NAME" ]]; then
        echo "Usage: lab create [win10|win11|ubuntu|server] [vm_name]"
        exit 1
    fi

    if [ -d "$VM_DIR" ]; then
        echo "Error: Directory $VM_DIR already exists."
        exit 1
    fi

    mkdir -p "$VM_DIR"
    cd "$VM_DIR" || exit

    case $TYPE in
        win10)
            ISO="$ISO_DIR/win10.iso"
            GUEST_OS="windows9-64"
            FIRMWARE="bios"
            ;;
        win11)
            ISO="$ISO_DIR/win11.iso"
            GUEST_OS="windows9-64"
            FIRMWARE="bios"
            ;;
        server)
            ISO="$ISO_DIR/win_server.iso"
            GUEST_OS="windows9-64"
            FIRMWARE="bios"
            ;;
        ubuntu)
            ISO="$ISO_DIR/ubuntu.iso"
            GUEST_OS="ubuntu-64"
            FIRMWARE="efi"
            ;;
        *)
            echo "Invalid type. Options: win10, win11, server, ubuntu"
            exit 1
            ;;
    esac

    echo "Creating 60GB Virtual Disk..."
    qemu-img create -f vmdk "$VMDK_FILE" 60G

    echo "Generating VMX configuration..."
    cat <<EOF > "$VMX_FILE"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"
vmci0.present = "TRUE"
displayName = "$NAME"
guestOS = "$GUEST_OS"
memsize = "2048"
numvcpus = "2"
cpuid.coresPerSocket = "1"
mks.enable3d = "FALSE"
firmware = "$FIRMWARE"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge5.present = "TRUE"
pciBridge6.present = "TRUE"
pciBridge7.present = "TRUE"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$VMDK_FILE"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.virtualDev = "e1000"
ide1:0.present = "TRUE"
ide1:0.fileName = "$ISO"
ide1:0.deviceType = "cdrom-image"
EOF

    echo "Success: VM $NAME created at $VM_DIR"
}

# --- MAIN LOGIC ---
case $1 in
    create)
        create_vm "$2" "$3"
        ;;
    kali)
        TARGET_VMX="$KALI_VMX"
        TARGET_IP="$KALI_IP"
        TARGET_USER="$KALI_USER"
        ;;
    ubuntu)
        TARGET_VMX="$UBUNTU_VMX"
        TARGET_IP="$UBUNTU_IP"
        TARGET_USER="$UBUNTU_USER"
        ;;
    *)
        echo "Usage:"
        echo "  lab [kali|ubuntu] [start|stop|ssh|status]"
        echo "  lab create [win10|win11|ubuntu|server] [name]"
        exit 1
        ;;
esac

# Actions for existing VMs
if [[ "$1" == "kali" || "$1" == "ubuntu" ]]; then
    case $2 in
        start)
            vmrun -T ws start "$TARGET_VMX" nogui
            echo "Started $1 in background."
            ;;
        stop)
            vmrun -T ws stop "$TARGET_VMX" soft
            echo "Stopped $1."
            ;;
        ssh)
            ssh "$TARGET_USER@$TARGET_IP"
            ;;
        status)
            vmrun list | grep -q "$TARGET_VMX" && echo "$1 status: RUNNING" || echo "$1 status: STOPPED"
            ;;
        *)
            echo "Error: Invalid action for $1."
            exit 1
            ;;
    esac
fi