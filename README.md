# QEMU Kernel DevKit

A minimal, reproducible toolkit for compiling and running a custom Linux kernel with QEMU and BusyBox.

## What is this?

This repo provides everything you need to go from a kernel source tree to a running QEMU VM with a BusyBox rootfs.

- No dependency on a specific kernel repository
- Modular, copy-paste friendly config templates
- Works with TCG (no KVM) and KVM modes

## Directory Layout

```
.
├── configs/
│   └── x86_64_defconfig.template   # Kernel config template with required options
├── docs/
│   ├── KERNEL_QEMU_GUIDE.md        # Full guide and troubleshooting
│   └── AGENTS.md                   # Agent coding assistant guidelines
├── rootfs-template/
│   └── init                        # Minimal init script template
├── scripts/
│   ├── prepare-rootfs.sh           # Generate rootfs directory
│   ├── mkrootfs-img.sh             # Pack rootfs into ext4 .img
│   ├── run-qemu-tcg.sh             # Run with TCG (no KVM)
│   └── run-qemu.sh                 # Run with KVM
├── .gitignore
├── LICENSE
└── README.md
```

## Quick Start

### 1. Prepare BusyBox

You need a **statically-linked** `busybox` binary. Choose one of:

```bash
# Option A: Use system package (Debian/Ubuntu)
sudo apt install busybox-static

# Option B: Download manually from https://busybox.net/downloads/binaries/
# and copy it into this repo root:
cp busybox-x86_64 ./busybox
```

### 2. Generate Rootfs

```bash
# Create rootfs/ directory
./scripts/prepare-rootfs.sh

# Create rootfs.img (requires sudo for mount)
./scripts/mkrootfs-img.sh
```

### 3. Prepare Kernel

Place your kernel source next to this repo (or anywhere), then apply the config template:

```bash
cd /path/to/linux
make x86_64_defconfig
cat ../kernel-qemu-devkit/configs/x86_64_defconfig.template >> .config
make oldconfig
make -j$(($(nproc)-2))
```

### 4. Run QEMU

```bash
cd /path/to/kernel-qemu-devkit

# TCG mode (works everywhere)
./scripts/run-qemu-tcg.sh

# Or KVM mode (requires /dev/kvm)
./scripts/run-qemu.sh
```

Inside the VM shell, try:

```sh
/ # ls /proc/
/ # uname -a
```

## Environment Variables

Both `run-qemu-*.sh` scripts accept arguments or env variables:

```bash
# Explicit paths
./scripts/run-qemu-tcg.sh /path/to/linux /path/to/rootfs.img

# Or via env
KERNEL_DIR=/path/to/linux ROOTFS_IMG=/path/to/rootfs.img ./scripts/run-qemu-tcg.sh
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `proc/` is empty | `init=/init` missing from kernel cmdline | Already included in run scripts |
| `No static busybox found` | No pre-installed static busybox | `apt install busybox-static` or place `busybox` in repo root |
| `KVM permission denied` | User not in `kvm` group or no hardware virt | Use `run-qemu-tcg.sh` instead |
| virtio disk not found | `CONFIG_VIRTIO_BLK` missing | Copy `.config.template` into kernel config |
| No serial output | `CONFIG_SERIAL_8250_CONSOLE` missing | Same as above |

## Binary Files Policy

- `busybox` (~1MB): Put it in repo root or let the system provide it
- `rootfs.img` (128MB): **Do not commit to git**. Use `mkrootfs-img.sh` to generate it locally, or attach it to a GitHub Release

## License

MIT
