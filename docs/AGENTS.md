# AGENTS.md - Linux Kernel Development Workspace

## Overview
This is a Linux kernel development workspace using WSL2 + QEMU x86_64. The kernel source is expected at `~/git/kernel/`.

## Build Commands

### Full Kernel Build
```bash
cd ~/git/kernel
make -j$(($(nproc))) CC="ccache gcc" 2>&1 | tee build.log
```

### Build with Reserved Cores (recommended)
```bash
cd ~/git/kernel
make -j$(($(nproc)-2)) CC="ccache gcc"
```

### Build Single Module
```bash
cd ~/git/kernel
make M=drivers/char/mydev CC="ccache gcc"
```

### Clean Build
```bash
make clean
make mrproper  # Full clean including config
```

## Configuration
```bash
make menuconfig           # Interactive config
make oldconfig            # Update config for new options
make defconfig            # Default config
make x86_64_defconfig     # x86_64 specific defaults
```

## Test Commands

### Run QEMU (Full System)
```bash
cd ~/kernel-work
./run-qemu.sh
```

### Manual QEMU Launch
```bash
cd ~/git/kernel
qemu-system-x86_64 \
    -M pc-i440fx-8.2 \
    -kernel arch/x86_64/boot/bzImage \
    -append "console=ttyS0 root=/dev/vda rw panic=1 nokaslr" \
    -drive file=~/kernel-work/rootfs.img,format=raw,if=virtio \
    -m 2G -smp 2 -cpu host -enable-kvm \
    -serial mon:stdio
```

### GDB Debugging
```bash
# Terminal 1: Start QEMU with debug flags
cd ~/git/kernel
qemu-system-x86_64 ... -S -s

# Terminal 2: Connect GDB
gdb vmlinux -ex "target remote localhost:1234"
```

## Code Style Guidelines

### Formatting
- **Indentation**: Tabs (8 spaces width), not spaces
- **Line Width**: 80 characters maximum
- **Braces**: Opening brace on same line (K&R style)
- **Spacing**: Space after keywords (if, while, for), not after function calls

### Naming Conventions
- Functions: `lowercase_with_underscores`
- Macros: `UPPERCASE_WITH_UNDERSCORES`
- Constants: `UPPERCASE_WITH_UNDERSCORES`
- Structs: `lowercase_with_underscores`
- Typedefs: Avoid; use `struct foo` directly

### Headers
```c
#include <linux/module.h>      /* Kernel headers use <> */
#include <linux/kernel.h>
#include <linux/slab.h>
```

### Memory Management
- Use `kmalloc/kzalloc` for small allocations
- Use `vmalloc` for large allocations
- Always check: `if (!ptr) return -ENOMEM;`
- Free with `kfree` / `vfree`
- NEVER use malloc/free

### Error Handling
```c
struct foo *ptr = kzalloc(sizeof(*ptr), GFP_KERNEL);
if (!ptr)
    return -ENOMEM;

/* For functions returning pointers */
struct file *f = filp_open(...);
if (IS_ERR(f))
    return PTR_ERR(f);
```

### Exporting Symbols
```c
EXPORT_SYMBOL_GPL(my_function);  /* Prefer GPL */
```

### Module Template
```c
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init mymod_init(void)
{
    pr_info("Module loaded\n");
    return 0;
}

static void __exit mymod_exit(void)
{
    pr_info("Module unloaded\n");
}

module_init(mymod_init);
module_exit(mymod_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Description");
```

## Important Conventions

### Path Rules
- Use Linux paths: `/home/user/...`
- Never Windows paths: `C:\...`

### QEMU Shortcuts
- `Ctrl+A C`: Switch to QEMU monitor
- `Ctrl+A X`: Exit QEMU
- Serial console: Direct terminal input
- SSH: `ssh -p 2222 root@localhost`

### Build Artifacts
- Kernel image: `arch/x86_64/boot/bzImage`
- vmlinux: `vmlinux` (with debug symbols)
- Modules: `lib/modules/` in rootfs

### Version Control
- Use `git format-patch` for patches
- Follow commit message conventions
- Sign-off: `git commit -s`
