# System pieces (ASUS TUF FA607NUG)

These files touch the boot process and the laptop firmware, so `install.sh` does **not** copy them.
They were written for an ASUS TUF with a MUX (AMD Radeon 740M + NVIDIA RTX 4050) and `asusctl`.
Read each script before installing.

| File | What it does |
| :--- | :--- |
| `usr/local/bin/gpu-mode` | `gpu-mode amd\|nvidia\|status` — switches the GPU that drives the screen and reboots. **amd** = MUX hybrid + NVIDIA powered off (battery, no HDMI). **nvidia** = MUX dGPU only (gaming, HDMI). Used by the GPU tile. |
| `usr/local/bin/igpu-guard` + `etc/systemd/system/igpu-guard.service` | Runs before login and adapts the system to the **real** MUX state: removes the unused iGPU in NVIDIA mode, loads `amdgpu` in AMD mode, powers the NVIDIA off on the first boot after `gpu-mode amd`. Writes `/run/gpu-mode` (read by `hyprland/env.lua`) and `/run/gpu-mode.env` (read by the QuickShell service). |
| `etc/modprobe.d/dgpu-only.conf` | `blacklist amdgpu` (only the guard loads it) + NVIDIA module options. |
| `etc/udev/rules.d/99-gpu-devices.rules` | Stable `/dev/dri/nvidia-dgpu` and `/dev/dri/amd-igpu` symlinks (Aquamarine cannot parse `:` in paths). |
| `etc/systemd/system/nvidia-persistenced.service.d/only-with-dgpu.conf` | Skips NVIDIA services when the card is powered off (copy it for `nvidia-powerd` too). |
| `usr/local/bin/power-mode` | `silent\|balanced\|performance\|ac\|battery\|login\|status` — the 3-position power tile. No overclock. Hook it in `/etc/asusd/asusd.ron`: `ac_command: "/usr/local/bin/power-mode ac"`, `bat_command: "/usr/local/bin/power-mode battery"`, `change_platform_profile_on_ac/battery: false`. |
| `usr/local/bin/gaming-mode.sh`, `usr/local/bin/gpu-oc` | Autostart latency tweaks and the NVIDIA VF offset used by Gaming mode. |
| `etc/sudoers.d/ashestia` | Passwordless sudo for the scripts above (the tiles call them with `sudo -n`). Check with `visudo -cf` before copying. |

## Install

```bash
sudo install -m755 usr/local/bin/* /usr/local/bin/
sudo cp -r etc/systemd/system/* /etc/systemd/system/
sudo cp etc/modprobe.d/dgpu-only.conf /etc/modprobe.d/
sudo cp etc/udev/rules.d/99-gpu-devices.rules /etc/udev/rules.d/
sudo install -m440 etc/sudoers.d/ashestia /etc/sudoers.d/ && sudo visudo -cf /etc/sudoers.d/ashestia
sudo systemctl daemon-reload && sudo systemctl enable igpu-guard.service
sudo mkinitcpio -P
```

**Recovery:** if the screen stays black after a GPU switch, open a TTY (Ctrl+Alt+F3) and run `sudo gpu-mode nvidia`.
