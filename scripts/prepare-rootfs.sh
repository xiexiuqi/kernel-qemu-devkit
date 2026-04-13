#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ARCH="x86_64"
ROOTFS_DIR="$REPO_ROOT/rootfs"

usage() {
    echo "Usage: $0 [--arch x86_64|aarch64] [rootfs-dir]"
    echo ""
    echo "Options:"
    echo "  --arch    Target architecture (default: x86_64)"
    echo ""
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            ROOTFS_DIR="$1"
            shift
            ;;
    esac
done

if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo "Unsupported architecture: $ARCH"
    echo "Supported: x86_64, aarch64"
    exit 1
fi

BUSYBOX_NAME="busybox-$ARCH"
BUSYBOX_SRC=""

echo "=== Creating $ARCH rootfs at: $ROOTFS_DIR ==="

mkdir -p "$ROOTFS_DIR"/{bin,sbin,etc/init.d,proc,sys,dev,tmp,lib,lib64,usr/{bin,sbin},root}

find_busybox() {
    if [ -f "$REPO_ROOT/prebuilt/busybox/$BUSYBOX_NAME" ]; then
        BUSYBOX_SRC="$REPO_ROOT/prebuilt/busybox/$BUSYBOX_NAME"
        return 0
    fi
    if [ -f "$REPO_ROOT/$BUSYBOX_NAME" ]; then
        BUSYBOX_SRC="$REPO_ROOT/$BUSYBOX_NAME"
        return 0
    fi
    if [ -f "$ROOTFS_DIR/busybox" ]; then
        BUSYBOX_SRC="$ROOTFS_DIR/busybox"
        return 0
    fi
    if [ "$ARCH" = "x86_64" ] && command -v busybox >/dev/null 2>&1; then
        local sys_bb
        sys_bb="$(command -v busybox)"
        if ldd "$sys_bb" 2>/dev/null | grep -q 'not a dynamic executable'; then
            BUSYBOX_SRC="$sys_bb"
            return 0
        fi
    fi
    return 1
}

if find_busybox; then
    echo "Found busybox at: $BUSYBOX_SRC"
    cp "$BUSYBOX_SRC" "$ROOTFS_DIR/busybox"
    chmod +x "$ROOTFS_DIR/busybox"
else
    echo "WARNING: No static busybox found for architecture: $ARCH"
    echo ""
    echo "Please provide a static busybox binary by one of:"
    echo "  1. Copy busybox to this repo root:  cp /path/to/$BUSYBOX_NAME $REPO_ROOT/prebuilt/busybox/"
    echo "  2. Download from: https://busybox.net/downloads/binaries/"
    echo "  3. Install system busybox-static and rerun (x86_64 only):"
    echo "     sudo apt install busybox-static   # Debian/Ubuntu"
    echo "     sudo dnf install busybox          # openEuler/Fedora"
    echo "  4. Build from source:"
    echo "     ./scripts/build-busybox.sh $ARCH"
    echo ""
    exit 1
fi

cd "$ROOTFS_DIR"

for cmd in sh ls cat cp mv rm mkdir rmdir ps kill mount umount echo pwd chmod chown; do
    ln -sf /busybox "bin/$cmd" 2>/dev/null || true
done

cat > init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Hello from custom kernel!"
exec /bin/sh
EOF
chmod +x init

cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

cat > etc/group << 'EOF'
root:x:0:
EOF

cat > etc/hosts << 'EOF'
127.0.0.1 localhost
EOF

cat > etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 114.114.114.114
EOF

cat > etc/fstab << 'EOF'
proc    /proc   proc    defaults    0   0
sysfs   /sys    sysfs   defaults    0   0
tmpfs   /tmp    tmpfs   defaults    0   0
EOF

cat > etc/inittab << 'EOF'
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
EOF

cat > etc/init.d/rcS << 'EOF'
#!/bin/sh
mount -a
EOF
chmod +x etc/init.d/rcS

mknod dev/null c 1 3 2>/dev/null || true
mknod dev/zero c 1 5 2>/dev/null || true
mknod dev/random c 1 8 2>/dev/null || true
mknod dev/urandom c 1 9 2>/dev/null || true
mknod dev/tty c 5 0 2>/dev/null || true
mknod dev/console c 5 1 2>/dev/null || true

if [ "$ARCH" = "x86_64" ]; then
    mknod dev/ttyS0 c 4 64 2>/dev/null || true
else
    mknod dev/ttyAMA0 c 204 64 2>/dev/null || true
fi

cd - > /dev/null

echo ""
echo "=== $ARCH rootfs directory ready: $ROOTFS_DIR ==="
echo ""
echo "Next steps:"
echo "  1. Create disk image:   ./scripts/mkrootfs-img.sh $ROOTFS_DIR"
echo "  2. Or create cpio:      cd $ROOTFS_DIR && find . | cpio -o -H newc | gzip -9 > ../rootfs.cpio.gz"