#!/usr/bin/env bash
set -e
# Detect GPU and inject variables if Nvidia is present
if lspci | grep -iE 'vga|3d' | grep -iq nvidia; then
    echo "NVIDIA detected. Applying Wayland Nvidia environment..."
    cat << 'EOF' >> ~/.config/hypr/nvidia.conf
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
EOF
    # Source nvidia.conf in hyprland.conf if not already sourced
    grep -q "source = ~/.config/hypr/nvidia.conf" ~/.config/hypr/hyprland.conf || \
    sed -i '1i source = ~/.config/hypr/nvidia.conf' ~/.config/hypr/hyprland.conf
fi