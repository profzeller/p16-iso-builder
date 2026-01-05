FROM ubuntu:24.04

LABEL maintainer="profzeller"
LABEL description="P16 GPU Server ISO Builder"

ENV DEBIAN_FRONTEND=noninteractive

# Install ISO building tools
RUN apt-get update && apt-get install -y \
    p7zip-full \
    xorriso \
    isolinux \
    syslinux-utils \
    wget \
    curl \
    gpg \
    squashfs-tools \
    genisoimage \
    rsync \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /work /output /cache

WORKDIR /work

# Copy build scripts
COPY scripts/ /scripts/
COPY autoinstall/ /autoinstall/
COPY files/ /files/

RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/customize-iso.sh"]
