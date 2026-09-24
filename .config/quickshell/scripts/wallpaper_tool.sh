#!/bin/bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CURRENT_WP_FILE="$HOME/.config/hypr/current_wallpaper"
COLORS_CACHE="$HOME/.config/quickshell/current_colors.json"

get_active() {
    if [ -s "$CURRENT_WP_FILE" ]; then
        head -n 1 "$CURRENT_WP_FILE" | tr -d '\r\n'
    else
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1 | tr -d '\r\n'
    fi
}

get_colors() {
    local img="$1"
    if [ -f "$COLORS_CACHE" ]; then
        local cached_img
        cached_img=$(jq -r '.image // empty' "$COLORS_CACHE" 2>/dev/null)
        if [ "$cached_img" = "$img" ]; then
            local cached_cols
            cached_cols=$(jq -c '.colors // empty' "$COLORS_CACHE" 2>/dev/null)
            if [ -n "$cached_cols" ] && [ "$cached_cols" != "null" ]; then
                echo "$cached_cols"
                return
            fi
        fi
    fi

    if [ -n "$img" ] && [ -f "$img" ] && command -v matugen >/dev/null 2>&1; then
        local cols
        cols=$(matugen image "$img" --source-color-index 0 -j hex 2>/dev/null | jq -c '.colors | {
            primary: .primary.default.color,
            on_primary: .on_primary.default.color,
            primary_container: .primary_container.default.color,
            secondary: .secondary.default.color,
            tertiary: .tertiary.default.color,
            error: .error.default.color,
            surface: .surface.default.color,
            surface_container: .surface_container.default.color,
            outline: .outline.default.color,
            outline_variant: .outline_variant.default.color,
            on_surface: .on_surface.default.color,
            on_surface_variant: .on_surface_variant.default.color
        }' 2>/dev/null)
        if [ -n "$cols" ] && [ "$cols" != "null" ]; then
            echo "{\"image\":\"$img\",\"colors\":$cols}" > "$COLORS_CACHE" 2>/dev/null
            echo "$cols"
            return
        fi
    fi

    echo '{"primary":"#b088ff","on_primary":"#131418","primary_container":"#2e2a42","secondary":"#bdc7dc","tertiary":"#dbbce1","error":"#ffb4ab","surface":"#12131a","surface_container":"#1a1b24","outline":"#36384a","outline_variant":"#43474e","on_surface":"#e1e2e9","on_surface_variant":"#c4c6cf"}'
}

clean_name() {
    local fn="$1"
    local base="${fn%.*}"
    base="${base//-wallpaper-/ }"
    base="${base//-4k-/ }"
    base="${base//-/ }"
    base="${base//_/ }"
    local res=""
    for w in $base; do
        local low="${w,,}"
        case "$low" in
            4k|uhdpaper|com|hd|wallpaper) continue ;;
            *)
                local cap="$(tr '[:lower:]' '[:upper:]' <<< "${w:0:1}")${w:1}"
                res="${res:+$res }$cap"
                ;;
        esac
    done
    [ -n "$res" ] && echo "$res" || echo "${fn%.*}"
}

cmd_list() {
    local active
    active=$(get_active)
    local wp_json="[]"
    if [ -d "$WALLPAPER_DIR" ]; then
        wp_json=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort | jq -R -s --arg active "$active" '
            split("\n") | map(select(length > 0)) | map({
                name: (split("/") | last | sub("(?i)-wallpaper-|-4k-"; " ") | gsub("[-_]"; " ") | split(" ") | map(select(. != "" and (. | ascii_downcase | test("^(4k|uhdpaper|com|hd|wallpaper)$") | not)) | (.[0:1] | ascii_upcase) + .[1:]) | join(" ")),
                filename: (split("/") | last),
                path: .,
                active: (. == $active)
            })
        ')
    fi
    local colors
    colors=$(get_colors "$active")
    jq -c -n --arg act "$active" --argjson wps "$wp_json" --argjson cols "$colors" '{
        active: $act,
        wallpapers: $wps,
        colors: $cols
    }'
}

cmd_set() {
    local path="$1"
    if [ ! -f "$path" ]; then
        echo '{"status":"error","message":"File not found"}'
        return 1
    fi

    # 1. Update wallpaper seamlessly with swaybg (launch new on top, then kill older)
    local old_pids
    old_pids=$(pgrep -x swaybg)
    setsid systemd-run --user --scope --quiet --collect swaybg -i "$path" -m fill </dev/null >/dev/null 2>&1 &
    local new_pid=$!
    disown 2>/dev/null
    # grava já: se este processo for cancelado (troca rápida pelo widget) o Quickshell ainda recebe o novo caminho
    echo "$path" > "$CURRENT_WP_FILE"
    sleep 0.2
    if [ -n "$old_pids" ]; then
        for p in $old_pids; do
            if [ "$p" != "$new_pid" ]; then
                kill "$p" 2>/dev/null
            fi
        done
    fi

    # 3. Clean names and colors
    local name
    name=$(clean_name "$(basename "$path")")
    local colors
    colors=$(get_colors "$path")

    jq -c -n --arg st "ok" --arg act "$path" --arg nm "$name" --argjson cols "$colors" '{
        status: $st,
        active: $act,
        name: $nm,
        colors: $cols
    }'
}

cmd_init() {
    local wp
    wp=$(get_active)
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        pkill -x swaybg 2>/dev/null
        setsid systemd-run --user --scope --quiet --collect swaybg -i "$wp" -m fill </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null
    fi
}

cmd_random() {
    if [ -d "$WALLPAPER_DIR" ]; then
        local rand_file
        rand_file=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
        if [ -n "$rand_file" ]; then
            cmd_set "$rand_file"
            return
        fi
    fi
    echo '{"status":"error","message":"No wallpapers found"}'
}

cmd_next() {
    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo '{"status":"error","message":"No wallpapers directory"}'
        return 1
    fi
    local active
    active=$(get_active)
    local wps=()
    while IFS= read -r line; do
        [ -n "$line" ] && wps+=("$line")
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

    local total=${#wps[@]}
    if [ "$total" -eq 0 ]; then
        echo '{"status":"error","message":"No wallpapers found"}'
        return 1
    fi

    local current_idx=-1
    for i in "${!wps[@]}"; do
        if [ "${wps[$i]}" = "$active" ]; then
            current_idx=$i
            break
        fi
    done

    local next_idx=$(( (current_idx + 1) % total ))
    local next_wp="${wps[$next_idx]}"
    cmd_set "$next_wp"
}

cmd_prev() {
    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo '{"status":"error","message":"No wallpapers directory"}'
        return 1
    fi
    local active
    active=$(get_active)
    local wps=()
    while IFS= read -r line; do
        [ -n "$line" ] && wps+=("$line")
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

    local total=${#wps[@]}
    if [ "$total" -eq 0 ]; then
        echo '{"status":"error","message":"No wallpapers found"}'
        return 1
    fi

    local current_idx=0
    for i in "${!wps[@]}"; do
        if [ "${wps[$i]}" = "$active" ]; then
            current_idx=$i
            break
        fi
    done

    local prev_idx=$(( (current_idx - 1 + total) % total ))
    local prev_wp="${wps[$prev_idx]}"
    cmd_set "$prev_wp"
}

case "$1" in
    init) cmd_init ;;
    list) cmd_list ;;
    set) cmd_set "$2" ;;
    next) cmd_next ;;
    prev) cmd_prev ;;
    random) cmd_random ;;
    colors)
        act=$(get_active)
        cols=$(get_colors "$act")
        jq -c -n --arg act "$act" --argjson cols "$cols" '{active: $act, colors: $cols}'
        ;;
    active)
        act=$(get_active)
        jq -c -n --arg act "$act" '{active: $act}'
        ;;
    *) cmd_list ;;
esac
