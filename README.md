# QEMU Kernel DevKit

A minimal, reproducible toolkit for compiling and running a custom Linux kernel with QEMU and BusyBox.

Supports **x86_64** and **aarch64 (ARM64)** architectures.

## Features

- One-key deployment with interactive prompts
- Prebuilt static busybox for x86_64 and aarch64 (zero dependency)
- Copy-paste kernel config templates
- Works with TCG (no KVM) and KVM modes
- AI-agent friendly (OpenCode / Cursor / Copilot)

## Quick Start (One Key Deploy)

```bash
git clone <your-repo-url> kernel-qemu-devkit
cd kernel-qemu-devkit
./deploy.sh
```

This interactive script will ask you for:
- Target architecture (`x86_64` or `aarch64`)
- Kernel source directory
- Boot mode (`tcg` or `kvm`)

Then it automatically does:
1. Generates rootfs directory with busybox
2. Creates `rootfs.img`
3. Applies kernel config template
4. Compiles the kernel
5. Offers to start QEMU immediately

## Directory Layout

```
.
├── deploy.sh                       ← One-key deploy script
├── configs/
│   ├── x86_64_defconfig.template   # x86_64 kernel config
│   └── arm64_defconfig.template    # aarch64 kernel config
├── docs/
│   ├── KERNEL_QEMU_GUIDE.md        # Full guide
│   └── AGENTS.md                   # AI assistant guidelines
├── prebuilt/
│   └── busybox/
│       ├── busybox-x86_64          # Prebuilt static busybox
│       └── busybox-aarch64         # Prebuilt static busybox
├── rootfs-template/
│   └── init                        # init script template
├── scripts/
│   ├── prepare-rootfs.sh           # Generate rootfs dir (supports --arch)
│   ├── mkrootfs-img.sh             # Pack rootfs into ext4 .img
│   ├── build-busybox.sh            # Build static busybox from source
│   ├── run-qemu-tcg.sh             # x86_64 TCG mode
│   ├── run-qemu.sh                 # x86_64 KVM mode
│   └── run-qemu-arm64.sh           # aarch64 TCG mode
├── .gitignore
├── LICENSE
└── README.md
```

## Manual Steps

If you prefer to run each step manually:

### 1. Generate Rootfs

**x86_64** (prebuilt busybox already included):

```bash
./scripts/prepare-rootfs.sh --arch x86_64
./scripts/mkrootfs-img.sh
```

**aarch64** (prebuilt busybox already included):

```bash
./scripts/prepare-rootfs.sh --arch aarch64
./scripts/mkrootfs-img.sh
```

If the prebuilt binary is incompatible with your environment, rebuild it:

```bash
# Install aarch64 cross compiler
sudo apt install gcc-aarch64-linux-gnu

# Build static busybox
./scripts/build-busybox.sh aarch64
```

### 2. Prepare Kernel

```bash
cd /path/to/linux

# x86_64
make x86_64_defconfig
cat ../kernel-qemu-devkit/configs/x86_64_defconfig.template >> .config
make oldconfig
make -j$(($(nproc)-2))

# aarch64
make ARCH=arm64 defconfig
cat ../kernel-qemu-devkit/configs/arm64_defconfig.template >> .config
make ARCH=arm64 oldconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
```

### 3. Run QEMU

```bash
cd /path/to/kernel-qemu-devkit

# x86_64 TCG
./scripts/run-qemu-tcg.sh /path/to/linux /path/to/rootfs.img

# x86_64 KVM
./scripts/run-qemu.sh /path/to/linux /path/to/rootfs.img

# aarch64 TCG
./scripts/run-qemu-arm64.sh /path/to/linux /path/to/rootfs.img
```

Inside the VM shell, try:

```sh
/ # ls /proc/
/ # uname -a
/ # cat /proc/cpuinfo
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `proc/` is empty | Missing `init=/init` in kernel cmdline | Already included in all run scripts |
| `No static busybox found` | Prebuilt binary missing | Run `./scripts/build-busybox.sh x86_64` or copy one to `prebuilt/busybox/` |
| `busybox-aarch64` incompatible | Prebuilt binary built on different toolchain | Install cross compiler and run `./scripts/build-busybox.sh aarch64` |
| `KVM permission denied` | No KVM access | Use `run-qemu-tcg.sh` or add user to `kvm` group |
| virtio disk not found | Missing `CONFIG_VIRTIO_BLK` | Copy config template into kernel `.config` |

## AI Agent / OpenCode Support

This repository includes an `AGENTS.md` file with:
- Build commands for single module and full kernel
- Code style guidelines (tabs, 80 chars, K&R style)
- Kernel-specific conventions (kmalloc, IS_ERR/PTR_ERR, EXPORT_SYMBOL_GPL)
- QEMU shortcuts and debugging workflows

Point your AI assistant to `docs/AGENTS.md` before making kernel changes.

## BusyBox Binary Policy

- `busybox-x86_64` (~1.1MB): **Prebuilt static binary included** for out-of-the-box x86_64 usage
- `busybox-aarch64` (~2.2MB): **Prebuilt static binary included** for out-of-the-box aarch64 usage. If you encounter compatibility issues with your cross-compilation environment, rebuild it via `scripts/build-busybox.sh aarch64`.
- `rootfs.img` (128MB): **Do not commit to git**. Generated locally via `mkrootfs-img.sh`.

## License

MIT
