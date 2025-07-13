# ImageCracker - Universal Firecracker Image Builder

A universal CLI tool for creating Firecracker VM images from any directory with a Dockerfile.

## Features

- **Universal**: Works with any directory containing a Dockerfile
- **Automatic Optimization**: Shrinks images to actual required size by default
- **Flexible**: Customizable parameters for different use cases
- **Globally Available**: Symlink installation for system-wide access
- **User-specific**: Images are stored in the user's home directory
- **Interactive**: Direct console access to VMs
- **Kernel Flexibility**: Support for custom kernel names and preservation

## Installation

```bash
git clone https://github.com/noxomix/imagecracker.git
cd imagecracker
./imagecracker.sh setup
```

## Usage

### Basic Syntax
```bash
imagecracker <COMMAND> [OPTIONS] [DIRECTORY]
```

### Available Commands
- `build` - Creates a Firecracker image from a Dockerfile
- `run` - Runs/tests a Firecracker image
- `setup` - Installs symlink for global access

### Build Options
- `-n, --name NAME` - Image name (required)
- `-d, --directory DIR` - Output directory (default: `$HOME/firecracker_images`)
- `-k, --kernel KERNEL` - Path to vmlinux kernel (default: bundled kernel)
- `--keep-kernel-name` - Keep original kernel filename (default: rename to 'kernel')
- `--no-compact` - Disable rootfs optimization (keep full size)
- `-s, --size SIZE` - Initial rootfs size in MB (default: 2048)
- `-h, --help` - Show help message

### Run Options
- `-d, --directory DIR` - Image directory (default: `$HOME/firecracker_images`)
- `-c, --config FILE` - Use custom Firecracker config file (won't be deleted)
- `--kernel-name NAME` - Kernel filename in image directory (default: 'kernel')
- `--ram SIZE` - RAM size in MB (default: 256, ignored with custom config)
- `--vcpus COUNT` - Number of vCPUs (default: 2, ignored with custom config)
- `--boot-args ARGS` - Kernel boot arguments (default: "console=ttyS0 reboot=k panic=1 pci=off", ignored with custom config)
- `--executable PATH` - Path to firecracker executable (default: firecracker)
- `-h, --help` - Show help message

### Examples

#### Build Examples

##### Simple build in current directory
```bash
imagecracker build --name myapp .
```

##### Production image (automatically optimized)
```bash
imagecracker build --name production /path/to/project
```

##### Image without optimization (full size)
```bash
imagecracker build --name fullsize --no-compact /path/to/project
```

##### With custom kernel and larger image
```bash
imagecracker build --name bigapp --kernel /path/to/vmlinux --size 4096 .
```

##### Keep original kernel filename
```bash
imagecracker build --name myapp --kernel /path/to/mykernel-5.10 --keep-kernel-name .
# This will save the kernel as 'mykernel-5.10' instead of 'kernel'
```

##### Save to custom directory
```bash
imagecracker build --name testapp --directory /tmp/my-images .
```

#### Run Examples

##### Basic VM execution
```bash
imagecracker run myapp
```

##### Run with custom hardware configuration
```bash
imagecracker run --ram 512 --vcpus 4 myapp
```

##### Run from custom directory
```bash
imagecracker run -d /path/to/images myapp
```

##### Run with custom boot arguments
```bash
imagecracker run --boot-args "console=ttyS0 init=/bin/bash" myapp
```

##### Run with custom Firecracker executable
```bash
imagecracker run --executable /usr/local/bin/firecracker myapp
```

##### Run with custom Firecracker configuration
```bash
imagecracker run -c /path/to/config.json myapp
```

##### Run with custom kernel name
```bash
imagecracker run --kernel-name mykernel-5.10 myapp
# Use this if the image was built with --keep-kernel-name
```

##### Advanced configuration (all options)
```bash
imagecracker run --ram 1024 --vcpus 8 --boot-args "console=ttyS0 debug" --executable /custom/firecracker myapp
```

#### Setup for global access
```bash
imagecracker setup
```

## Requirements

### For Building Images
- Dockerfile in target directory (see [Firecracker-Compatible Dockerfile Examples](#firecracker-compatible-dockerfile-examples) below)
- Docker installed and running
- Root/sudo access for image operations

### For Running Images
- Firecracker installed and in PATH (or custom path specified with `--executable`)
- Root/sudo access for VM operations
- Pre-built Firecracker images (created with the `build` command)
- Screen installed (for VM console management)

**Important**: Firecracker requires init systems (systemd/OpenRC) - see [Dockerfile Examples](#firecracker-compatible-dockerfile-examples)

## Output Structure

Images are stored in a structured format:

```
$HOME/firecracker_images/
├── myapp/
│   ├── kernel         # Kernel for this VM (default name)
│   └── rootfs.ext4    # Root filesystem
├── production/
│   ├── kernel
│   └── rootfs.ext4
├── custom-app/        # Built with --keep-kernel-name
│   ├── mykernel-5.10  # Original kernel name preserved
│   └── rootfs.ext4
└── ...
```


## Workflow

### Building Images
1. Navigate to a directory with a Dockerfile
2. Run `imagecracker build --name <name> .`
3. Images are stored in `$HOME/firecracker_images/<name>/`

### Running Images
1. Run `imagecracker run <name>` to start and connect to the VM
2. Use the console:
   - Press Ctrl+A then D to exit and terminate the VM
   - Press Ctrl+A then X to kill the VM immediately
3. Configure with options like `--ram`, `--vcpus`, `--boot-args`

### Complete Example
```bash
# Build an image with default kernel naming
imagecracker build --name webserver .

# Run with default settings (256MB RAM, 2 vCPUs)
imagecracker run webserver

# Exit and terminate the VM (Ctrl+A then D)

# Run with more resources
imagecracker run --ram 512 --vcpus 4 webserver

# Build with custom kernel and preserve its name
imagecracker build --name custom-app --kernel mykernel-5.10 --keep-kernel-name .

# Run the image with custom kernel name
imagecracker run --kernel-name mykernel-5.10 custom-app
```

## Included Files

- `imagecracker.sh` - The main script
- `vmlinux` - Standard Linux kernel for Firecracker VMs
- `README.md` - This documentation

## Tips

### Building
- Images are automatically optimized by default
- Use `--no-compact` only if you need the full size
- Use `--keep-kernel-name` to preserve original kernel filenames

### Running
- Default: 256MB RAM, 2 vCPUs
- Wildcard matching: `imagecracker run web` matches any image containing "web"
- Custom configs override all other options
- Use `--boot-args "console=ttyS0 init=/bin/bash"` for debugging
- Use `--kernel-name` if kernel has custom name

## Kernel Naming Convention

ImageCracker provides flexible kernel naming to support different use cases:

### Default Behavior
- Kernels are saved as `kernel` in the image directory
- The `run` command expects `kernel` by default

### Custom Kernel Names
If you need to preserve original kernel filenames (e.g., for version tracking):

1. **During Build**: Use `--keep-kernel-name` flag
   ```bash
   imagecracker build --name myapp --kernel linux-5.10-custom --keep-kernel-name .
   # Kernel saved as: linux-5.10-custom
   ```

2. **During Run**: Use `--kernel-name` flag
   ```bash
   imagecracker run --kernel-name linux-5.10-custom myapp
   ```

### Use Cases
- **Default naming**: Best for most users, ensures compatibility
- **Custom naming**: Useful when:
  - Testing multiple kernel versions
  - Tracking specific kernel builds
  - Maintaining kernel version history

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.

The included Linux kernel (`vmlinux`) is licensed under GPLv2 - see [KERNEL_LICENSE.md](KERNEL_LICENSE.md) for details.

## Firecracker-Compatible Dockerfile Examples

For Firecracker VMs, your Dockerfile needs an init system since Firecracker runs full VMs (not containers). Here are working examples:

### Ubuntu with systemd
```dockerfile
FROM ubuntu:20.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install systemd and essential packages
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    init \
    openssh-server \
    curl \
    net-tools \
    iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure systemd
RUN systemctl set-default multi-user.target

# Disable unnecessary services for faster boot
RUN systemctl mask \
    systemd-random-seed.service \
    cryptsetup.target \
    getty@tty1.service

# Set hostname
RUN echo 'firecracker-vm' > /etc/hostname

# Configure SSH (optional)
RUN mkdir -p /var/run/sshd && \
    echo 'root:firecracker' | chpasswd

# Use systemd as PID 1
ENTRYPOINT ["/sbin/init"]
```

### Alpine Linux with OpenRC (Minimal)
```dockerfile
FROM alpine:latest

RUN apk add --no-cache openrc util-linux openssh bash && \
    rc-update add sshd default && \
    echo 'root:alpine' | chpasswd

ENTRYPOINT ["/sbin/init"]
```

### Key Differences from Regular Docker Images:
- **Init System Required**: Firecracker VMs need systemd, OpenRC, or custom init
- **PID 1**: Must use `/sbin/init` as entrypoint, not your application
- **Full VM Environment**: Include networking tools, SSH server, etc.
- **Hostname Configuration**: Set hostname for the VM