#!/usr/bin/env bash
# ============================================================
# Ashestia Hyprland Rice - Installer & Setup Script
# CachyOS / Arch Linux • Zero-Latency Gaming & Clean UI
# ============================================================

set -e

echo "✨ Instalando Ashestia Hyprland Rice..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Goticas"

# 1. Copiar configurações (.config)
echo "📁 Copiando dotfiles para $CONFIG_DIR..."
for folder in hypr quickshell foot fastfetch cava matugen mako fish; do
    if [ -d "$SCRIPT_DIR/.config/$folder" ]; then
        echo "  -> Instalando $folder..."
        cp -r "$SCRIPT_DIR/.config/$folder" "$CONFIG_DIR/"
    fi
done

# 2. Copiar scripts (.local/bin)
echo "⚡ Copiando utilitários para $BIN_DIR..."
if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    cp -r "$SCRIPT_DIR/.local/bin/"* "$BIN_DIR/"
    chmod +x "$BIN_DIR"/*
fi

# 3. Copiar wallpapers
if [ -d "$SCRIPT_DIR/wallpapers" ]; then
    echo "🖼️ Copiando wallpapers para $HOME/Pictures/Wallpapers..."
    cp -r "$SCRIPT_DIR/wallpapers/"* "$HOME/Pictures/Wallpapers/"
fi

# 4. Copiar imagens do Foot / Fastfetch (Goticas Sixel)
if [ -d "$SCRIPT_DIR/pictures/Goticas" ]; then
    echo "🖤 Copiando imagens do Fastfetch/Foot para $HOME/Pictures/Goticas..."
    cp -r "$SCRIPT_DIR/pictures/Goticas/"* "$HOME/Pictures/Goticas/"
    [ -d "$SCRIPT_DIR/pictures/Goticas/.cache" ] && cp -r "$SCRIPT_DIR/pictures/Goticas/.cache" "$HOME/Pictures/Goticas/"
fi

echo "✅ Instalação concluída com sucesso!"
echo "💡 Dica: Recarregue o Hyprland com 'hyprctl reload' ou faça logoff e login novamente."
