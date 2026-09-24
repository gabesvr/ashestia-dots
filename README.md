# Ashestia Hyprland Rice

> Minimalist, modern, zero-latency gaming and daily productivity setup for Linux (CachyOS / Arch Linux), with macOS-style **Liquid Glass** desktop widgets built in QuickShell.

![Ashestia Desktop Widgets](assets/screenshots/widgets.png)

<p align="center">
  <img src="assets/demo/ashestia-demo.gif" alt="Ashestia widgets demo: layouts, solid mode, panels" width="820">
</p>

> Full quality video: [`assets/demo/ashestia-demo.mp4`](assets/demo/ashestia-demo.mp4) (layout switching, solid-mode key, expanding panels, synced lyrics).

---

## Highlights

* **Liquid Glass widgets** rendered by a custom GLSL shader: soft frosted blur, a thin lens refraction near the edges, extra vibrancy and adaptive darkening so white text stays readable over bright wallpapers.
* **10 adaptive layouts** that recompute from the real screen size (no overlapping, works with fractional scaling) and switch with a staggered "wave" animation.
* **Widgets that change shape per layout**: in the 5 creative layouts the same widget morphs into a different visual (giant thin clock, round clock with a seconds ring, vinyl record player, magazine-style date, bento cards…) while it flies to its new place. Only the active variant is kept in memory.
* **Spring animations** everywhere: widgets move with a slight overshoot, panels grow and settle like on macOS. Hyprland windows, workspaces and layers use spring curves too.
* **Solid mode key**: an animated macOS-style switch tile turns every widget from glass into a flat dark gray surface (`#2b2d33`, same color as the terminal). The change ripples out from the switch.
* **Expandable panels** for Wi-Fi, Bluetooth, Battery and Wallpapers with clean SF-style iconography, signal bars, iOS-style switches and inline password entry. Wi-Fi really rescans and connects to saved networks in one click.
* **3-position power switch** (Silent / Balanced / Performance: ASUS profile, fan curve, power-profiles and NVIDIA clocks — no overclock) that follows the charger automatically.
* **Battery widget** with charge ring, time left, watts, health and an 80% charge-limit switch.
* **GPU mode tile** (ASUS MUX laptops): NVIDIA-only for gaming or AMD-only with the NVIDIA powered off for battery life — see [`system/`](system/).
* **Synced lyrics** panel for the music widget that resizes itself so it never covers the weather widget.
* Everything is driven by a tiny FIFO interface, so Hyprland binds (or scripts) can control the shell.

---

## Layouts

| | |
| :---: | :---: |
| ![Sonoma Flanks](assets/screenshots/layout-1-sonoma-flanks.jpg)<br>**1. Sonoma Flanks** | ![Top Shelf](assets/screenshots/layout-2-top-shelf.jpg)<br>**2. Top Shelf** |
| ![Smart Sidebar](assets/screenshots/layout-3-smart-sidebar.jpg)<br>**3. Smart Sidebar** | ![Four Corners](assets/screenshots/layout-4-four-corners.jpg)<br>**4. Four Corners** |
| ![Creative Studio](assets/screenshots/layout-5-creative-studio.jpg)<br>**5. Creative Studio** | ![Lyrics panel](assets/screenshots/lyrics-panel.jpg)<br>**Synced lyrics panel** |

### Creative layouts (widgets change shape)

| | |
| :---: | :---: |
| ![Hero Clock](assets/screenshots/layout-6-hero-clock.jpg)<br>**6. Hero Clock** — giant thin clock, one-line weather, pill player, round-tile dock | ![Bento](assets/screenshots/layout-7-bento.jpg)<br>**7. Bento** — boxes of different sizes with big numbers and a large cover |
| ![Orbit](assets/screenshots/layout-8-orbit.jpg)<br>**8. Orbit** — round glass clock with a seconds ring, tiles in orbit, spinning vinyl | ![Island](assets/screenshots/layout-9-island.jpg)<br>**9. Island** — everything in a dark island that expands on hover, thin tile rail |
| ![Editorial](assets/screenshots/layout-10-editorial.jpg)<br>**10. Editorial** — magazine cover: huge serif date, thin temperature, album poster | |

### Solid mode (the key tile)

| | |
| :---: | :---: |
| ![Solid layout 1](assets/screenshots/solid-mode-layout-1.jpg) | ![Solid layout 4](assets/screenshots/solid-mode-layout-4.jpg) |

---

## Hardware & System Specifications

* **Operating System:** CachyOS (Kernel BORE / linux-cachyos)
* **Hardware:** ASUS TUF Gaming FA607NUG (16" 1920x1200 @144Hz, fractional scale 1.5)
* **Processor:** AMD Ryzen 7 7445HS
* **Graphics:** NVIDIA GeForce RTX 4050 Laptop (140W TGP) + AMD Radeon 740M — switchable with the GPU mode tile (MUX)
* **Compositor:** Hyprland 0.56+ (configured in Lua via `hyprland.lua`)
* **Desktop Widgets:** QuickShell (Clock, Calendar, Quick Controls, Weather, Music with Synced Lyrics, Liquid Glass shaders)
* **Terminal:** foot / footclient (instant startup via systemd daemon, flat `#2b2d33` background)
* **Color Palette:** Matugen (dynamic colors generated from the wallpaper)
* **Terminal Fetch:** minimal Fastfetch with the Claude mascot
* **Audio Visualizer:** Cava
* **Notifications:** Mako

---

## Desktop Widgets

* **Clock Widget:** digital clock with localized timezone offset and tick ring.
* **Calendar Widget:** full-month calendar with active day highlight.
* **Quick Controls & Sliders:** volume and brightness sliders plus tiles: Wi-Fi, Bluetooth, Battery, App drawer, the 3-position power switch, Gaming mode, Do Not Disturb, Xwayland toggle, Wallpaper picker, laptop/HDMI monitor mode, GPU mode, Claude and the **solid-mode switch**.
* **Weather Widget:** live weather from Open-Meteo (current conditions, hourly forecast, 5-day outlook).
* **Music Widget:** real-time player with sub-second Spotify sync, album art and an interactive synced lyrics view.

### Controlling the shell (FIFO)

```bash
echo layout:4   > /tmp/qs-island-fifo   # switch layout (1-10 or "next")
echo theme      > /tmp/qs-island-fifo   # toggle solid mode
echo wifi       > /tmp/qs-island-fifo   # open/close the Wi-Fi panel
echo bt         > /tmp/qs-island-fifo   # open/close the Bluetooth panel
echo battery    > /tmp/qs-island-fifo   # open/close the Battery panel
echo turbo      > /tmp/qs-island-fifo   # next power mode (silent → balanced → performance)
echo lyrics     > /tmp/qs-island-fifo   # open/close the lyrics panel
echo wallpaper:panel > /tmp/qs-island-fifo   # open/close the wallpaper gallery
```

---

## Terminal & Fastfetch

* Flat dark gray `#2b2d33` background with a soft blue/orange palette, block cursor, `DejaVu Sans Mono` with `JetBrainsMono Nerd Font` as icon fallback.
* Fish greeting runs a minimal `fastfetch` (user, OS, WM, shell, memory) next to the Claude mascot.

---

## Installation

Requirements: `hyprland`, `quickshell`, `foot`, `fish`, `matugen`, `mako`, `cava`, `playerctl`, `brightnessctl`, `qt6-shadertools` (for `qsb`), `gcc` (helper daemons). Optional: `asusctl`, `power-profiles-daemon`, `gpu-screen-recorder`, `noto-fonts` (serif of the Editorial layout).

The widgets use the SF Pro fonts by family name; `install.sh` installs them to `~/.local/share/fonts`.

```bash
git clone https://github.com/gabesvr/ashestia-dots.git
cd ashestia-dots
chmod +x install.sh
./install.sh
```

Hardware-specific pieces for the ASUS TUF (GPU mode, power modes, boot-time GPU guard) live in [`system/`](system/) and are **not** installed automatically — read [`system/README.md`](system/README.md) first.

If you edit a shader (`launcher/widgets/shaders/*.frag`), recompile and **restart** QuickShell (Qt caches shaders per process):

```bash
/usr/lib/qt6/bin/qsb --glsl "300 es,330" --hlsl 50 --msl 12 -o X.frag.qsb X.frag
systemctl --user restart quickshell
```

---

## Keybindings

| Shortcut | Action |
| :--- | :--- |
| `Super + Enter` | Open Terminal (`foot`) |
| `Super + T` | Floating Terminal |
| `Super + W` | Open Browser (`Firefox`) |
| `Super + E` | Open File Manager (`Thunar`) |
| `Super + A` / `Super + Space` | App Launchpad |
| `Super + I` | Control Center Island |
| `Super + G` | Next widget layout |
| `Super + Alt + [1-9]` / `Super + Alt + 0` | Jump to widget layout 1–9 / 10 |
| `Super + Shift + G` | Gaming mode (shell off, no animations, GPU tuned) |
| `Super + F9` | Start/stop screen recording (`gravar`) |
| `Super + Shift + S` | Region Screenshot |
| `Print` | Fullscreen Screenshot |
| `Super + Q` | Close Active Window |
| `Super + F` | Toggle Floating Window |
| `Super + [1-9]` | Switch to Workspace |

---

## Monitor Configuration

`hyprland.lua` is tuned for a 1920x1200 @144Hz laptop panel with `scale = 1.5`. The internal panel's connector name changes with the GPU (`eDP-1` on NVIDIA, `eDP-2` on AMD), so the config finds it in `/sys/class/drm` instead of hard-coding it. Edit `apply_monitors()` in `~/.config/hypr/hyprland.lua` for a different refresh rate, resolution or a multi-monitor setup. The widget layouts are computed from the real screen size (tested at 1280x800, 1536x960 and 1920x1080), so they adapt automatically to other scales.

---

Created by Gabriel • Ashestia Community
