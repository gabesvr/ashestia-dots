#!/bin/bash
# Bateria em JSON (uma linha) para o BatteryTileWidget.
#   battery_tool.sh            : status
#   battery_tool.sh limit 80|100 : limite de carga (asusctl; persiste no asusd)
B=/sys/class/power_supply/BAT1
case "$1" in
limit)
    asusctl battery limit "$2" >/dev/null 2>&1 || sudo -n asusctl battery limit "$2" >/dev/null 2>&1
    ;;
esac
awk -v st="$(cat $B/status)" -v cap="$(cat $B/capacity)" -v cn="$(cat $B/charge_now)" -v cf="$(cat $B/charge_full)" \
    -v cd="$(cat $B/charge_full_design)" -v cur="$(cat $B/current_now)" -v volt="$(cat $B/voltage_now)" \
    -v cyc="$(cat $B/cycle_count 2>/dev/null || echo 0)" -v lim="$(cat $B/charge_control_end_threshold 2>/dev/null || echo 100)" \
    -v ac="$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)" -v mode="$(/usr/local/bin/power-mode status 2>/dev/null)" '
BEGIN {
    watts = cur * volt / 1e12
    health = cd > 0 ? int(cf * 100 / cd + 0.5) : 0
    mins = -1
    if (cur > 50000) {
        if (st == "Discharging") mins = int(cn / cur * 60)
        else if (st == "Charging") { tgt = cf * lim / 100; if (tgt > cn) mins = int((tgt - cn) / cur * 60) }
    }
    printf "{\"percent\":%d,\"status\":\"%s\",\"ac\":%s,\"watts\":%.1f,\"minutes\":%d,\"health\":%d,\"cycles\":%d,\"limit\":%d,\"mode\":\"%s\"}\n",
        cap, st, (ac == 1 ? "true" : "false"), watts, mins, health, cyc, lim, mode
}'
