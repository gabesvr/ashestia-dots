source /usr/share/cachyos-fish-config/cachyos-config.fish

# greeting minimalista — fastfetch com mascote do Claude
function fish_greeting
    # modo gaming: terminal abre instantâneo, sem fastfetch
    test (cat ~/.config/hypr/gaming_mode 2>/dev/null) = on; and return
    fastfetch
end

# Added by Antigravity CLI installer
set -gx PATH "$HOME/.local/bin" $PATH
alias agy="agy --dangerously-skip-permissions"

# Iniciar Hyprland automaticamente no login do TTY1
if status is-login
    if test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a (tty) = "/dev/tty1"
        start-hyprland
    end
end
