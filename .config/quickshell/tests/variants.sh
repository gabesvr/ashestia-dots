#!/bin/bash
# Etapa 1: todo widget do widgetMap tem "variant", applyOne a aplica, regra do hidden e atalhos 1..10.
L=launcher; fail=0
chk() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ids=$(sed -n '/readonly property var widgetMap/,/})/p' $L/shell.qml | grep -oE ':\s*\w+' | tr -d ': ' )
for id in $ids; do
  type=$(grep -B1 -E "^\s*id: $id\s*$" $L/shell.qml | head -1 | grep -oE '\w+' | head -1)
  grep -q 'property bool shown' $L/widgets/$type.qml && continue   # compostos (dock, ilha) usam "shown", não variant
  chk "variant em $type" "grep -q 'property string variant: \"classic\"' $L/widgets/$type.qml"
done
chk "applyOne aplica variant" "grep -q 'w.variant = p.variant' $L/shell.qml"
chk "regra hidden p/ widgets fora do layout" "grep -q 'variant: \"hidden\"' $L/shell.qml"
chk "3 layouts (node)" "node tests/layouts.test.mjs >/dev/null"
for v in ClockHero WeatherLine MusicPill; do
  chk "variante $v existe" "[ -f $L/widgets/variants/$v.qml ]"
done
chk "atalho layout:3" "grep -q 'layout 3' ~/.config/hypr/hyprland.lua"
exit $fail
