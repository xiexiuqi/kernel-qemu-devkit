#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ROOTFS_DIR="${1:-$REPO_ROOT/rootfs}"
OUTPUT_IMG="${2:-$REPO_ROOT/rootfs.img}"
SIZE_MB="${3:-128}"
MOUNT_POINT="/tmp/kernel-qemu-rootfs-$$"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: Rootfs directory not found: $ROOTFS_DIR"
    echo "Run ./scripts/prepare-rootfs.sh first"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Note: mkfs.ext4 and mount may require sudo. Retrying with sudo..."
    exec sudo "$0" "$@"
fi

echo "=== Creating rootfs image ==="
echo "Source:  $ROOTFS_DIR"
echo "Output:  $OUTPUT_IMG"
echo "Size:    ${SIZE_MB}MB"

rm -f "$OUTPUT_IMG"
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count="$SIZE_MB" status=progress
mkfs.ext4 -F "$OUTPUT_IMG"

mkdir -p "$MOUNT_POINT"
mount -o loop "$OUTPUT_IMG" "$MOUNT_POINT"

cp -r "$ROOTFS_DIR"/* "$MOUNT_POINT/"

umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT" 2>/dev/null || true

echo "=== Done: $OUTPUT_IMG ==="