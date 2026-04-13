#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ARCH="${1:-x86_64}"
BUILD_DIR="${REPO_ROOT}/prebuilt/busybox-src"
INSTALL_DIR="${REPO_ROOT}/prebuilt/busybox"
JOBS="$(nproc)"

if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

CROSS_COMPILE=""
if [ "$ARCH" = "aarch64" ]; then
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="aarch64-linux-gnu-"
    elif command -v aarch64-linux-musl-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="aarch64-linux-musl-"
    else
        echo "ERROR: No aarch64 cross compiler found."
        echo "Please install one of:"
        echo "  sudo apt install gcc-aarch64-linux-gnu"
        echo "  sudo dnf install gcc-aarch64-linux-gnu"
        exit 1
    fi
fi

mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
cd "$BUILD_DIR"

if [ ! -d "busybox-1.36.1" ]; then
    echo "Downloading BusyBox source..."
    if [ ! -f "busybox-1.36.1.tar.bz2" ]; then
        curl -L -o busybox-1.36.1.tar.bz2 https://busybox.net/downloads/busybox-1.36.1.tar.bz2
    fi
    tar -xjf busybox-1.36.1.tar.bz2
fi

cd busybox-1.36.1

make defconfig
sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config
sed -i 's/.*CONFIG_TC=.*/CONFIG_TC=n/' .config
yes "" | make oldconfig CROSS_COMPILE="$CROSS_COMPILE" >/dev/null 2>&1 || true
make -j"$JOBS" CROSS_COMPILE="$CROSS_COMPILE" EXTRA_CFLAGS="-DLONG_BIT=64" EXTRA_LDFLAGS="--sysroot=/usr/aarch64-redhat-linux/sys-root/fc43"
cp busybox "$INSTALL_DIR/busybox-$ARCH"
chmod +x "$INSTALL_DIR/busybox-$ARCH"

echo ""
echo "=== Build complete: $INSTALL_DIR/busybox-$ARCH ==="
file "$INSTALL_DIR/busybox-$ARCH"