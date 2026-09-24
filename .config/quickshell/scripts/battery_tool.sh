#!/bin/bash
# Bateria em JSON (uma linha) para o BatteryTileWidget.
#   battery_tool.sh            : status
#   battery_tool.sh limit 80|100 : limite de carga (asusctl; persiste no asusd)
B=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -n "$B" ] || { echo '{"present":false}'; exit 0; }          # desktop sem bateria: o tile some
AC=0; for d in /sys/class/power_supply/*; do [ "$(cat $d/type 2>/dev/null)" = Mains ] && AC=$(cat $d/online 2>/dev/null) && break; done
if [ -x /usr/local/bin/power-mode ]; then MODE=$(/usr/local/bin/power-mode status 2>/dev/null)
else case "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)" in quiet|low-power) MODE=silent ;; performance) MODE=performance ;; *) MODE=balanced ;; esac; fi
case "$1" in
limit)
    asusctl battery limit "$2" >/dev/null 2>&1 || sudo -n asusctl battery limit "$2" >/dev/null 2>&1
    ;;
esac
# Baterias expõem carga (charge_*/current_now, µAh/µA) ou energia (energy_*/power_now, µWh/µW): normaliza para energia.
r() { cat "$B/$1" 2>/dev/null; }
if [ -r "$B/energy_now" ]; then EN=$(r energy_now); EF=$(r energy_full); ED=$(r energy_full_design); PW=$(r power_now)
else V=$(r voltage_now); EN=$(( $(r charge_now) * V / 1000000 )); EF=$(( $(r charge_full) * V / 1000000 )); ED=$(( $(r charge_full_design) * V / 1000000 )); PW=$(( $(r current_now) * V / 1000000 )); fi
awk -v st="$(r status)" -v cap="$(r capacity)" -v en="${EN:-0}" -v ef="${EF:-0}" -v ed="${ED:-0}" -v pw="${PW:-0}" \
    -v cyc="$(r cycle_count || echo 0)" -v lim="$(r charge_control_end_threshold || echo 100)" \
    -v ac="$AC" -v mode="$MODE" '
BEGIN {
    watts = pw / 1e6
    health = ed > 0 ? int(ef * 100 / ed + 0.5) : 0
    mins = -1
    if (pw > 500000) {
        if (st == "Discharging") mins = int(en / pw * 60)
        else if (st == "Charging") { tgt = ef * lim / 100; if (tgt > en) mins = int((tgt - en) / pw * 60) }
    }
    printf "{\"present\":true,\"percent\":%d,\"status\":\"%s\",\"ac\":%s,\"watts\":%.1f,\"minutes\":%d,\"health\":%d,\"cycles\":%d,\"limit\":%d,\"mode\":\"%s\"}\n",
        cap, st, (ac == 1 ? "true" : "false"), watts, mins, health, cyc + 0, (lim == "" ? 100 : lim), mode
}'
