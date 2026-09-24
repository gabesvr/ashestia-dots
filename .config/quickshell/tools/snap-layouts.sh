#!/bin/bash
# Prints dos layouts 1..N numa área de trabalho vazia (ws 9) + RSS e contagem de processos.
# uso: tools/snap-layouts.sh <pasta-saida> [N]
out="$1"; n="${2:-5}"; mkdir -p "$out"
cur=$(python3 -c 'import json;print(json.load(open("$HOME/.config/quickshell/layout_state.json"))["layout"])' 2>/dev/null || echo 1)
hyprctl dispatch "hl.dsp.focus({ workspace = 9 })" >/dev/null
for i in $(seq 1 "$n"); do echo "layout:$i" > /tmp/qs-island-fifo; sleep 1.8; grim "$out/l$i.png"; done
echo "layout:$cur" > /tmp/qs-island-fifo
hyprctl dispatch "hl.dsp.focus({ workspace = 2 })" >/dev/null
pid=$(systemctl --user show -p MainPID --value quickshell)
{ echo "rss_kb=$(awk '/VmRSS/{print $2}' /proc/$pid/status)"
  echo "follow=$(pgrep -fc '^/usr/bin/playerctl metadata --follow')"
  echo "controls_status=$(pgrep -xc controls_status)"; } | tee "$out/stats.txt"
