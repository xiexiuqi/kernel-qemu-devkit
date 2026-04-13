#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KERNEL_DIR="${1:-${KERNEL_DIR:-$REPO_ROOT/../linux}}"
ROOTFS_IMG="${2:-${ROOTFS_IMG:-$REPO_ROOT/rootfs-arm64.img}}"
IMAGE="$KERNEL_DIR/arch/arm64/boot/Image"

echo "Starting QEMU aarch64 with Serial Console + Network (TCG mode)..."
echo "=========================================="
echo "Kernel: $IMAGE"
echo "Rootfs: $ROOTFS_IMG"
echo "Exit QEMU: Ctrl+A then X"
echo "=========================================="
echo ""

if [ ! -f "$IMAGE" ]; then
    echo "Error: Kernel image not found at $IMAGE"
    echo "Please compile the kernel first, or set KERNEL_DIR"
    exit 1
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    echo "Error: Rootfs image not found at $ROOTFS_IMG"
    echo "Please run ./scripts/prepare-rootfs.sh and ./scripts/mkrootfs-img.sh first"
    exit 1
fi

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -kernel "$IMAGE" \
    -append "console=ttyAMA0 root=/dev/vda rw panic=1 nokaslr loglevel=8 net.ifnames=0 biosdevname=0 init=/init" \
    -drive "file=$ROOTFS_IMG,format=raw,if=virtio" \
    -netdev "user,id=net0,hostfwd=tcp::2227-:22" \
    -device virtio-net-pci,netdev=net0 \
    -m 2G \
    -smp 2 \
    -serial mon:stdio \
    -no-reboot \
    -display none

echo ""
echo "QEMU exited with code $?"