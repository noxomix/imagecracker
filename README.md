# ImageCracker - Universal Firecracker Image Builder

A universal CLI tool for creating Firecracker VM images from any directory with a Dockerfile.

## Features

- 🔧 **Universal**: Works with any directory containing a Dockerfile
- 📦 **Automatic Optimization**: Shrinks images to actual required size by default
- 🎯 **Flexible**: Customizable parameters for different use cases
- 🔗 **Globally Available**: Symlink installation for system-wide access
- 🏠 **User-specific**: Images are stored in the user's home directory

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
- `setup` - Installs symlink for global access

### Build Options
- `-n, --name NAME` - Image name (required)
- `-d, --directory DIR` - Output directory (default: `$HOME/firecracker_images`)
- `-k, --kernel KERNEL` - Path to vmlinux kernel (default: bundled kernel)
- `--no-compact` - Disable rootfs optimization (keep full size)
- `-s, --size SIZE` - Initial rootfs size in MB (default: 2048)
- `-h, --help` - Show help message

### Examples

#### Simple build in current directory
```bash
imagecracker build --name myapp .
```

#### Production image (automatically optimized)
```bash
imagecracker build --name production /path/to/project
```

#### Image without optimization (full size)
```bash
imagecracker build --name fullsize --no-compact /path/to/project
```

#### With custom kernel and larger image
```bash
imagecracker build --name bigapp --kernel /path/to/vmlinux --size 4096 .
```

#### Save to custom directory
```bash
imagecracker build --name testapp --directory /tmp/my-images .
```

#### Setup for global access
```bash
imagecracker setup
```

## Requirements

- Dockerfile in target directory
- Docker installed and running
- Root/sudo access for image operations

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

1. **Preparation**: Navigate to a directory with a Dockerfile
2. **Build**: Run `imagecracker build --name <name> .`
3. **Usage**: The finished images are located in `$HOME/firecracker_images/<name>/`

## Included Files

- `imagecracker.sh` - The main script
- `vmlinux` - Standard Linux kernel for Firecracker VMs
- `README.md` - This documentation

## Tips

- Use descriptive names for your images (`--name dev`, `--name prod`, etc.)
- Images are automatically optimized (shrunk to actual size) by default
- Use `--no-compact` only if you need the full size
- The included kernel works with most applications
- Images are automatically overwritten if you use the same name

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.

The included Linux kernel (`vmlinux`) is licensed under GPLv2 - see [KERNEL_LICENSE.md](KERNEL_LICENSE.md) for details.