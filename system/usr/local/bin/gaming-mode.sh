#!/bin/bash
# ================================================
# GAMING MODE - FA607NUG / RTX 4050 / Ryzen 7445HS
# ================================================
echo "[GAMING MODE] Iniciando otimizações..."

# Perfil de energia/governor/clock da NVIDIA: quem decide é o power-mode (tile de 3 posições), não este script.

# === CPU: Scheduler latência mínima ===
sysctl -w kernel.sched_min_granularity_ns=500000 2>/dev/null
sysctl -w kernel.sched_wakeup_granularity_ns=1000000 2>/dev/null
sysctl -w kernel.sched_latency_ns=4000000 2>/dev/null

# === Tela interna do laptop: 100% desligada (Zero backlight) ===
# brightnessctl -d nvidia_0 set 0 2>/dev/null
echo "[TELA] Backlight laptop mantido ativo"

# === Touchpad (I2C): Sem autosuspend para evitar congelamento ===
echo on > /sys/devices/platform/AMDI0010:01/power/control 2>/dev/null
echo on > /sys/devices/platform/AMDI0010:01/i2c-1/i2c-ASUF1204:00/power/control 2>/dev/null

# === USB Input: 8000Hz Mouse & Teclado (Zero Autosuspend) ===
for dev in /sys/bus/usb/devices/*/power/control; do
    echo on > "$dev" 2>/dev/null
done
for dev in /sys/bus/usb/devices/*/power/autosuspend; do
    echo -1 > "$dev" 2>/dev/null
done
echo "[USB] Autosuspend desativado -> 8000Hz polling rate e latência zero"

# === CPU: C-state latency mínima ===
for f in /sys/devices/system/cpu/cpu*/power/pm_qos_resume_latency_us; do
    echo 0 > "$f" 2>/dev/null
done
echo "[CPU] C-states -> latência mínima"

# === VM tunning para gaming ===
sysctl -w vm.swappiness=100
sysctl -w vm.dirty_ratio=3
sysctl -w vm.dirty_background_ratio=2
sysctl -w vm.vfs_cache_pressure=125

# === Network: menor latência ===
sysctl -w net.core.netdev_max_backlog=16384
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

echo "[GAMING MODE] Sistema otimizado para máximo desempenho!"
