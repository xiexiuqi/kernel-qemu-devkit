#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ARCH="x86_64"
KERNEL_DIR=""
ROOTFS_DIR="$REPO_ROOT/rootfs"
ROOTFS_IMG="$REPO_ROOT/rootfs.img"
BOOT_MODE="tcg"
AUTO_RUN="yes"

ask() {
    local prompt="$1"
    local default="$2"
    local result
    read -rp "$prompt [$default]: " result
    echo "${result:-$default}"
}

echo "=========================================="
echo "  QEMU Kernel DevKit - One-Key Deploy"
echo "=========================================="
echo ""

ARCH=$(ask "Target architecture (x86_64 / aarch64)" "$ARCH")
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

DEFAULT_KERNEL=""
if [ -d "$REPO_ROOT/../linux" ]; then
    DEFAULT_KERNEL="$REPO_ROOT/../linux"
elif [ -d "$HOME/linux" ]; then
    DEFAULT_KERNEL="$HOME/linux"
fi

KERNEL_DIR=$(ask "Kernel source directory" "${DEFAULT_KERNEL:-}")
if [ -z "$KERNEL_DIR" ] || [ ! -d "$KERNEL_DIR" ]; then
    echo "Error: Kernel directory not found: $KERNEL_DIR"
    echo "Please clone a kernel first:"
    echo "  git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ~/linux"
    exit 1
fi
KERNEL_DIR="$(cd "$KERNEL_DIR" && pwd)"

BOOT_MODE=$(ask "Boot mode (tcg / kvm)" "$BOOT_MODE")
if [[ "$BOOT_MODE" != "tcg" && "$BOOT_MODE" != "kvm" ]]; then
    echo "Unsupported boot mode: $BOOT_MODE"
    exit 1
fi

if [ "$BOOT_MODE" = "kvm" ] && [ "$ARCH" = "aarch64" ]; then
    echo "WARNING: KVM on aarch64 requires compatible host. Falling back to tcg recommended."
    BOOT_MODE=$(ask "Confirm boot mode (tcg / kvm)" "tcg")
fi

echo ""
echo "=== Configuration Summary ==="
echo "Architecture: $ARCH"
echo "Kernel dir:   $KERNEL_DIR"
echo "Rootfs dir:   $ROOTFS_DIR"
echo "Rootfs img:   $ROOTFS_IMG"
echo "Boot mode:    $BOOT_MODE"
echo ""

read -rp "Press Enter to continue, or Ctrl+C to cancel..."
echo ""

echo "[1/4] Preparing rootfs..."
if [ ! -f "$REPO_ROOT/prebuilt/busybox/busybox-$ARCH" ]; then
    echo "  Prebuilt busybox-$ARCH not found."
    if [ "$ARCH" = "x86_64" ]; then
        echo "  Attempting to find system busybox..."
    fi
fi
"$REPO_ROOT/scripts/prepare-rootfs.sh" --arch "$ARCH" "$ROOTFS_DIR"

echo "[2/4] Creating rootfs.img..."
"$REPO_ROOT/scripts/mkrootfs-img.sh" "$ROOTFS_DIR" "$ROOTFS_IMG" 128

echo "[3/4] Preparing kernel config..."
cd "$KERNEL_DIR"

if [ ! -f .config ]; then
    if [ "$ARCH" = "x86_64" ]; then
        make x86_64_defconfig
    else
        make ARCH=arm64 defconfig
    fi
fi

cat "$REPO_ROOT/configs/${ARCH}_defconfig.template" >> .config
if [ "$ARCH" = "aarch64" ]; then
    make ARCH=arm64 oldconfig
else
    make oldconfig
fi

echo "[4/4] Building kernel..."
if [ "$ARCH" = "aarch64" ]; then
    make -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- 2>&1 | tee build.log
else
    make -j"$(nproc)" CC="ccache gcc" 2>&1 | tee build.log
fi

if [ "$ARCH" = "aarch64" ]; then
    IMAGE="$KERNEL_DIR/arch/arm64/boot/Image"
else
    IMAGE="$KERNEL_DIR/arch/x86_64/boot/bzImage"
fi

if [ ! -f "$IMAGE" ]; then
    echo "ERROR: Kernel build failed. Image not found: $IMAGE"
    exit 1
fi

echo ""
echo "=========================================="
echo "  Build Success!"
echo "=========================================="
echo "Kernel: $IMAGE"
echo "Rootfs: $ROOTFS_IMG"
echo ""
echo "To start QEMU, run:"
echo ""
if [ "$ARCH" = "aarch64" ]; then
    echo "  KERNEL_DIR=$KERNEL_DIR ROOTFS_IMG=$ROOTFS_IMG $REPO_ROOT/scripts/run-qemu-arm64.sh"
else
    if [ "$BOOT_MODE" = "kvm" ]; then
        echo "  KERNEL_DIR=$KERNEL_DIR ROOTFS_IMG=$ROOTFS_IMG $REPO_ROOT/scripts/run-qemu.sh"
    else
        echo "  KERNEL_DIR=$KERNEL_DIR ROOTFS_IMG=$ROOTFS_IMG $REPO_ROOT/scripts/run-qemu-tcg.sh"
    fi
fi
echo ""

AUTO_RUN=$(ask "Start QEMU now? (yes / no)" "$AUTO_RUN")
if [ "$AUTO_RUN" = "yes" ] || [ "$AUTO_RUN" = "y" ]; then
    echo ""
    echo "Starting QEMU..."
    if [ "$ARCH" = "aarch64" ]; then
        KERNEL_DIR="$KERNEL_DIR" ROOTFS_IMG="$ROOTFS_IMG" "$REPO_ROOT/scripts/run-qemu-arm64.sh"
    else
        if [ "$BOOT_MODE" = "kvm" ]; then
            KERNEL_DIR="$KERNEL_DIR" ROOTFS_IMG="$ROOTFS_IMG" "$REPO_ROOT/scripts/run-qemu.sh"
        else
            KERNEL_DIR="$KERNEL_DIR" ROOTFS_IMG="$ROOTFS_IMG" "$REPO_ROOT/scripts/run-qemu-tcg.sh"
        fi
    fi
fi