#!/bin/bash
set -e

# =============================================================================
# P16 GPU Server ISO Customization Script
# Runs inside Docker container to build custom Ubuntu Server ISO
# =============================================================================

# Configuration
UBUNTU_VERSION="24.04"
UBUNTU_CODENAME="noble"
ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
ISO_NAME="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
OUTPUT_NAME="${OUTPUT_NAME:-p16-gpu-server-${UBUNTU_VERSION}.iso}"
NVIDIA_DRIVER="nvidia-driver-550"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

# =============================================================================
section "Downloading Ubuntu Server ISO"
# =============================================================================

if [ -f "/cache/${ISO_NAME}" ]; then
    log "Using cached ISO: ${ISO_NAME}"
    cp "/cache/${ISO_NAME}" "/work/${ISO_NAME}"
else
    log "Downloading Ubuntu Server ${UBUNTU_VERSION}..."
    wget -q --show-progress -O "/work/${ISO_NAME}" "${ISO_URL}"
    cp "/work/${ISO_NAME}" "/cache/${ISO_NAME}"
fi

# =============================================================================
section "Extracting ISO"
# =============================================================================

log "Extracting ISO contents..."
mkdir -p /work/iso-extract
7z x -o/work/iso-extract "/work/${ISO_NAME}" -y > /dev/null

# Also extract the squashfs filesystem for modifications
log "Extracting squashfs filesystem..."
mkdir -p /work/squashfs
unsquashfs -d /work/squashfs-root /work/iso-extract/casper/ubuntu-server-minimal.squashfs 2>/dev/null || \
unsquashfs -d /work/squashfs-root /work/iso-extract/casper/filesystem.squashfs 2>/dev/null || \
log "No squashfs to extract (live server ISO)"

# =============================================================================
section "Adding Autoinstall Configuration"
# =============================================================================

log "Creating autoinstall directory..."
mkdir -p /work/iso-extract/autoinstall

# Copy autoinstall files
cp /autoinstall/user-data /work/iso-extract/autoinstall/
cp /autoinstall/meta-data /work/iso-extract/autoinstall/

log "Autoinstall configuration added"

# =============================================================================
section "Adding Server Setup Utility"
# =============================================================================

log "Downloading server-setup script..."
mkdir -p /work/iso-extract/p16-setup

# Download from GitHub
curl -fsSL https://raw.githubusercontent.com/profzeller/p16-server-setup/main/setup.sh \
    -o /work/iso-extract/p16-setup/setup.sh
chmod +x /work/iso-extract/p16-setup/setup.sh

# Create install script that runs post-installation
cat > /work/iso-extract/p16-setup/install-server-setup.sh << 'INSTALL_SCRIPT'
#!/bin/bash
# Post-install script to set up server-setup utility

# Install server-setup command
cp /cdrom/p16-setup/setup.sh /usr/local/bin/server-setup
chmod +x /usr/local/bin/server-setup

# Create auto-start on login
cat > /etc/profile.d/server-setup-autostart.sh << 'EOF'
# Auto-start server-setup menu on interactive login
if [[ $- == *i* ]] && [[ -z "$SERVER_SETUP_RUNNING" ]] && [[ -z "$SSH_CONNECTION" || -n "$FORCE_MENU" ]]; then
    if [ ! -f /etc/gpu-server/.menu-disabled ]; then
        export SERVER_SETUP_RUNNING=1
        exec /usr/local/bin/server-setup
    fi
fi
EOF

# Create marker directory
mkdir -p /etc/gpu-server

echo "Server setup utility installed. Run 'server-setup' to launch."
INSTALL_SCRIPT

chmod +x /work/iso-extract/p16-setup/install-server-setup.sh

log "Server setup utility added to ISO"

# =============================================================================
section "Creating Package Lists for Offline Install"
# =============================================================================

log "Creating package download script..."
cat > /work/iso-extract/p16-setup/download-packages.sh << 'DLSCRIPT'
#!/bin/bash
# Downloads packages for offline installation
# Run this on an Ubuntu 24.04 system with internet

PACKAGES=(
    # NVIDIA
    nvidia-driver-550
    nvidia-container-toolkit
    nvidia-container-runtime

    # Docker
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin

    # Utilities
    curl
    wget
    git
    htop
    nvtop
    net-tools
    openssh-server
)

mkdir -p /tmp/packages
cd /tmp/packages

# Add repos
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg

# Download packages
apt-get update
apt-get download ${PACKAGES[@]} $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances ${PACKAGES[@]} | grep "^\w" | sort -u)

echo "Packages downloaded to /tmp/packages"
DLSCRIPT

chmod +x /work/iso-extract/p16-setup/download-packages.sh

# =============================================================================
section "Modifying Boot Configuration"
# =============================================================================

log "Updating GRUB configuration..."

# Modify grub.cfg for autoinstall option
if [ -f /work/iso-extract/boot/grub/grub.cfg ]; then
    # Add custom menu entry for P16 GPU Server install
    cat >> /work/iso-extract/boot/grub/grub.cfg << 'GRUBCFG'

# P16 GPU Server Installation Options
menuentry "P16 GPU Server - Interactive Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---
    initrd  /casper/initrd
}

menuentry "P16 GPU Server - Expert Install (Manual)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz ---
    initrd  /casper/initrd
}
GRUBCFG
    log "GRUB configuration updated"
fi

# Update isolinux for legacy BIOS boot
if [ -f /work/iso-extract/isolinux/txt.cfg ]; then
    cat >> /work/iso-extract/isolinux/txt.cfg << 'ISOLINUX'
label p16-auto
  menu label ^P16 GPU Server - Interactive Install
  kernel /casper/vmlinuz
  append initrd=/casper/initrd quiet autoinstall ds=nocloud;s=/cdrom/autoinstall/ ---
ISOLINUX
    log "ISOLINUX configuration updated"
fi

# =============================================================================
section "Rebuilding ISO"
# =============================================================================

log "Generating new ISO..."
cd /work/iso-extract

# Create new ISO with proper boot support
xorriso -as mkisofs \
    -r -V "P16-GPU-SERVER" \
    -o "/output/${OUTPUT_NAME}" \
    -J -joliet-long \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -partition_offset 16 \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    . 2>/dev/null || {
        # Fallback for different ISO structure
        log "Using alternative ISO generation method..."
        genisoimage -r -V "P16-GPU-SERVER" \
            -cache-inodes -J -l \
            -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -o "/output/${OUTPUT_NAME}" \
            .
    }

# =============================================================================
section "Build Complete"
# =============================================================================

ISO_SIZE=$(du -h "/output/${OUTPUT_NAME}" | cut -f1)
log "ISO created: ${OUTPUT_NAME} (${ISO_SIZE})"
log "Output location: /output/${OUTPUT_NAME}"

echo ""
echo "To write to USB drive:"
echo "  Linux:   sudo dd if=${OUTPUT_NAME} of=/dev/sdX bs=4M status=progress"
echo "  Windows: Use Rufus or balenaEtcher"
echo ""
