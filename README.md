# P16 GPU Server ISO Builder

Docker-based tool to create custom Ubuntu Server 24.04 LTS ISOs for P16 GPU servers.

## Features

- Ubuntu Server 24.04 LTS base
- NVIDIA drivers (550) and Container Toolkit via server-setup
- Docker with GPU support and UFW firewall integration
- Auto-boots to `server-setup` menu on first login
- UFW firewall properly controls Docker container traffic
- Unattended installation option

## Quick Start

```bash
# Build the ISO
./build.sh

# Output: output/p16-gpu-server-24.04.iso
```

## Requirements

- Docker with 10GB+ free space
- Internet connection (downloads Ubuntu ISO)
- ~30 minutes build time

## What's Included

| Component | Version | Notes |
|-----------|---------|-------|
| Ubuntu Server | 24.04 LTS | Latest kernel |
| NVIDIA Driver | 550 | Installed via server-setup |
| NVIDIA Container Toolkit | Latest | For Docker GPU |
| Docker CE | Latest | With UFW integration |
| server-setup | Latest | Auto-starts on login |

### Security Features

- **UFW Firewall** - Configured to control all traffic including Docker
- **Docker UFW Integration** - Docker containers properly controlled by firewall rules
- **SSH Hardening** - Secure SSH configuration out of the box

## Installation Options

### Option 1: Interactive Install

Boot from ISO and follow prompts. After install:
- System auto-boots to `server-setup` menu
- Run through configuration wizard

### Option 2: Unattended Install

For automated deployments, the ISO includes autoinstall support:

```bash
# Boot with kernel parameter:
autoinstall ds=nocloud;s=/cdrom/autoinstall/
```

Default credentials (change immediately):
- Username: `admin`
- Password: `gpu-server`

## Customization

### Change Default User

Edit `autoinstall/user-data`:

```yaml
identity:
  hostname: gpu-server-01
  username: admin
  password: <your-hashed-password>
```

Generate password hash:
```bash
openssl passwd -6 'your-password'
```

### Add Custom Packages

Edit `scripts/customize-iso.sh` to add packages to the `PACKAGES` array.

### Change NVIDIA Driver Version

Edit `scripts/customize-iso.sh`:
```bash
NVIDIA_DRIVER="nvidia-driver-560"
```

## Build Options

```bash
# Standard build
./build.sh

# Custom output name
./build.sh --output my-server.iso

# Skip cache (re-download Ubuntu ISO)
./build.sh --no-cache

# Verbose output
./build.sh --verbose
```

## Directory Structure

```
p16-iso-builder/
├── build.sh              # Main build script
├── Dockerfile            # Build environment
├── docker-compose.yml    # Docker config
├── autoinstall/
│   ├── user-data         # Autoinstall config
│   └── meta-data         # Cloud-init metadata
├── scripts/
│   └── customize-iso.sh  # ISO customization
├── files/
│   └── server-setup      # Setup utility (downloaded)
└── output/               # Built ISOs
```

## Troubleshooting

### Build fails with "no space left"

Increase Docker disk space or clean old images:
```bash
docker system prune -a
```

### ISO won't boot

Verify the ISO checksum and try re-burning to USB with:
```bash
# Linux
sudo dd if=output/p16-gpu-server-24.04.iso of=/dev/sdX bs=4M status=progress

# Windows - use Rufus or balenaEtcher
```

### NVIDIA driver issues post-install

Run `server-setup` → NVIDIA Stack → Reinstall drivers

## License

MIT
