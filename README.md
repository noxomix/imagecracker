# ImageCracker - Universal Firecracker Image Builder

A universal CLI tool for creating Firecracker VM images from any directory with a Dockerfile.

## Features

- **Universal**: Works with any directory containing a Dockerfile
- **Automatic Optimization**: Shrinks images to actual required size by default
- **Flexible**: Customizable parameters for different use cases
- **Globally Available**: Symlink installation for system-wide access
- **User-specific**: Images are stored in the user's home directory

## Installation

### Install symlink for global access
```bash
git clone https://github.com/noxomix/imagecracker.git
cd imagecracker
./imagecracker.sh setup
```

After installation, you can use `imagecracker` from anywhere!

## Usage

### Basic Syntax
```bash
imagecracker <COMMAND> [OPTIONS] [DIRECTORY]
```

### Available Commands
- `build` - Creates a Firecracker image from a Dockerfile
- `run` - Runs/tests a Firecracker image
- `kill` - Kills running Firecracker VMs
- `setup` - Installs symlink for global access

### Build Options
- `-n, --name NAME` - Image name (required)
- `-d, --directory DIR` - Output directory (default: `$HOME/firecracker_images`)
- `-k, --kernel KERNEL` - Path to vmlinux kernel (default: bundled kernel)
- `--no-compact` - Disable rootfs optimization (keep full size)
- `-s, --size SIZE` - Initial rootfs size in MB (default: 2048)
- `-h, --help` - Show help message

### Run Options
- `-d, --directory DIR` - Image directory (default: `$HOME/firecracker_images`)
- `-c, --config FILE` - Use custom Firecracker config file (won't be deleted)
- `--ram SIZE` - RAM size in MB (default: 256, ignored with custom config)
- `--vcpus COUNT` - Number of vCPUs (default: 2, ignored with custom config)
- `--boot-args ARGS` - Kernel boot arguments (default: "console=ttyS0 reboot=k panic=1 pci=off", ignored with custom config)
- `--executable PATH` - Path to firecracker executable (default: firecracker)
- `-h, --help` - Show help message

### Kill Options
- `-a, --all` - Kill all running Firecracker VMs
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

##### Advanced configuration (all options)
```bash
imagecracker run --ram 1024 --vcpus 8 --boot-args "console=ttyS0 debug" --executable /custom/firecracker myapp
```

#### Kill Examples

##### Kill a specific VM
```bash
imagecracker kill myapp
```

##### Kill all running VMs
```bash
imagecracker kill --all
# or
imagecracker kill -a
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
- Screen installed (for background VM execution)

**Important**: Firecracker VMs require special Dockerfile configurations with init systems (systemd/OpenRC) since they run full VMs, not containers. Your Dockerfile must use `/sbin/init` as entrypoint and include essential system packages.

## Output Structure

Images are stored in a structured format:

```
$HOME/firecracker_images/
├── myapp/
│   ├── vmlinux        # Kernel for this VM
│   └── rootfs.ext4    # Root filesystem
├── production/
│   ├── vmlinux
│   └── rootfs.ext4
└── ...
```

## Workflow

### Building Images
1. **Preparation**: Navigate to a directory with a Dockerfile
2. **Build**: Run `imagecracker build --name <name> .`
3. **Storage**: The finished images are located in `$HOME/firecracker_images/<name>/`

### Running Images
1. **Test**: Run `imagecracker run <name>` to start the VM in a screen session
2. **Interact**: Use the console:
   - Press Ctrl+A then D to detach from screen (VM keeps running)
   - Run `screen -r firecracker-<name>` to reattach
   - Press Ctrl+A then X to kill the VM (while attached)
3. **Configure**: Use options like `--ram`, `--vcpus`, `--boot-args` for customization
4. **Kill**: Use `imagecracker kill <name>` to terminate a running VM

### Complete Example
```bash
# Build an image
imagecracker build --name webserver .

# Run with default settings (256MB RAM, 2 vCPUs)
imagecracker run webserver

# Detach from the VM (Ctrl+A then D)
# The VM continues running in the background

# Reattach to the VM
screen -r firecracker-webserver

# Kill the VM from outside
imagecracker kill webserver

# Run with more resources
imagecracker run --ram 512 --vcpus 4 webserver

# Kill all running VMs
imagecracker kill --all
```

## Included Files

- `imagecracker.sh` - The main script
- `vmlinux` - Standard Linux kernel for Firecracker VMs
- `README.md` - This documentation

## Tips

### Building
- Use descriptive names for your images (`--name dev`, `--name prod`, etc.)
- Images are automatically optimized (shrunk to actual size) by default
- Use `--no-compact` only if you need the full size
- The included kernel works with most applications
- Images are automatically overwritten if you use the same name

### Running
- Start with default settings (256MB RAM, 2 vCPUs) and increase as needed
- Use wildcard matching: `imagecracker run web` matches any image containing "web"
- Custom configs override all other options (`--ram`, `--vcpus`, `--boot-args`)
- VMs run in screen sessions for background execution
- Screen controls:
  - Ctrl+A then D: Detach (VM keeps running)
  - Ctrl+A then X: Kill VM (while attached)
  - `screen -r firecracker-<name>`: Reattach to VM
- Use `--boot-args "console=ttyS0 init=/bin/bash"` for debugging boot issues
- Kill running VMs with `imagecracker kill <name>` or `imagecracker kill --all`

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