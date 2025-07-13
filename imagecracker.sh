#!/bin/bash

# ImageCracker - Universal Firecracker Image Builder
# Build Firecracker VM images from any directory with a Dockerfile

set -e

# Script directory and default paths
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DEFAULT_KERNEL="$SCRIPT_DIR/vmlinux"
DEFAULT_OUTPUT_DIR="$HOME/firecracker_images"
DEFAULT_SIZE="2048"

# Default values
IMAGE_NAME=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
KERNEL_PATH="$DEFAULT_KERNEL"
COMPRESS=true
SIZE="$DEFAULT_SIZE"
WORKING_DIR="."
KEEP_KERNEL_NAME=false
CREATE_TEMPLATE=true
EXTRA_DISK_SIZE=""
READONLY_ROOTFS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Show usage
show_usage() {
    cat << EOF
ImageCracker - Universal Firecracker Image Builder

USAGE:
    $(basename "$0") <COMMAND> [OPTIONS] [DIRECTORY]

COMMANDS:
    build           Build Firecracker image from Dockerfile
    run             Run/test a Firecracker image
    setup           Install symlink for global access

BUILD OPTIONS:
    -n, --name NAME         Image name (required)
    -d, --directory DIR     Output directory (default: $DEFAULT_OUTPUT_DIR)
    -k, --kernel KERNEL     Path to kernel/vmlinux (default: bundled vmlinux)
    --keep-kernel-name      Keep original kernel filename (default: rename to 'kernel')
    --no-compact            Disable rootfs optimization (keep full size)
    --no-template           Skip creating vmconfig.json template (created by default)
    --readonly-rootfs       Mount rootfs as read-only in VM configuration
    -ed, --extra-disk [SIZE] Create additional empty ext4 disk (default: 4GB, or specify size in GB)
    -s, --size SIZE         Initial rootfs size in MB (default: $DEFAULT_SIZE)
    -h, --help              Show this help message

RUN OPTIONS:
    -d, --directory DIR     Image directory (default: $DEFAULT_OUTPUT_DIR)
    -c, --config FILE       Use custom Firecracker config file (won't be deleted)
    --kernel-name NAME      Kernel filename in image directory (default: 'kernel')
    --ram SIZE              RAM size in MB (default: 256, ignored with custom config)
    --vcpus COUNT           Number of vCPUs (default: 2, ignored with custom config)
    --boot-args ARGS        Kernel boot arguments (default: "console=ttyS0 reboot=k panic=1 pci=off", ignored with custom config)
    --executable PATH       Path to firecracker executable (default: firecracker)
    -h, --help              Show this help message

EXAMPLES:
    $(basename "$0") build --name myapp .                     # Build image from current directory
    $(basename "$0") build -n prod /path/to/project          # Build optimized production image
    $(basename "$0") run test                                 # Run image named 'test' from default directory
    $(basename "$0") run -d /my/images test                   # Run image 'test' from custom directory
    $(basename "$0") setup                                    # Install for global access

REQUIREMENTS:
    - Dockerfile in target directory
    - Docker installed and running
    - Root/sudo access for image operations

EOF
}

# Install symlink for global access
install_symlink() {
    local script_path="$(realpath "$0")"
    local symlink_name="imagecracker"
    local shell_rc=""
    local bin_dir="$SCRIPT_DIR/bin"
    
    # Check if screen is installed, offer to install if not
    if ! command -v screen &> /dev/null; then
        print_warn "Screen is not installed. Screen is recommended for running VMs in the background."
        read -p "Would you like to install screen now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installing screen..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y screen
            elif command -v yum &> /dev/null; then
                sudo yum install -y screen
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y screen
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y screen
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm screen
            else
                print_error "Could not detect package manager. Please install screen manually."
            fi
            
            if command -v screen &> /dev/null; then
                print_info "Screen installed successfully!"
            else
                print_warn "Screen installation failed. Please install it manually."
            fi
        else
            print_info "Skipping screen installation. You can install it later with:"
            print_info "  Debian/Ubuntu: sudo apt-get install screen"
            print_info "  RHEL/CentOS: sudo yum install screen"
            print_info "  Fedora: sudo dnf install screen"
            print_info "  openSUSE: sudo zypper install screen"
            print_info "  Arch: sudo pacman -S screen"
        fi
    fi
    
    # Detect shell and RC file
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" =~ zsh ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" =~ bash ]]; then
        shell_rc="$HOME/.bashrc"
    else
        print_warn "Could not detect shell type, defaulting to .bashrc"
        shell_rc="$HOME/.bashrc"
    fi
    
    # Create default firecracker_images directory
    print_info "Creating default output directory: $DEFAULT_OUTPUT_DIR"
    mkdir -p "$DEFAULT_OUTPUT_DIR"
    
    # Create bin directory if it doesn't exist
    mkdir -p "$bin_dir"
    
    # Create symlink
    local symlink_path="$bin_dir/$symlink_name"
    if [[ -L "$symlink_path" ]] || [[ -f "$symlink_path" ]]; then
        print_warn "Removing existing $symlink_name"
        rm -f "$symlink_path"
    fi
    
    ln -s "$script_path" "$symlink_path"
    chmod +x "$symlink_path"
    
    # Add to PATH if not already there
    if ! grep -q "$bin_dir" "$shell_rc" 2>/dev/null; then
        echo '' >> "$shell_rc"
        echo '# Added by ImageCracker installer' >> "$shell_rc"
        echo "export PATH=\"$bin_dir:\$PATH\"" >> "$shell_rc"
        print_info "Added $bin_dir to PATH in $shell_rc"
    fi
    
    print_info "Default output directory created: $DEFAULT_OUTPUT_DIR"
    print_info "Symlink installed: $symlink_path"
    print_info "You can now use 'imagecracker' from anywhere"
    print_info "Restart your shell or run: source $shell_rc"
    exit 0
}

# Validate requirements
validate_requirements() {
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if Dockerfile exists in working directory
    if [[ ! -f "$WORKING_DIR/Dockerfile" ]]; then
        print_error "No Dockerfile found in $WORKING_DIR"
        exit 1
    fi
    
    # Check if kernel exists
    if [[ ! -f "$KERNEL_PATH" ]]; then
        print_error "Kernel not found at: $KERNEL_PATH"
        exit 1
    fi
    
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        build)
            parse_build_args "$@"
            ;;
        run)
            parse_run_args "$@"
            ;;
        setup)
            install_symlink
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Parse run command arguments
parse_run_args() {
    local search_dir="$DEFAULT_OUTPUT_DIR"
    local image_pattern=""
    local custom_config=""
    local ram_size="256"
    local vcpu_count="2"
    local firecracker_exec="firecracker"
    local boot_args="console=ttyS0 reboot=k panic=1 pci=off"
    local kernel_name="kernel"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                search_dir="$2"
                shift 2
                ;;
            -c|--config)
                custom_config="$2"
                shift 2
                ;;
            --ram)
                ram_size="$2"
                shift 2
                ;;
            --vcpus)
                vcpu_count="$2"
                shift 2
                ;;
            --boot-args)
                boot_args="$2"
                shift 2
                ;;
            --executable)
                firecracker_exec="$2"
                shift 2
                ;;
            --kernel-name)
                kernel_name="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                image_pattern="$1"
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$image_pattern" ]]; then
        print_error "Image name/pattern is required"
        show_usage
        exit 1
    fi
    
    # Validate custom config if provided
    if [[ -n "$custom_config" ]] && [[ ! -f "$custom_config" ]]; then
        print_error "Config file not found: $custom_config"
        exit 1
    fi
    
    # Validate RAM and vCPU values
    if ! [[ "$ram_size" =~ ^[0-9]+$ ]] || [[ "$ram_size" -lt 128 ]]; then
        print_error "Invalid RAM size: $ram_size (must be at least 128 MB)"
        exit 1
    fi
    
    if ! [[ "$vcpu_count" =~ ^[0-9]+$ ]] || [[ "$vcpu_count" -lt 1 ]] || [[ "$vcpu_count" -gt 32 ]]; then
        print_error "Invalid vCPU count: $vcpu_count (must be between 1 and 32)"
        exit 1
    fi
    
    # Find matching images
    run_image "$search_dir" "$image_pattern" "$custom_config" "$ram_size" "$vcpu_count" "$firecracker_exec" "$boot_args" "$kernel_name"
}

# Parse build command arguments
parse_build_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -d|--directory)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -k|--kernel)
                KERNEL_PATH="$2"
                shift 2
                ;;
            --no-compact)
                COMPRESS=false
                shift
                ;;
            --keep-kernel-name)
                KEEP_KERNEL_NAME=true
                shift
                ;;
            --no-template)
                CREATE_TEMPLATE=false
                shift
                ;;
            --readonly-rootfs)
                READONLY_ROOTFS=true
                shift
                ;;
            -ed|--extra-disk)
                # Check if next argument is a number (disk size)
                if [[ $# -gt 1 ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    EXTRA_DISK_SIZE="$2"
                    shift 2
                else
                    # Default to 4GB if no size specified
                    EXTRA_DISK_SIZE="4"
                    shift
                fi
                ;;
            -s|--size)
                SIZE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                WORKING_DIR="$1"
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$IMAGE_NAME" ]]; then
        print_error "Image name is required (--name NAME)"
        show_usage
        exit 1
    fi
    
    # Convert to absolute path
    WORKING_DIR="$(realpath "$WORKING_DIR")"
}

# Build the image (adapted from original script)
build_image() {
    local docker_image_name="imagecracker-temp-$$"
    local container_name="imagecracker-container-$$"
    local rootfs_file="rootfs.ext4"
    local mnt_dir="mnt-$$"
    local target_dir="$OUTPUT_DIR/$IMAGE_NAME"
    
    print_info "Building image '$IMAGE_NAME' from $WORKING_DIR"
    print_info "Output directory: $target_dir"
    print_info "Kernel: $KERNEL_PATH"
    print_info "Initial size: ${SIZE}MB"
    
    # Setup target directory
    mkdir -p "$target_dir"
    if [[ -d "$target_dir" ]] && [[ "$(ls -A "$target_dir")" ]]; then
        print_warn "Removing existing image '$IMAGE_NAME'"
        rm -rf "$target_dir"/*
    fi
    
    # Change to working directory
    cd "$WORKING_DIR"
    
    print_info "Building Docker image..."
    docker build -t "$docker_image_name" .
    
    print_info "Creating container and exporting filesystem..."
    docker create --name "$container_name" "$docker_image_name"
    docker export "$container_name" -o rootfs.tar
    docker rm "$container_name"
    docker rmi "$docker_image_name" > /dev/null
    
    print_info "Creating ext4 image (${SIZE}MB initial)..."
    sudo dd if=/dev/zero of="$rootfs_file" bs=1M count="$SIZE" 2>/dev/null
    sudo mkfs.ext4 "$rootfs_file" >/dev/null 2>&1
    
    print_info "Mounting and extracting filesystem..."
    mkdir "$mnt_dir"
    sudo mount -o loop "$rootfs_file" "$mnt_dir"
    sudo tar -xf rootfs.tar -C "$mnt_dir"
    
    # Get actual usage
    local used_mb=$(df -BM "$mnt_dir" | tail -1 | awk '{print $3}' | sed 's/M//')
    print_info "Content size: ${used_mb}MB"
    
    sudo umount "$mnt_dir"
    rm -rf "$mnt_dir" rootfs.tar
    
    # Optimize and compress if requested
    if [[ "$COMPRESS" == true ]]; then
        print_info "Optimizing filesystem size..."
        sudo e2fsck -f -y "$rootfs_file" >/dev/null 2>&1
        
        local min_blocks=$(sudo resize2fs -P "$rootfs_file" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
        local block_size=$(sudo dumpe2fs -h "$rootfs_file" 2>/dev/null | grep "Block size" | awk '{print $3}')
        local min_size_mb=$(( (min_blocks * block_size / 1024 / 1024) + 20 ))  # 20MB buffer
        
        print_info "Shrinking to ${min_size_mb}MB..."
        sudo resize2fs -p "$rootfs_file" ${min_size_mb}M >/dev/null 2>&1
        
        local truncate_size=$((min_size_mb * 1024 * 1024))
        sudo truncate -s $truncate_size "$rootfs_file"
    fi
    
    # Copy files to target directory
    print_info "Copying files to target directory..."
    if [[ "$KEEP_KERNEL_NAME" == true ]]; then
        local kernel_filename=$(basename "$KERNEL_PATH")
        cp "$KERNEL_PATH" "$target_dir/$kernel_filename"
        print_info "Kernel saved as: $kernel_filename"
    else
        cp "$KERNEL_PATH" "$target_dir/kernel"
        print_info "Kernel saved as: kernel"
    fi
    cp "$rootfs_file" "$target_dir/"
    
    # Create extra disk if --extra-disk flag is set
    if [[ -n "$EXTRA_DISK_SIZE" ]]; then
        local extra_disk_file="$target_dir/extra.ext4"
        local size_mb=$((EXTRA_DISK_SIZE * 1024))
        
        print_info "Creating extra disk: ${EXTRA_DISK_SIZE}GB ($extra_disk_file)..."
        
        # Create sparse file for extra disk
        sudo dd if=/dev/zero of="$extra_disk_file" bs=1M count="$size_mb" 2>/dev/null
        
        # Create ext4 filesystem
        sudo mkfs.ext4 -F "$extra_disk_file" >/dev/null 2>&1
        
        # Set proper permissions
        sudo chmod 666 "$extra_disk_file"
        
        print_info "Extra disk created: extra.ext4 (${EXTRA_DISK_SIZE}GB)"
    fi
    
    # Create vmconfig.json if --templ flag is set
    if [[ "$CREATE_TEMPLATE" == true ]]; then
        print_info "Creating vmconfig.json template..."
        local kernel_filename="kernel"
        if [[ "$KEEP_KERNEL_NAME" == true ]]; then
            kernel_filename=$(basename "$KERNEL_PATH")
        fi
        # Generate drives section based on whether extra disk is present
        local rootfs_readonly="false"
        if [[ "$READONLY_ROOTFS" == true ]]; then
            rootfs_readonly="true"
        fi
        
        local drives_json='[
    {
      "drive_id": "rootfs",
      "path_on_host": "rootfs.ext4",
      "is_root_device": true,
      "is_read_only": '"$rootfs_readonly"'
    }'
        
        if [[ -n "$EXTRA_DISK_SIZE" ]]; then
            drives_json+=',
    {
      "drive_id": "extra",
      "path_on_host": "extra.ext4",
      "is_root_device": false,
      "is_read_only": false
    }'
        fi
        
        drives_json+='
  ]'
        
        cat > "$target_dir/vmconfig.json" << EOF
{
  "boot-source": {
    "kernel_image_path": "$kernel_filename",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": $drives_json,
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 512,
    "ht_enabled": false
  },
  "cpu-config": {
    "max_phys_bits": 39
  },
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "06:00:AC:10:00:02",
      "host_dev_name": "tap0"
    }
  ]
}
EOF
        print_info "vmconfig.json created in $target_dir"
    fi
    
    # Cleanup
    rm -f "$rootfs_file"
    
    local final_size_mb=$(stat -c%s "$target_dir/$rootfs_file" | awk '{print int($1/1024/1024)}')
    
    print_info "Image '$IMAGE_NAME' built successfully"
    print_info "Location: $target_dir"
    if [[ "$COMPRESS" == true ]]; then
        print_info "Final size: ${final_size_mb}MB (saved $((SIZE - final_size_mb))MB)"
        print_info "Optimized: Yes"
    else
        print_info "Final size: ${final_size_mb}MB"
        print_info "Optimized: No (full size)"
    fi
}

# Run a Firecracker image
run_image() {
    local search_dir="$1"
    local image_pattern="$2"
    local custom_config="$3"
    local ram_size="$4"
    local vcpu_count="$5"
    local firecracker_exec="$6"
    local boot_args="$7"
    local kernel_name="$8"
    
    # Check if search directory exists
    if [[ ! -d "$search_dir" ]]; then
        print_error "Directory not found: $search_dir"
        exit 1
    fi
    
    # First, check for exact match
    local exact_match="$search_dir/$image_pattern"
    if [[ -d "$exact_match" ]]; then
        local image_dir="$exact_match"
    else
        # If no exact match, find partial matches
        local matches=()
        while IFS= read -r -d '' dir; do
            local basename=$(basename "$dir")
            if [[ "$basename" == *"$image_pattern"* ]]; then
                matches+=("$dir")
            fi
        done < <(find "$search_dir" -maxdepth 1 -type d -name "*$image_pattern*" -print0)
        
        # Check number of matches
        if [[ ${#matches[@]} -eq 0 ]]; then
            print_error "No images found matching pattern: $image_pattern"
            print_info "Available images in $search_dir:"
            find "$search_dir" -maxdepth 1 -type d -not -path "$search_dir" -exec basename {} \; | sort
            exit 1
        elif [[ ${#matches[@]} -gt 1 ]]; then
            print_error "Multiple images found matching pattern: $image_pattern"
            print_info "Matching images:"
            for match in "${matches[@]}"; do
                echo "  - $(basename "$match")"
            done
            print_info "Tip: Use exact image name to avoid ambiguity"
            exit 1
        fi
        
        local image_dir="${matches[0]}"
    fi
    
    local image_name=$(basename "$image_dir")
    
    # Check if required files exist
    local kernel_path="$image_dir/$kernel_name"
    local rootfs_path="$image_dir/rootfs.ext4"
    
    if [[ ! -f "$kernel_path" ]]; then
        print_error "Kernel not found: $kernel_path"
        print_info "Use --kernel-name to specify a different kernel filename"
        exit 1
    fi
    
    if [[ ! -f "$rootfs_path" ]]; then
        print_error "Root filesystem not found: $rootfs_path"
        exit 1
    fi
    
    print_info "Running image: $image_name"
    print_info "Kernel: $kernel_path"
    print_info "Rootfs: $rootfs_path"
    
    # Check if firecracker executable exists
    if ! command -v "$firecracker_exec" &> /dev/null; then
        print_error "Firecracker executable not found: $firecracker_exec"
        print_info "Please install Firecracker or specify correct path with --executable"
        print_info "Installation guide: https://github.com/firecracker-microvm/firecracker"
        exit 1
    fi
    
    # Check if screen is installed
    if ! command -v screen &> /dev/null; then
        print_error "Screen is not installed. Screen is required to run VMs in the background."
        print_info "Install screen with: sudo apt-get install screen (Debian/Ubuntu) or sudo yum install screen (RHEL/CentOS)"
        exit 1
    fi
    
    # Create temporary socket
    local socket_path="/tmp/firecracker-$$.socket"
    local config_file=""
    local delete_config=false
    
    # Use custom config or check for vmconfig.json in image directory
    if [[ -n "$custom_config" ]]; then
        config_file="$custom_config"
        print_info "Using custom config: $config_file"
        if [[ "$ram_size" != "256" ]] || [[ "$vcpu_count" != "2" ]] || [[ "$boot_args" != "console=ttyS0 reboot=k panic=1 pci=off" ]]; then
            print_warn "--ram, --vcpus, and --boot-args options are ignored when using custom config"
        fi
    elif [[ -f "$image_dir/vmconfig.json" ]]; then
        # Use vmconfig.json from image directory
        config_file="$image_dir/vmconfig.json"
        delete_config=false
        print_info "Using VM config from image: $config_file"
        if [[ "$ram_size" != "256" ]] || [[ "$vcpu_count" != "2" ]] || [[ "$boot_args" != "console=ttyS0 reboot=k panic=1 pci=off" ]]; then
            print_warn "--ram, --vcpus, and --boot-args options are ignored when using image's vmconfig.json"
        fi
    else
        config_file="/tmp/firecracker-$$.json"
        delete_config=true
        
        # Create default Firecracker configuration
        cat > "$config_file" << EOF
{
    "boot-source": {
        "kernel_image_path": "$kernel_path",
        "boot_args": "$boot_args"
    },
    "drives": [
        {
            "drive_id": "rootfs",
            "path_on_host": "$rootfs_path",
            "is_root_device": true,
            "is_read_only": false
        }
    ],
    "machine-config": {
        "vcpu_count": $vcpu_count,
        "mem_size_mib": $ram_size
    }
}
EOF
    fi
    
    # Cleanup function
    cleanup() {
        sudo rm -f "$socket_path" 2>/dev/null || true
        if [[ "$delete_config" == true ]]; then
            rm -f "$config_file"
        fi
        sudo pkill -f "firecracker.*$socket_path" 2>/dev/null || true
    }
    trap cleanup EXIT
    
    print_info "Starting Firecracker VM..."
    print_info "To exit and terminate VM: Press Ctrl+A then D"
    print_info "To kill the VM immediately: Press Ctrl+A then X"
    
    # Start Firecracker in screen
    screen -S "firecracker-$image_name" sudo "$firecracker_exec" --api-sock "$socket_path" --config-file "$config_file"
    
    cleanup
}

# Main function
main() {
    parse_args "$@"
    if [[ "$1" == "build" ]]; then
        validate_requirements
        build_image
    fi
}

# Run main function
main "$@"