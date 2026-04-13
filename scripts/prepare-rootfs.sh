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

echo "Creating busybox symlinks..."
BB_LIST_HELPER="./busybox"
if ! ./busybox --list >/dev/null 2>&1; then
    BB_LIST_HELPER="$REPO_ROOT/prebuilt/busybox/busybox-x86_64"
    if [ ! -x "$BB_LIST_HELPER" ]; then
        BB_LIST_HELPER="$(command -v busybox 2>/dev/null || true)"
    fi
fi
for cmd in $("$BB_LIST_HELPER" --list); do
    dir="bin"
    case "$cmd" in
        fdisk|fsck|halt|init|insmod|klogd|losetup|lsmod|modprobe|poweroff|reboot|rmmod|route|swapon|swapoff|sysctl|syslogd|tune2fs|udhcpd|vconfig)
            dir="sbin" ;;
        *)
            dir="bin" ;;
    esac
    ln -sf /busybox "$dir/$cmd" 2>/dev/null || true
    if [ "$dir" = "bin" ]; then
        ln -sf /busybox "usr/bin/$cmd" 2>/dev/null || true
    else
        ln -sf /busybox "usr/sbin/$cmd" 2>/dev/null || true
    fi
done
ln -sf /busybox bin/busybox 2>/dev/null || true

cat > init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t tmpfs none /tmp
# devtmpfs is auto-mounted by kernel; fallback here just in case
mount -t devtmpfs none /dev 2>/dev/null || true

# Basic network setup
ip link set lo up 2>/dev/null || true
ip link set eth0 up 2>/dev/null || true
udhcpc -i eth0 2>/dev/null || true

echo ""
echo "========================================"
echo "  Welcome to QEMU Kernel DevKit"
echo "========================================"
echo ""
echo "Basic commands: ls, cat, ps, dmesg, free, grep, awk, sed, vi, wget, ping"
echo "Hardware info:  lscpu, lsblk, lspci, lsusb"
echo ""

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
devtmpfs /dev   devtmpfs defaults   0   0
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

cat > bin/lscpu << 'EOF'
#!/bin/sh
# Minimal lscpu wrapper
echo "Architecture:        $(uname -m)"
echo "CPU op-mode(s):      32-bit, 64-bit"
echo "Model name:          $(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ *//')"
echo "CPU(s):              $(grep -c '^processor' /proc/cpuinfo)"
awk '/^vendor_id|^cpu family|^model|^stepping|^cpu MHz|^cache size|^physical id|^siblings|^core id|^cpu cores|^apicid|^initial apicid|^fpu|^flags|^bogomips/{printf "%-20s %s\n", $1, substr($0,index($0,$2))}' /proc/cpuinfo
EOF
chmod +x bin/lscpu

cat > bin/lsblk << 'EOF'
#!/bin/sh
# Minimal lsblk wrapper
printf "NAME  MAJ:MIN  RM  SIZE  RO  TYPE  MOUNTPOINT\n"
for dev in /sys/block/*; do
    [ -d "$dev" ] || continue
    name=$(basename "$dev")
    case "$name" in
        loop*) continue ;;
    esac
    major=$(cat "$dev/dev" 2>/dev/null | cut -d: -f1)
    minor=$(cat "$dev/dev" 2>/dev/null | cut -d: -f2)
    size=$(awk "BEGIN {printf \"%.0fM\", $(cat $dev/size 2>/dev/null || echo 0)*512/1024/1024}")
    ro=$(cat "$dev/ro" 2>/dev/null || echo 0)
    mp=""
    if [ -r /proc/mounts ]; then
        mp=$(awk -v d="/dev/$name" '$1==d{print $2; exit}' /proc/mounts)
    fi
    printf "%-5s %3s:%-3s  %2s  %5s  %2s  %-4s  %s\n" "$name" "$major" "$minor" "0" "$size" "$ro" "disk" "$mp"
done
EOF
chmod +x bin/lsblk

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
