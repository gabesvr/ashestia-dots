#!/bin/bash
# Verifica os serviços da etapa 1: cada fonte de dado roda uma vez e ninguém mais lê direto.
# uso: tests/services.sh   (com o Quickshell rodando)
fail=0; L=launcher
chk() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
chk "SystemStatus existe"            '[ -f $L/services/SystemStatus.qml ]'
chk "shell sem props system* antigas" '! grep -qE "system(Volume|Brightness|WifiOn|WifiSsid|BtOn|Power|Dnd|Xwayland)\b|statusPoller" $L/shell.qml'
chk "1 controls_status"              '[ "$(pgrep -xc controls_status)" = 1 ]'
chk "MusicService existe"            '[ -f $L/services/MusicService.qml ]'
chk "MusicWidget sem playerctl próprio" "! grep -qF '\"playerctl\"' \$L/widgets/MusicWidget.qml"
chk "1 playerctl --follow"            '[ "$(pgrep -fc "^/usr/bin/playerctl metadata --follow")" = 1 ]'
chk "WeatherService existe"           '[ -f $L/services/WeatherService.qml ]'
chk "WeatherWidget sem WeatherData próprio" '! grep -qE "^\s*WeatherData \{" $L/widgets/WeatherWidget.qml'
chk "BatteryService existe"           '[ -f $L/services/BatteryService.qml ]'
chk "BatteryTile sem battery_tool próprio" '! grep -q "battery_tool" $L/widgets/BatteryTileWidget.qml'
chk "log do quickshell sem erro"     '! journalctl --user -u quickshell --since "-60s" --no-pager | grep -qiE "TypeError|ReferenceError|is not defined|Cannot assign"'
exit $fail
