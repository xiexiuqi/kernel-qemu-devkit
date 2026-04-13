# Linux 内核 + QEMU + BusyBox 启动指南

## 概述
在 WSL2/QEMU x86_64 环境中编译和运行自定义 Linux 内核。

## 必备 Kernel Config

### 1. VirtIO 支持（QEMU 必需）
```
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_PCI_LEGACY=y
CONFIG_VIRTIO_BLK=y          # 磁盘支持
CONFIG_VIRTIO_NET=y          # 网络支持
CONFIG_VIRTIO_CONSOLE=y      # 控制台
CONFIG_VIRTIO_BALLOON=y      # 内存气球（可选）
CONFIG_VIRTIO_INPUT=y        # 输入设备（可选）
CONFIG_VIRTIO_MMIO=y         # MMIO 支持
```

### 2. 块设备支持
```
CONFIG_BLOCK=y
CONFIG_BLK_DEV=y
CONFIG_BLK_DEV_LOOP=y        # loop 设备
CONFIG_BLK_DEV_SD=y          # SCSI 磁盘
CONFIG_SCSI=y
CONFIG_SCSI_MOD=y
```

### 3. 文件系统支持
```
CONFIG_EXT4_FS=y             # ext4（推荐根文件系统）
CONFIG_EXT4_USE_FOR_EXT2=y
CONFIG_FS_MBCACHE=y
CONFIG_JBD2=y
CONFIG_ISO9660_FS=y          # ISO9660（CD-ROM）
CONFIG_FAT_FS=y              # FAT（可选）
CONFIG_VFAT_FS=y             # VFAT（可选）
CONFIG_PROC_FS=y             # /proc（必需）
CONFIG_SYSFS=y               # /sys（必需）
CONFIG_TMPFS=y               # tmpfs
```

### 4. 串口控制台（调试必需）
```
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_NR_UARTS=4
CONFIG_SERIAL_8250_RUNTIME_UARTS=4
CONFIG_SERIAL_8250_EXTENDED=y
CONFIG_CONSOLE_TRANSLATIONS=y
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
```

### 5. 网络支持（可选但推荐）
```
CONFIG_NET=y
CONFIG_INET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_IPV6=y
CONFIG_NETDEVICES=y
CONFIG_NET_CORE=y
CONFIG_ETHERNET=y
CONFIG_NETCONSOLE=y          # 网络控制台
```

### 6. 调试支持
```
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_FS=y
CONFIG_MAGIC_SYSRQ=y
```

### 7. initrd 支持（使用 initramfs 时可选）
```
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_INITRAMFS_SOURCE=""   # 从命令行加载
```

## Rootfs 准备

### 目录结构
```
rootfs/
├── bin/           -> busybox 软链接
├── sbin/          -> busybox 软链接
├── etc/           # 配置文件
│   ├── passwd
│   ├── group
│   ├── hosts
│   ├── resolv.conf
│   └── fstab
├── dev/           # 设备文件
├── proc/          # proc 挂载点（空）
├── sys/           # sysfs 挂载点（空）
├── tmp/           # tmpfs 挂载点
├── lib/           # 库文件（静态链接不需要）
├── init           # 启动脚本
└── busybox        # 静态编译的 busybox
```

### init 脚本 (rootfs/init)
```sh
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "Hello from custom kernel!"
exec /bin/sh
```

### 基本配置文件

#### etc/passwd
```
root:x:0:0:root:/root:/bin/sh
```

#### etc/group
```
root:x:0:
```

#### etc/resolv.conf
```
nameserver 8.8.8.8
nameserver 114.114.114.114
```

#### etc/fstab
```
proc    /proc   proc    defaults    0   0
sysfs   /sys    sysfs   defaults    0   0
tmpfs   /tmp    tmpfs   defaults    0   0
```

### 创建 Rootfs 镜像

```bash
# 方法1：使用 dd + mkfs.ext4
dd if=/dev/zero of=rootfs.img bs=1M count=128
mkfs.ext4 rootfs.img

# 挂载并复制文件
mkdir -p /tmp/rootfs-mount
sudo mount -o loop rootfs.img /tmp/rootfs-mount
sudo cp -r rootfs/* /tmp/rootfs-mount/
sudo umount /tmp/rootfs-mount

# 方法2：使用 cpio initramfs（更简单）
cd rootfs
find . | cpio -o -H newc | gzip -9 > ../rootfs.cpio.gz
```

## 编译内核

### 基本编译
```bash
cd ~/git/kernel

# 使用已有配置
make oldconfig

# 或使用默认 x86_64 配置
make x86_64_defconfig

# 编译（保留2核给系统）
make -j$(($(nproc)-2)) CC="ccache gcc"

# 或全核编译
make -j$(nproc) CC="ccache gcc"
```

### 输出文件
- **内核镜像**: `arch/x86_64/boot/bzImage`
- **带符号表**: `vmlinux`（用于调试）

## QEMU 启动

### TCG 模式（无需 KVM，较慢但兼容性好）
```bash
cd ~/git/kernel

qemu-system-x86_64 \
    -M pc-i440fx-8.2 \
    -kernel arch/x86_64/boot/bzImage \
    -append "console=ttyS0 root=/dev/vda rw panic=1 nokaslr loglevel=8 net.ifnames=0 biosdevname=0 init=/init" \
    -drive file=~/kernel-work/rootfs.img,format=raw,if=virtio \
    -m 2G \
    -smp 2 \
    -serial stdio \
    -display none \
    -no-reboot
```

### KVM 模式（需要 /dev/kvm 权限，性能更好）
```bash
cd ~/git/kernel

qemu-system-x86_64 \
    -M pc-i440fx-8.2 \
    -kernel arch/x86_64/boot/bzImage \
    -append "console=ttyS0 root=/dev/vda rw panic=1 nokaslr loglevel=8 net.ifnames=0 biosdevname=0 init=/init" \
    -drive file=~/kernel-work/rootfs.img,format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -m 2G \
    -smp 2 \
    -cpu host \
    -enable-kvm \
    -serial mon:stdio
```

### 关键启动参数
- `console=ttyS0` - 使用串口0作为控制台
- `root=/dev/vda` - 根文件系统设备（virtio 磁盘）
- `init=/init` - **指定 init 程序路径**（重要！否则会用 /bin/init）
- `rw` - 以读写模式挂载根文件系统
- `panic=1` - 内核 panic 后1秒重启
- `nokaslr` - 禁用内核地址空间布局随机化（便于调试）
- `loglevel=8` - 显示所有内核消息

## 常见问题

### 1. proc/sys 目录为空
**原因**: init 脚本未执行，或使用了 busybox 的 init 而不是自定义 init

**解决**: 确保启动参数包含 `init=/init`

### 2. 无法识别 virtio 磁盘
**原因**: 未启用 VIRTIO_BLK 配置

**解决**: 检查 `.config` 中 `CONFIG_VIRTIO_BLK=y`

### 3. 控制台无输出
**原因**: 未启用串口控制台支持

**解决**: 确保 `CONFIG_SERIAL_8250_CONSOLE=y`

### 4. KVM 权限错误
```
Could not access KVM kernel module: Permission denied
```

**解决**: 
- 使用 TCG 模式（去掉 `-enable-kvm -cpu host`）
- 或将用户加入 kvm 组：`sudo usermod -aG kvm $USER`

### 5. 网络端口冲突
```
Could not set up host forwarding rule
```

**解决**: 更换端口号或检查端口占用

## 调试技巧

### GDB 调试
```bash
# 终端1：启动 QEMU 并暂停
qemu-system-x86_64 ... -S -s

# 终端2：连接 GDB
cd ~/git/kernel
gdb vmlinux
(gdb) target remote localhost:1234
(gdb) break start_kernel
(gdb) continue
```

### 查看启动日志
```bash
# 保存启动日志
qemu-system-x86_64 ... 2>&1 | tee boot.log

# 搜索特定消息
grep "Hello from custom kernel" boot.log
```

### 检查内核配置
```bash
grep CONFIG_VIRTIO_BLK .config
grep CONFIG_EXT4_FS .config
grep CONFIG_SERIAL_8250 .config
```

## 文件清单（独立存放）

所有配置文件都保存在 `kernel-work` 目录，不依赖内核仓库：

| 文件 | 用途 |
|------|------|
| `.config.template` | 内核配置模板（复制到内核源码使用） |
| `prepare-rootfs.sh` | 自动创建 busybox rootfs |
| `run-qemu-tcg.sh` | TCG 模式启动脚本 |
| `run-qemu.sh` | KVM 模式启动脚本 |
| `rootfs/` | 根文件系统目录 |
| `rootfs.img` | ext4 根文件系统镜像 |

## 快速开始（复制粘贴）

```bash
# 1. 切换到工作目录
cd ~/kernel-work

# 2. 准备 rootfs（如果还没有）
./prepare-rootfs.sh

# 3. 复制配置模板到新内核（假设新内核在 ~/git/kernel-new）
cp .config.template ~/git/kernel-new/.config
cd ~/git/kernel-new
make oldconfig

# 4. 编译内核
make -j$(($(nproc)-2)) CC="ccache gcc"

# 5. 启动 QEMU
cd ~/kernel-work
./run-qemu-tcg.sh

# 6. 进入 shell 后测试
ls /proc/
ls /sys/
uname -a
```

## 参考

- Linux Kernel Documentation: https://www.kernel.org/doc/html/latest/
- BusyBox: https://busybox.net/
- QEMU Documentation: https://www.qemu.org/documentation/
