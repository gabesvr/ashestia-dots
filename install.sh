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

mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$HOME/Pictures/Wallpapers"

# 1. Copy configuration directories (.config)
echo "--> Copying dotfiles to $CONFIG_DIR..."
for folder in hypr quickshell foot fastfetch cava matugen mako fish; do   # systemd is handled below
    if [ -d "$SCRIPT_DIR/.config/$folder" ]; then
        echo "    Installing $folder..."
        mkdir -p "$CONFIG_DIR/$folder"
        cp -r "$SCRIPT_DIR/.config/$folder/"* "$CONFIG_DIR/$folder/"
    fi
done

# 1b. Fonts used by the widgets (loaded by family name: SF Pro Display / SF Pro Rounded / Barlow Condensed)
if [ -d "$SCRIPT_DIR/.config/quickshell/launcher/widgets/fonts" ]; then
    echo "--> Installing widget fonts..."
    mkdir -p "$HOME/.local/share/fonts/liquidglass"
    cp "$SCRIPT_DIR/.config/quickshell/launcher/widgets/fonts/"* "$HOME/.local/share/fonts/liquidglass/"
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null
fi

# 1c. QuickShell systemd user service (+ GPU env drop-in written by system/igpu-guard, optional)
if [ -d "$SCRIPT_DIR/.config/systemd/user" ]; then
    mkdir -p "$CONFIG_DIR/systemd/user"
    cp -r "$SCRIPT_DIR/.config/systemd/user/"* "$CONFIG_DIR/systemd/user/"
    command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
fi

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

# 5. Restart QuickShell so the widgets load (systemd user service)
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user restart quickshell 2>/dev/null || true
fi

echo "==> Installation finished successfully."
echo "==> Reload Hyprland with 'hyprctl reload' or restart the active session."
