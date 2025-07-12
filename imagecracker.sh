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
COMPRESS=false
SIZE="$DEFAULT_SIZE"
WORKING_DIR="."

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
    $(basename "$0") [OPTIONS] [DIRECTORY]

OPTIONS:
    -n NAME         Image name (required)
    -d DIRECTORY    Output directory (default: $DEFAULT_OUTPUT_DIR)
    -k KERNEL       Path to kernel/vmlinux (default: bundled vmlinux)
    -c              Optimize rootfs size (shrink to actual usage)
    -s SIZE         Initial rootfs size in MB (default: $DEFAULT_SIZE)
    -symlink        Install symlink for global access
    -h, --help      Show this help message

EXAMPLES:
    $(basename "$0") -n myapp .                    # Build image from current directory
    $(basename "$0") -n prod -c /path/to/project   # Build optimized production image
    $(basename "$0") -symlink                      # Install for global access

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
    
    # Detect shell and RC file
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" =~ zsh ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" =~ bash ]]; then
        shell_rc="$HOME/.bashrc"
    else
        print_warn "Could not detect shell type, defaulting to .bashrc"
        shell_rc="$HOME/.bashrc"
    fi
    
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
            -c|--compress)
                COMPRESS=true
                shift
                ;;
            -s|--size)
                SIZE="$2"
                shift 2
                ;;
            -symlink)
                install_symlink
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
        print_error "Image name is required (-n NAME)"
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
    cp "$KERNEL_PATH" "$target_dir/vmlinux"
    cp "$rootfs_file" "$target_dir/"
    
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
    fi
}

# Main function
main() {
    parse_args "$@"
    validate_requirements
    build_image
}

# Run main function
main "$@"