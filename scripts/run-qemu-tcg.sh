#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

KERNEL_DIR="${1:-${KERNEL_DIR:-$REPO_ROOT/../linux}}"
ROOTFS_IMG="${2:-${ROOTFS_IMG:-$REPO_ROOT/rootfs.img}}"
BZIMAGE="$KERNEL_DIR/arch/x86_64/boot/bzImage"

echo "Starting QEMU with Serial Console + Network (TCG mode, no KVM)..."
echo "=========================================="
echo "Kernel: $BZIMAGE"
echo "Rootfs: $ROOTFS_IMG"
echo "Serial console: type directly in this terminal"
echo "Exit QEMU: Ctrl+A then X"
echo "=========================================="
echo ""

if [ ! -f "$BZIMAGE" ]; then
    echo "Error: Kernel image not found at $BZIMAGE"
    echo "Please compile the kernel first, or set KERNEL_DIR:"
    echo "  KERNEL_DIR=/path/to/kernel ./scripts/run-qemu-tcg.sh"
    exit 1
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    echo "Error: Rootfs image not found at $ROOTFS_IMG"
    echo "Please run ./scripts/prepare-rootfs.sh first, or set ROOTFS_IMG"
    exit 1
fi

cd "$KERNEL_DIR"

qemu-system-x86_64 \
    -M pc-i440fx-8.2 \
    -kernel arch/x86_64/boot/bzImage \
    -append "console=ttyS0 root=/dev/vda rw panic=1 nokaslr loglevel=8 net.ifnames=0 biosdevname=0 init=/init" \
    -drive "file=$ROOTFS_IMG,format=raw,if=virtio" \
    -netdev "user,id=net0,hostfwd=tcp::2222-:22" \
    -device virtio-net-pci,netdev=net0 \
    -m 2G \
    -smp 2 \
    -serial mon:stdio \
    -no-reboot \
    -display none

echo ""
echo "QEMU exited with code $?"