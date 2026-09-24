#!/bin/bash
# Native ultra-fast Bash replacement for wifi_tool.py - Zero Python overhead
set -e

get_status() {
    local radio
    radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
    if [ "$radio" != "enabled" ]; then
        echo '{"enabled":false,"ssid":"","signal":0}'
        return
    fi

    local in_use ssid signal
    while IFS=: read -r in_use ssid signal; do
        if [ "$in_use" = "*" ]; then
            echo "{\"enabled\":true,\"ssid\":\"$ssid\",\"signal\":${signal:-0}}"
            return
        fi
    done < <(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null || true)

    echo '{"enabled":true,"ssid":"","signal":0}'
}

# Lista de redes em JSON (uma linha). "saved" = já tem perfil no NetworkManager (conecta sem pedir senha).
print_list() {
    local saved
    saved=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}')
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | awk -F: -v saved="$saved" '
    BEGIN {
        n = split(saved, arr, "\n"); for (i = 1; i <= n; i++) known[arr[i]] = 1
        printf "{\"enabled\":true,\"networks\":["
        first = 1
    }
    {
        in_use = ($1 == "*") ? "true" : "false"
        ssid = $2
        signal = $3 + 0
        sec = $4
        is_locked = (length(sec) > 0 && sec != "--") ? "true" : "false"
        is_saved = (ssid in known) ? "true" : "false"

        # Escape special chars in SSID and Security
        gsub(/\\/, "\\\\", ssid)
        gsub(/"/, "\\\"", ssid)
        gsub(/\\/, "\\\\", sec)
        gsub(/"/, "\\\"", sec)

        if (ssid != "" && !seen[ssid]++) {
            if (!first) printf ","
            printf "{\"in_use\":%s,\"ssid\":\"%s\",\"signal\":%d,\"security\":\"%s\",\"is_locked\":%s,\"saved\":%s}", in_use, ssid, signal, sec, is_locked, is_saved
            first = 0
        }
    }
    END {
        printf "]}\n"
    }'
}

# list        : lista em cache (instantânea)
# list rescan : cache na hora + varredura nova, e imprime de novo quando ela termina (2 linhas).
#               Necessário: com sinal bom o NM quase não varre sozinho (bgscan simple:30:-70:86400).
cmd_list() {
    local radio
    radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
    if [ "$radio" != "enabled" ]; then
        echo '{"enabled":false,"networks":[]}'
        return
    fi
    print_list
    if [ "$1" = "rescan" ]; then
        nmcli -t -f SSID dev wifi list --rescan yes >/dev/null 2>&1 || true
        print_list
    fi
}

cmd_connect() {
    local ssid="$1"
    local pwd="$2"
    local out=""
    local ret=0

    if [ -n "$pwd" ]; then
        out=$(nmcli dev wifi connect "$ssid" password "$pwd" 2>&1) || ret=$?
    elif nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
        out=$(nmcli connection up id "$ssid" 2>&1) || ret=$?
    else
        out=$(nmcli dev wifi connect "$ssid" 2>&1) || ret=$?
    fi

    # Escape JSON
    out=$(echo "$out" | tr -d '\r\n' | sed 's/"/\\"/g')
    if [ "$ret" -eq 0 ]; then
        echo "{\"success\":true,\"output\":\"$out\"}"
    else
        echo "{\"success\":false,\"output\":\"$out\"}"
    fi
}

cmd_toggle() {
    local target="$1"
    if [ "$target" = "on" ] || [ "$target" = "off" ]; then
        nmcli radio wifi "$target" 2>/dev/null || true
    else
        local radio
        radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
        if [ "$radio" = "enabled" ]; then
            nmcli radio wifi off 2>/dev/null || true
        else
            nmcli radio wifi on 2>/dev/null || true
        fi
    fi
    get_status
}

cmd_disconnect() {
    local dev
    dev=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
    if [ -n "$dev" ]; then
        nmcli dev disconnect "$dev" 2>/dev/null || true
        echo '{"success":true}'
    else
        echo '{"success":false}'
    fi
}

cmd_forget() {
    local ssid="$1"
    if [ -n "$ssid" ]; then
        nmcli connection delete id "$ssid" 2>/dev/null || true
        echo '{"success":true}'
    else
        echo '{"success":false}'
    fi
}

case "$1" in
    list) cmd_list "$2" ;;
    connect) cmd_connect "$2" "$3" ;;
    toggle) cmd_toggle "$2" ;;
    disconnect) cmd_disconnect ;;
    forget) cmd_forget "$2" ;;
    status) get_status ;;
    *) cmd_list ;;
esac
