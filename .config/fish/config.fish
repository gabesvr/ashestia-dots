# CachyOS fish config (se disponível)
test -f /usr/share/cachyos-fish-config/cachyos-config.fish && source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting — rotaciona imagem gotica + fastfetch via sixel
function fish_greeting
    set -l cache_dir "$HOME/Pictures/Goticas/.cache"
    set -l state_file "$HOME/Pictures/Goticas/.fetch_index"

    set -l images (find "$cache_dir" -maxdepth 1 -type f -name '*.jp*' 2>/dev/null | sort)
    set -l total (count $images)

    set -l logo_args

    if test $total -gt 0
        set -l idx 0
        if test -f "$state_file"
            set idx (string trim (cat "$state_file" 2>/dev/null))
        end

        set -l pick (math "$idx % $total + 1")
        set logo_args --logo "$images[$pick]" --logo-type sixel --logo-width 22 --logo-height 11 --logo-preserve-aspect-ratio true --logo-padding-top 1 --logo-padding-right 3

        # avança índice
        echo (math "$idx + 1") > "$state_file"
    end

    fastfetch $logo_args
end

# Adicionar ~/.local/bin ao PATH
set -gx PATH "$HOME/.local/bin" $PATH

# Iniciar Hyprland automaticamente no login do TTY1
if status is-login
    if test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a (tty) = "/dev/tty1"
        start-hyprland
    end
end
