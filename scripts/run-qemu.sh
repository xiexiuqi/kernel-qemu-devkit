#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

KERNEL_DIR="${1:-${KERNEL_DIR:-$REPO_ROOT/../linux}}"
ROOTFS_IMG="${2:-${ROOTFS_IMG:-$REPO_ROOT/rootfs.img}}"
BZIMAGE="$KERNEL_DIR/arch/x86_64/boot/bzImage"

echo "Starting QEMU with Serial Console + Network (KVM mode)..."
echo "=========================================="
echo "Kernel: $BZIMAGE"
echo "Rootfs: $ROOTFS_IMG"
echo "Serial console: type directly in this terminal"
echo "Exit QEMU: Ctrl+A then X"
echo "GDB debug: gdb vmlinux -ex 'target remote localhost:1234'"
echo "=========================================="
echo ""

if [ ! -f "$BZIMAGE" ]; then
    echo "Error: Kernel image not found at $BZIMAGE"
    echo "Please compile the kernel first, or set KERNEL_DIR"
    exit 1
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    echo "Error: Rootfs image not found at $ROOTFS_IMG"
    echo "Please run ./scripts/prepare-rootfs.sh and ./scripts/mkrootfs-img.sh first"
    exit 1
fi

cd "$KERNEL_DIR"

qemu-system-x86_64 \
    -M pc-i440fx-8.2 \
    -kernel arch/x86_64/boot/bzImage \
    -append "console=ttyS0 root=/dev/vda rw panic=1 nokaslr loglevel=8 net.ifnames=0 biosdevname=0 init=/init" \
    -drive "file=$ROOTFS_IMG,format=raw,if=virtio" \
    -netdev "user,id=net0,hostfwd=tcp::2225-:22" \
    -device virtio-net-pci,netdev=net0 \
    -m 2G \
    -smp 8,cores=4,threads=2,sockets=1 \
    -object memory-backend-ram,id=ram0,size=1024M \
    -object memory-backend-ram,id=ram1,size=1024M \
    -numa node,nodeid=0,cpus=0-3,memdev=ram0 \
    -numa node,nodeid=1,cpus=4-7,memdev=ram1 \
    -cpu host \
    -enable-kvm \
    -serial mon:stdio

echo ""
echo "QEMU exited with code $?"