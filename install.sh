#!/usr/bin/env bash
# ============================================================
# Ashestia Hyprland Rice - Installer & Setup Script
# CachyOS / Arch Linux • Zero-Latency Gaming & Clean UI
# ============================================================

set -e

echo "==> Installing Ashestia Hyprland Rice..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Goticas"

# 1. Copy configuration directories (.config)
echo "--> Copying dotfiles to $CONFIG_DIR..."
for folder in hypr quickshell foot fastfetch cava matugen mako fish; do
    if [ -d "$SCRIPT_DIR/.config/$folder" ]; then
        echo "    Installing $folder..."
        mkdir -p "$CONFIG_DIR/$folder"
        cp -r "$SCRIPT_DIR/.config/$folder/"* "$CONFIG_DIR/$folder/"
    fi
done

# 2. Build C helper daemons if gcc is available
if command -v gcc >/dev/null 2>&1; then
    echo "--> Compiling helper daemons..."
    if [ -f "$CONFIG_DIR/quickshell/scripts/controls_status.c" ]; then
        gcc -O3 "$CONFIG_DIR/quickshell/scripts/controls_status.c" -o "$CONFIG_DIR/quickshell/scripts/controls_status"
        chmod +x "$CONFIG_DIR/quickshell/scripts/controls_status"
    fi
    if [ -f "$CONFIG_DIR/quickshell/scripts/apps_tool.c" ]; then
        gcc -O3 "$CONFIG_DIR/quickshell/scripts/apps_tool.c" -o "$CONFIG_DIR/quickshell/scripts/apps_tool"
        chmod +x "$CONFIG_DIR/quickshell/scripts/apps_tool"
    fi
fi

# 3. Copy scripts (.local/bin)
echo "--> Copying utilities to $BIN_DIR..."
if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    cp -r "$SCRIPT_DIR/.local/bin/"* "$BIN_DIR/"
    chmod +x "$BIN_DIR"/*
fi

# 4. Copy wallpapers
if [ -d "$SCRIPT_DIR/wallpapers" ]; then
    echo "--> Copying wallpapers to $HOME/Pictures/Wallpapers..."
    cp -r "$SCRIPT_DIR/wallpapers/"* "$HOME/Pictures/Wallpapers/"
fi

# 5. Copy terminal picture assets
if [ -d "$SCRIPT_DIR/pictures/Goticas" ]; then
    echo "--> Copying Fastfetch and Foot graphics to $HOME/Pictures/Goticas..."
    cp -r "$SCRIPT_DIR/pictures/Goticas/"* "$HOME/Pictures/Goticas/"
    [ -d "$SCRIPT_DIR/pictures/Goticas/.cache" ] && cp -r "$SCRIPT_DIR/pictures/Goticas/.cache" "$HOME/Pictures/Goticas/"
fi

echo "==> Installation finished successfully."
echo "==> Reload Hyprland with 'hyprctl reload' or restart the active session."
