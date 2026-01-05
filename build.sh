#!/bin/bash
# =============================================================================
# P16 GPU Server ISO Builder
# Creates custom Ubuntu Server 24.04 ISO with NVIDIA drivers and Docker
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
CACHE_DIR="${SCRIPT_DIR}/cache"
OUTPUT_NAME="p16-gpu-server-24.04.iso"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --output NAME    Output ISO filename (default: p16-gpu-server-24.04.iso)"
            echo "  --no-cache       Don't use cached Ubuntu ISO"
            echo "  --verbose        Show detailed output"
            echo "  --help           Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# =============================================================================
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                    P16 GPU Server ISO Builder                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
# =============================================================================

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is required but not installed"
fi

# Create directories
mkdir -p "${OUTPUT_DIR}" "${CACHE_DIR}"

# Clean cache if requested
if [ -n "$NO_CACHE" ]; then
    log "Clearing cache..."
    rm -rf "${CACHE_DIR}"/*
fi

# Build Docker image
log "Building ISO builder image..."
docker build -t p16-iso-builder:latest "${SCRIPT_DIR}" ${VERBOSE:+--progress=plain}

# Run the builder
log "Starting ISO customization..."
docker run --rm \
    -v "${OUTPUT_DIR}:/output" \
    -v "${CACHE_DIR}:/cache" \
    -e OUTPUT_NAME="${OUTPUT_NAME}" \
    ${VERBOSE:+-e VERBOSE=1} \
    p16-iso-builder:latest

# Verify output
if [ -f "${OUTPUT_DIR}/${OUTPUT_NAME}" ]; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                         BUILD SUCCESSFUL                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log "ISO created: ${OUTPUT_DIR}/${OUTPUT_NAME}"
    log "Size: $(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1)"
    echo ""
    echo "Next steps:"
    echo "  1. Write ISO to USB: Use Rufus (Windows) or dd (Linux)"
    echo "  2. Boot from USB on target P16 laptop"
    echo "  3. Select 'P16 GPU Server - Interactive Install'"
    echo ""
else
    error "ISO build failed - output file not found"
fi
