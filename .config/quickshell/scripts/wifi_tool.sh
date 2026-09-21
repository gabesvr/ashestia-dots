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

cmd_list() {
    local radio
    radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
    if [ "$radio" != "enabled" ]; then
        echo '{"enabled":false,"networks":[]}'
        return
    fi

    # Read cached AP list in 8ms with --rescan no (or rescan yes if explicitly requested)
    local rescan_flag="--rescan no"
    if [ "$1" = "rescan" ]; then
        rescan_flag="--rescan yes"
    fi

    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list $rescan_flag 2>/dev/null | awk -F: '
    BEGIN {
        printf "{\"enabled\":true,\"networks\":["
        first = 1
    }
    {
        in_use = ($1 == "*") ? "true" : "false"
        ssid = $2
        signal = $3 + 0
        sec = $4
        is_locked = (length(sec) > 0 && sec != "--") ? "true" : "false"

        # Escape special chars in SSID and Security
        gsub(/\\/, "\\\\", ssid)
        gsub(/"/, "\\\"", ssid)
        gsub(/\\/, "\\\\", sec)
        gsub(/"/, "\\\"", sec)

        if (ssid != "" && !seen[ssid]++) {
            if (!first) printf ","
            printf "{\"in_use\":%s,\"ssid\":\"%s\",\"signal\":%d,\"security\":\"%s\",\"is_locked\":%s}", in_use, ssid, signal, sec, is_locked
            first = 0
        }
    }
    END {
        printf "]}\n"
    }'
}

cmd_connect() {
    local ssid="$1"
    local pwd="$2"
    local out=""
    local ret=0

    if [ -n "$pwd" ]; then
        out=$(nmcli dev wifi connect "$ssid" password "$pwd" 2>&1) || ret=$?
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
