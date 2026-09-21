#!/bin/bash
# Native ultra-fast Bash replacement for bt_tool.py - Zero Python overhead
set -e

get_status() {
    local show_out
    show_out=$(bluetoothctl show 2>/dev/null || true)
    if ! echo "$show_out" | grep -q "Powered: yes"; then
        echo '{"powered":false,"enabled":false,"connected_name":"","connected_mac":""}'
        return
    fi

    local conn_mac="" conn_name=""
    local conn_dev
    conn_dev=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 || true)
    if [ -n "$conn_dev" ]; then
        conn_mac=$(echo "$conn_dev" | awk '{print $2}')
        conn_name=$(echo "$conn_dev" | cut -d' ' -f3-)
    fi

    # Escape JSON
    conn_name=$(echo "$conn_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "{\"powered\":true,\"enabled\":true,\"connected_name\":\"$conn_name\",\"connected_mac\":\"$conn_mac\"}"
}

cmd_list() {
    local show_out
    show_out=$(bluetoothctl show 2>/dev/null || true)
    if ! echo "$show_out" | grep -q "Powered: yes"; then
        echo '{"powered":false,"enabled":false,"devices":[]}'
        return
    fi

    local paired_macs
    paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' || true)

    local conn_macs
    conn_macs=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' || true)

    bluetoothctl devices 2>/dev/null | awk -v paired="$paired_macs" -v conn="$conn_macs" '
    BEGIN {
        split(paired, p_arr, "[ \n]")
        for (i in p_arr) if (p_arr[i] != "") is_paired[p_arr[i]] = 1

        split(conn, c_arr, "[ \n]")
        for (i in c_arr) if (c_arr[i] != "") is_conn[c_arr[i]] = 1

        printf "{\"powered\":true,\"enabled\":true,\"devices\":["
        first = 1
    }
    /^Device/ {
        mac = $2
        name = ""
        for (i = 3; i <= NF; i++) {
            name = (name == "") ? $i : (name " " $i)
        }
        if (name == "") name = mac

        # Escape special chars
        gsub(/\\/, "\\\\", name)
        gsub(/"/, "\\\"", name)

        p = (mac in is_paired) ? "true" : "false"
        c = (mac in is_conn) ? "true" : "false"

        if (mac != "" && !seen[mac]++) {
            if (!first) printf ","
            printf "{\"mac\":\"%s\",\"name\":\"%s\",\"paired\":%s,\"connected\":%s}", mac, name, p, c
            first = 0
        }
    }
    END {
        printf "]}\n"
    }'
}

cmd_toggle() {
    local target="$1"
    local show_out
    show_out=$(bluetoothctl show 2>/dev/null || true)
    local is_powered=false
    if echo "$show_out" | grep -q "Powered: yes"; then
        is_powered=true
    fi

    if [ "$target" = "on" ] || { [ -z "$target" ] && [ "$is_powered" = "false" ]; }; then
        rfkill unblock bluetooth 2>/dev/null || true
        bluetoothctl power on >/dev/null 2>&1 || true
    else
        bluetoothctl power off >/dev/null 2>&1 || true
    fi
    get_status
}

cmd_scan() {
    local dur="${1:-5}"
    rfkill unblock bluetooth 2>/dev/null || true
    bluetoothctl power on >/dev/null 2>&1 || true
    timeout "$dur" bluetoothctl scan on >/dev/null 2>&1 || true
    cmd_list
}

cmd_connect() {
    local mac="$1"
    local out ret=0
    out=$(bluetoothctl connect "$mac" 2>&1) || ret=$?
    out=$(echo "$out" | tr -d '\r\n' | sed 's/"/\\"/g')
    if [ "$ret" -eq 0 ] && echo "$out" | grep -qi "successful"; then
        echo "{\"success\":true,\"output\":\"$out\"}"
    else
        echo "{\"success\":false,\"output\":\"$out\"}"
    fi
}

cmd_disconnect() {
    local mac="$1"
    local out ret=0
    out=$(bluetoothctl disconnect "$mac" 2>&1) || ret=$?
    out=$(echo "$out" | tr -d '\r\n' | sed 's/"/\\"/g')
    echo "{\"success\":true,\"output\":\"$out\"}"
}

cmd_pair() {
    local mac="$1"
    local out ret=0
    out=$(bluetoothctl pair "$mac" 2>&1) || ret=$?
    out=$(echo "$out" | tr -d '\r\n' | sed 's/"/\\"/g')
    echo "{\"success\":true,\"output\":\"$out\"}"
}

cmd_remove() {
    local mac="$1"
    local out ret=0
    out=$(bluetoothctl remove "$mac" 2>&1) || ret=$?
    out=$(echo "$out" | tr -d '\r\n' | sed 's/"/\\"/g')
    echo "{\"success\":true,\"output\":\"$out\"}"
}

case "$1" in
    list) cmd_list ;;
    status) get_status ;;
    toggle) cmd_toggle "$2" ;;
    scan) cmd_scan "$2" ;;
    connect) cmd_connect "$2" ;;
    disconnect) cmd_disconnect "$2" ;;
    pair) cmd_pair "$2" ;;
    remove) cmd_remove "$2" ;;
    *) cmd_list ;;
esac
