local HOME = os.getenv("HOME")   -- nada de caminho fixo: roda em qualquer usuário
-- ============================================================
-- HYPRLAND CONFIG - FA607NUG | RTX 4050 | Ryzen 7 7445HS
-- CachyOS | Kernel 7.2.x-cachyos | Zero-latency Gaming Setup
-- ============================================================

-- Carregar variáveis de ambiente (NVIDIA + Wayland)
require("env")

-- Programas padrão (foot standalone lê foot.ini direto, 100% sólido e preto simples)
local terminal    = "foot"
local browser     = "zen-browser"
local fileManager = "thunar"
local islandMenu    = HOME .. "/.local/bin/island-toggle"     -- QuickShell Control Center / Island


------------------
---- MONITORS ----
------------------

-- Monitores: com o AOC 24G4 (HDMI) ligado, ele vira a unica tela (1080p @ 180 Hz, escala 1)
-- e o display do laptop (1920x1200@144, escala 1.5) e desligado. Sem HDMI, so o laptop.
-- O conector da tela interna muda com a GPU (eDP-1 na NVIDIA, eDP-2 na AMD): descoberto em /sys/class/drm.
-- Reavaliado no reload e a cada plug/unplug (monitor.added / monitor.removed).
-- Modo "laptop" (arquivo monitor_mode, alternado por `monitor-mode` / tile do Quickshell): so a tela do notebook,
-- HDMI desligado mesmo conectado (menos GPU/energia).
local function laptop_only()
  local f = io.open(os.getenv("HOME") .. "/.config/hypr/monitor_mode", "r")
  if not f then return false end
  local v = f:read("*l") or ""
  f:close()
  return v == "laptop"
end

local function hdmi_connected()
  local f = io.popen("cat /sys/class/drm/card*-HDMI-A-1/status 2>/dev/null")
  if not f then return false end
  local out = f:read("*a") or ""
  f:close()
  return out:find("^connected") ~= nil or out:find("\nconnected") ~= nil
end

local function internal_output()
  local f = io.popen("ls /sys/class/drm/ 2>/dev/null | grep -o 'eDP-[0-9]*' | head -1")
  local out = f and (f:read("*l") or "") or ""
  if f then f:close() end
  return out ~= "" and out or "eDP-1"
end
local EDP = internal_output()

local function apply_monitors()
  -- Antes de ligar um, empurra o outro para o lado (sem sobrepor em 0x0) e so depois desliga: sem aviso de overlap e nunca zero saidas.
  if hdmi_connected() and not laptop_only() then
    hl.monitor({ output = EDP, mode = "1920x1200@144", position = "2000x0", scale = 1.5, bitdepth = 8, vrr = 0 })
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@180", position = "0x0", scale = 1, bitdepth = 8, vrr = 0, disabled = false })
    hl.monitor({ output = EDP, disabled = true })
  else
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@180", position = "2000x0", scale = 1, bitdepth = 8, vrr = 0 })
    hl.monitor({ output = EDP, mode = "1920x1200@144", position = "0x0", scale = 1.5, bitdepth = 8, vrr = 0, disabled = false })
    hl.monitor({ output = "HDMI-A-1", disabled = true })
  end
end

apply_monitors()
hl.on("monitor.added",   function() hl.exec_cmd("sleep 1 && hyprctl reload") end)
hl.on("monitor.removed", function() hl.exec_cmd("sleep 1 && hyprctl reload") end)


---------------------
---- AUTOSTART ------
---------------------

-- API correta para Hyprland 0.47+: hl.on("hyprland.start", fn)
-- Equivalente ao exec-once do .conf legado
hl.on("hyprland.start", function()
-- Portal XDG (necessário para screenshare, file picker, etc.)
hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
-- Agente Polkit (permissões gráficas)
hl.exec_cmd("systemctl --user start hyprpolkitagent")
-- Persistência de clipboard (copiar e colar não se perde quando app fecha)
hl.exec_cmd("wl-clip-persist --clipboard regular")
hl.exec_cmd("wl-paste --watch cliphist store")
-- Terminal Foot Server (abertura instantânea com zero cold start e memória compartilhada)
hl.exec_cmd("foot --server")
-- Wallpaper daemon ultraleve (swaybg)
hl.exec_cmd(HOME .. "/.config/quickshell/scripts/wallpaper_tool.sh init")
-- QuickShell Daemon (Control Center Island - com limites e cgroup via systemd)
hl.exec_cmd("systemctl --user restart quickshell")
-- Garantir tema escuro global no portal e apps GTK (WhiteSur Dark - macOS icons)
hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'")
-- Thunar: abre instantâneo no Ryzen 7 (daemon desativado para poupar ~32MB de RAM)
-- hl.exec_cmd("thunar --daemon")
-- Aplicar gaming mode
hl.exec_cmd("sudo /usr/local/bin/gaming-mode.sh")
hl.exec_cmd("sudo -n /usr/local/bin/power-mode login")   -- perfil de energia certo p/ carregador/bateria (tile de 3 posições)
-- Garantir backlight da tela do laptop ativo (tela interna ativa)
hl.exec_cmd("brightnessctl -c backlight set 80%")   -- nvidia_0 (modo NVIDIA) ou amdgpu_bl* (modo AMD)
end)


---------------------
---- PERFORMANCE ----
---------------------

hl.config({
misc = {
force_default_wallpaper  = 0,
disable_hyprland_logo    = true,
disable_splash_rendering = true,
-- Swallow terminal ao abrir app dentro dele
enable_swallow           = true,
swallow_regex            = "^(xfce4-terminal|foot|foot-float|kitty|Alacritty)$",
focus_on_activate        = true,
-- Animação fluida estilo macOS ao segurar e arrastar / redimensionar janelas
animate_mouse_windowdragging = true,
animate_manual_resizes       = true,
vrr                          = 0,     -- G-Sync / VRR 100% DESLIGADO: máximo de FPS destravado sem sincronização
render_unfocused_fps         = 30,    -- reduz carga de GPU e alocação de buffers em janelas em segundo plano (janela ativa continua em 180Hz/144Hz)
},
    debug = {
        disable_logs = true,
    },
})

-- Direct scanout: desativado no desktop para eliminar micro-travamentos ao dividir janelas
-- Direct scanout: ativado (1) para enviar buffers diretamente ao display em fullscreen (zero latency e max FPS)
-- Estado do Xwayland (controlado pelo Switch Apple no Control Center)
local xwayland_enabled = true
local xw_f = io.open(HOME .. "/.config/hypr/xwayland_state", "r")
if xw_f then
    local content = xw_f:read("*all") or ""
    xw_f:close()
    if content:match("false") or content:match("0") then
        xwayland_enabled = false
    end
end

hl.config({
    render = {
        -- 0: com scanout direto o jogo fica preso aos Hz do monitor (buffer segurado pelo KMS
        -- até o vblank, tearing não engata) → FPS cravado em 180. Compondo, o FPS fica livre.
        direct_scanout = 0,
    },
    xwayland = {
        enabled = xwayland_enabled,
        force_zero_scaling = false,
    },
})


--------------------
---- APARÊNCIA ----
--------------------

hl.config({
general = {
gaps_in          = 6,
gaps_out         = 8,
border_size      = 0,
col = {
active_border   = 0x00000000,
inactive_border = 0x00000000,
},
resize_on_border    = false,
allow_tearing       = true,
layout              = "dwindle",  -- tiling automático
},
decoration = {
rounding       = 12,
rounding_power = 2.0,
active_opacity   = 1.0,
inactive_opacity = 1.0,
dim_inactive   = true,
dim_strength   = 0.08,   -- profundidade e foco sutil estilo macOS
shadow = {
enabled        = true,
range          = 32,
render_power   = 4,
color          = 0x70000000,
color_inactive = 0x35000000,
},
blur = {
enabled = true,
size = 10,
passes = 3,
new_optimizations = true,
ignore_opacity = true,
},
},
})


----------------------
---- ANIMAÇÕES ----
--------------------

-- ── Curvas estilo macOS ─────────────────────────────────────────────
-- Springs: física de mola como no macOS (leve overshoot, sem parada seca)
hl.curve("macOpen",   { type = "spring", mass = 1, stiffness = 260, dampening = 22 })  -- abrir: quase crítico, um leve "respiro"
hl.curve("macMove",   { type = "spring", mass = 1, stiffness = 300, dampening = 30 })  -- mover/redimensionar: firme e sem oscilar
hl.curve("macSpaces", { type = "spring", mass = 1, stiffness = 220, dampening = 28 })  -- trocar de Space: desliza e assenta suave
-- Bézier: saídas rápidas e fades
hl.curve("macClose",  { type = "bezier", points = { {0.32, 0.00}, {0.67, 0.00} } })    -- easeInCubic: fecha acelerando
hl.curve("macFade",   { type = "bezier", points = { {0.25, 0.10}, {0.25, 1.00} } })    -- ease padrão da Apple

-- ── Janelas ───────────────────────────────────────────────────────────
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 1, spring = "macOpen",  style = "popin 88%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.2, bezier = "macClose", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1, spring = "macMove" })

-- ── Fades ─────────────────────────────────────────────────────────────
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3.0, bezier = "macFade" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.2, bezier = "macFade" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 3.0, bezier = "macFade" })
hl.animation({ leaf = "fadeShadow",  enabled = true, speed = 3.0, bezier = "macFade" })
hl.animation({ leaf = "border",      enabled = true, speed = 3.0, bezier = "macFade" })

-- ── Layers (launcher, notificações, etc.) ─────────────────────────────
hl.animation({ leaf = "layersIn",    enabled = true, speed = 1, spring = "macOpen",  style = "popin 92%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2.2, bezier = "macClose", style = "fade" })

-- ── Workspaces (Spaces) ───────────────────────────────────────────────
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1, spring = "macSpaces", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1, spring = "macSpaces", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 1, spring = "macOpen", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1, spring = "macOpen", style = "slidevert" })


---------------
---- INPUT ----
---------------

hl.config({
input = {
kb_layout   = "us",
kb_variant  = "",
kb_model    = "",
kb_options  = "",
kb_rules    = "",

follow_mouse       = 1,
mouse_refocus      = true,  -- refoca janela ao mover mouse por cima (focus-follows-mouse entre monitors)
sensitivity        = 0,     -- sem aceleração de ponteiro padrão
accel_profile      = "flat",-- aceleração linear padrão para mouse externo (ideal para FPS)
force_no_accel     = false, -- permite aceleração adaptativa no touchpad

repeat_rate  = 50,   -- ms entre repetições de tecla
repeat_delay = 200,  -- ms antes de iniciar repetição

touchpad = {
natural_scroll          = true,  -- rolagem natural (estilo macOS / moderno)
disable_while_typing    = false, -- nunca trava enquanto digita ou apoia a mão
tap_to_click            = true,  -- toque leve para clicar
tap_and_drag            = true,  -- toque e arraste
drag_lock               = false, -- soltar dedo rapidamente não derruba janela
clickfinger_behavior    = false, -- desativado: ativa as áreas de botão físico (canto inferior direito = clique direito)
middle_button_emulation = false, -- desativado: previne clique acidental de botão do meio
scroll_factor           = 0.9,   -- rolagem suave e controlada
},
},
cursor = {
no_hardware_cursors = false,  -- hardware cursor na GPU (menor latência possível)
no_warps            = true,   -- sem saltos bruscos de cursor ao trocar foco
use_cpu_buffer      = 0,      -- 0 = pure GPU VRAM buffer, zero cópia CPU->GPU no DRM
min_refresh_rate    = 144,    -- trava atualização do cursor em 144Hz nativos do laptop (evita cair para 24Hz)
hotspot_padding     = 0,
},
})

-- Otimização específica para o touchpad ASUS FA607 (suave, responsivo e ágil)
hl.device({
name          = "asuf1204:00-2808:0202-touchpad",
accel_profile = "adaptive", -- curva adaptativa: movimentos lentos com precisão de pixel, swipes cobrem a tela
sensitivity   = 0.2,        -- velocidade ágil calibrada para o display 16" 144Hz
natural_scroll= true,
})

-- Mouse AJAZZ 2.4G 8K (8000Hz Polling Rate / Raw 1:1 / Zero Latência)
hl.device({
name          = "-------ajazz-2.4g-8k",
accel_profile = "flat",
sensitivity   = 0.0,
})

-- Mouse Razer DeathAdder Essential (1000Hz / Raw 1:1 / sem aceleração)
hl.device({
name          = "razer-razer-deathadder-essential",
accel_profile = "flat",
sensitivity   = 0.0,
})

-- Teclado Akko Gaming (8000Hz Polling Rate / Resposta Imediata)
hl.device({
name         = "-------akko-keyboard",
repeat_rate  = 50,
repeat_delay = 200,
})

-- Gestures
-- 3 dedos horizontal: trocar de workspace
hl.gesture({
fingers   = 3,
direction = "horizontal",
action    = "workspace"
})

-- 4 dedos para abrir / fechar a Dynamic Island (Control Center)
hl.gesture({
fingers   = 4,
direction = "down",
action    = {
finish = function()
hl.exec_cmd(HOME .. "/.local/bin/island-toggle")
end
}
})
hl.gesture({
fingers   = 4,
direction = "up",
action    = {
finish = function()
hl.exec_cmd(HOME .. "/.local/bin/island-toggle")
end
}
})


---------------------
---- LAYOUTS ----
---------------------

hl.config({
dwindle = {
preserve_split    = true,
smart_split       = false, -- desativa divisão por cursor (evita colunas finas lado a lado)
smart_resizing    = true,
force_split       = 2,     -- sempre divide à direita/embaixo (grid espiral natural)
},
master = {
new_status = "master",
},
scrolling = {
fullscreen_on_one_column = true,
},
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- ── Apps ────────────────────────────────────────────────────
hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd(terminal))                             -- normal terminal (tiled / sem float)
hl.bind(mainMod .. " + KP_Enter",      hl.dsp.exec_cmd(terminal))                             -- normal terminal (numpad enter)
hl.bind(mainMod .. " + T",             hl.dsp.exec_cmd(terminal .. " --app-id=foot-float"))   -- terminal no float
hl.bind(mainMod .. " + W",             hl.dsp.exec_cmd(browser))    -- zen browser
hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager))-- thunar
hl.bind(mainMod .. " + A",             hl.dsp.exec_cmd(islandMenu .. " launchpad"))           -- macOS Launchpad Fullscreen
hl.bind(mainMod .. " + Space",         hl.dsp.exec_cmd(islandMenu .. " launchpad"))           -- macOS Launchpad / Spotlight

-- ── Controle de janelas ─────────────────────────────────────
-- Q: fechar janela ativa imediatamente
hl.bind(mainMod .. " + Q",             hl.dsp.window.close())
-- F: alternar flutuante / tiled
hl.bind(mainMod .. " + F",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F",     hl.dsp.window.fullscreen())   -- fullscreen
hl.bind(mainMod .. " + I",             hl.dsp.exec_cmd(islandMenu))    -- Control Center Island
hl.bind(mainMod .. " + C",             hl.dsp.exec_cmd(islandMenu))    -- Control Center Island (alias)
hl.bind(mainMod .. " + B",             hl.dsp.exec_cmd(islandMenu .. " mini")) -- Mini Dynamic Island (iPhone 17 / Mac Notch)
hl.bind(mainMod .. " + N",             hl.dsp.exec_cmd(islandMenu .. " mini")) -- Mini Dynamic Island (alias Notch)
hl.bind(mainMod .. " + G",             hl.dsp.exec_cmd(islandMenu .. " layout next")) -- Alternar layouts dos Widgets Liquid Glass
hl.bind(mainMod .. " + ALT + 1",       hl.dsp.exec_cmd(islandMenu .. " layout 1"))    -- Layout 1: Sonoma Flanks
hl.bind(mainMod .. " + ALT + 2",       hl.dsp.exec_cmd(islandMenu .. " layout 2"))    -- Layout 2: Top Shelf
hl.bind(mainMod .. " + ALT + 3",       hl.dsp.exec_cmd(islandMenu .. " layout 3"))    -- Layout 3: Smart Sidebar
hl.bind(mainMod .. " + ALT + 4",       hl.dsp.exec_cmd(islandMenu .. " layout 4"))    -- Layout 4: Four Corners
hl.bind(mainMod .. " + ALT + 5",       hl.dsp.exec_cmd(islandMenu .. " layout 5"))    -- Layout 5: Creative Studio
hl.bind(mainMod .. " + ALT + 6",       hl.dsp.exec_cmd(islandMenu .. " layout 6"))    -- Layout 6: Hero Clock
hl.bind(mainMod .. " + ALT + 7",       hl.dsp.exec_cmd(islandMenu .. " layout 7"))    -- Layout 7: Bento
hl.bind(mainMod .. " + ALT + 8",       hl.dsp.exec_cmd(islandMenu .. " layout 8"))    -- Layout 8: Orbit
hl.bind(mainMod .. " + ALT + 9",       hl.dsp.exec_cmd(islandMenu .. " layout 9"))    -- Layout 9: Island
hl.bind(mainMod .. " + ALT + 0",       hl.dsp.exec_cmd(islandMenu .. " layout 10"))    -- Layout 10: Editorial
hl.bind(mainMod .. " + V",             hl.dsp.window.pseudo())
hl.bind(mainMod .. " + P",             hl.dsp.layout("togglesplit"))

-- Screenshot — grim + slurp + wl-copy (salva arquivo E copia pro clipboard)
hl.bind("SUPER + SHIFT + S",  hl.dsp.exec_cmd(HOME .. "/.local/bin/screenshot region"), { locked = false })
hl.bind("Print",               hl.dsp.exec_cmd(HOME .. "/.local/bin/screenshot full"))
hl.bind("SUPER + Print",       hl.dsp.exec_cmd(HOME .. "/.local/bin/screenshot window"))

-- Reload config
hl.bind(mainMod .. " + SHIFT + R",     hl.dsp.exec_cmd("hyprctl reload"))

-- Exit / Shutdown
hl.bind(mainMod .. " + SHIFT + P",     hl.dsp.exec_cmd(HOME .. "/.local/bin/island-toggle monitor"))
hl.bind(mainMod .. " + SHIFT + M",     hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- === Navegação de foco: HJKL (vim) + setas ===
hl.bind(mainMod .. " + H",     hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J",     hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L",     hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- === Mover janelas: SUPER+SHIFT+HJKL ===
hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K",     hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- === Redimensionar: SUPER+ALT+HJKL ===
hl.bind(mainMod .. " + ALT + H",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive -30 0"))
hl.bind(mainMod .. " + ALT + L",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive 30 0"))
hl.bind(mainMod .. " + ALT + K",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -30"))
hl.bind(mainMod .. " + ALT + J",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 30"))

-- Função auxiliar: identifica qual janela está sob o cursor do mouse
local function get_window_under_cursor()
local pos = hl.get_cursor_pos()
local cx = pos.x
local cy = pos.y
local active_ws = hl.get_active_workspace()
local active_ws_id = active_ws and active_ws.id
local matched = nil

for _, w in ipairs(hl.get_windows()) do
if w.workspace and w.workspace.id == active_ws_id then
local wx = w.at.x
local wy = w.at.y
local ww = w.size.x
local wh = w.size.y
if cx >= wx and cx <= wx + ww and cy >= wy and cy <= wy + wh then
-- Janelas flutuantes ficam por cima, têm prioridade
if w.floating then return w end
matched = w
end
end
end
return matched or hl.get_active_window()
end

-- Move a janela sob o mouse para a workspace de destino e segue o foco
local function move_window_under_cursor_to_workspace(ws)
local target = get_window_under_cursor()
if target then
hl.dispatch(hl.dsp.focus({ window = target }))
end
hl.dispatch(hl.dsp.window.move({ workspace = ws }))
hl.dispatch(hl.dsp.focus({ workspace = ws }))
end

-- ── Workspaces 1–10 ─────────────────────────────────────────
-- SUPER+N        → ir para workspace N
-- SUPER+SHIFT+N  → mover a janela sob o cursor para workspace N e seguir o foco
for i = 1, 10 do
local key = i % 10
hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
hl.bind(mainMod .. " + SHIFT + " .. key, function()
move_window_under_cursor_to_workspace(i)
end)
end

-- === Monitor focus ===
hl.bind(mainMod .. " + COMMA",         hl.dsp.exec_cmd("hyprctl dispatch focusmonitor l"))
hl.bind(mainMod .. " + PERIOD",        hl.dsp.exec_cmd("hyprctl dispatch focusmonitor r"))
hl.bind(mainMod .. " + SHIFT + COMMA", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + PERIOD",hl.dsp.window.move({ monitor = "r" }))

-- === Gravação de tela (GPU Screen Recorder / NVENC — ~/.local/bin/gravar) ===
hl.bind(mainMod .. " + F9",            hl.dsp.exec_cmd(HOME .. "/.local/bin/gravar rec"))     -- liga/para gravação

-- === Scratchpad (SUPER+D / SUPER+SHIFT+D para não conflitar com screenshot) ===
hl.bind(mainMod .. " + D",             hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + D",     hl.dsp.window.move({ workspace = "special:magic" }))

-- === Scroll workspaces com mouse ===
hl.bind(mainMod .. " + mouse_down",    hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",      hl.dsp.focus({ workspace = "e-1" }))

-- ── Mouse: arrastar e redimensionar ─────────────────────────
-- LMB / RMB clássico (SUPER + botão)
hl.bind(mainMod .. " + mouse:272",     hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",     hl.dsp.window.resize(), { mouse = true })
-- Z / X via teclado: segure a tecla e mova o mouse
-- Equivalente a: bindm = SUPER, Z, movewindow / bindm = SUPER, X, resizewindow
hl.bind(mainMod .. " + Z",             hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + X",             hl.dsp.window.resize(), { mouse = true })

-- === Multimídia ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),    { locked = true })

-- === Gaming Mode toggle === (SUPER+G já é usado para alternar layouts dos widgets)
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("systemd-run --user --scope --quiet --collect " .. HOME .. "/.local/bin/gaming-mode toggle")) -- Modo Gaming liga/desliga (desliga o Quickshell)


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Workspaces 1-10 seguem o monitor ativo (so ha um ligado por vez)
for i = 1, 10 do
hl.workspace_rule({
workspace = tostring(i),
default   = (i == 1),
})
end

-- Tamanho padrão para janelas flutuantes sem tamanho memorizado
hl.window_rule({
name  = "float-default-size",
match = { float = true },
size  = "800 500",
})

-- Terminal flutuante (SUPER+T abre com --app-id=foot-float)
hl.window_rule({
name   = "terminal-float",
match  = { class = "^(foot-float)$" },
float  = true,
size   = "960 600",
move   = "cursor_x-480 cursor_y-300",
})


-- Suprimir maximize (usar fullscreen manual)
hl.window_rule({
name  = "suppress-maximize-events",
match = { class = ".*" },
suppress_event = "maximize",
})

-- Fix XWayland drag issues
hl.window_rule({
name  = "fix-xwayland-drags",
match = {
class      = "^$",
title      = "^$",
xwayland   = true,
float      = true,
fullscreen = false,
pin        = false,
},
no_focus = true,
})

-- Hyprland-run float
hl.window_rule({
name  = "move-hyprland-run",
match = { class = "hyprland-run" },
move  = "20 monitor_h-120",
float = true,
})

-- Thunar: sempre flutuante e centralizado
hl.window_rule({
name   = "thunar-float",
match  = { class = "^([tT]hunar)$" },
float  = true,
center = true,
size   = "960 640",
})

-- Volume Control (Pavucontrol): sempre flutuante e centralizado
hl.window_rule({
name   = "pavucontrol-float",
match  = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol)$" },
float  = true,
center = true,
size   = "820 540",
})

-- ACCELA: sempre flutuante e centralizado (Custom Theme by gabesvr)
hl.window_rule({
name   = "accela-float",
match  = { class = "^([aA][cC][cC][eE][lL][aA]|god\\.is\\.in\\.the\\.wired\\.accela)$" },
float  = true,
center = true,
size   = "820 540",
})

hl.window_rule({
name   = "accela-float-title",
match  = { title = "^(ACCELA)$" },
float  = true,
center = true,
size   = "820 540",
})

-- Games: tearing imediato + sem bordas (FPS 100% destravado sem VSync / sem G-Sync)
hl.window_rule({
name      = "game-fullscreen",
match     = { fullscreen = true },
immediate = true,
border_size = 0,
rounding  = 0,
})

-- Overwatch (Proton/Xwayland, classe steam_app_2357570): tela cheia + tearing → FPS acima dos 180 Hz e sem atraso do compositor
hl.window_rule({
name        = "overwatch-game",
match       = { class = "^steam_app_2357570$" },
fullscreen  = true,
immediate   = true,
border_size = 0,
rounding    = 0,
})

-- Resident Evil 2 (Proton/Xwayland, classe steam_app_883710): tela cheia + tearing → FPS acima dos 180 Hz
hl.window_rule({
name        = "re2-game",
match       = { class = "^steam_app_883710$" },
fullscreen  = true,
immediate   = true,
border_size = 0,
rounding    = 0,
})

-- Minecraft & PrismLauncher: FPS máximo destravado e menor latência de entrada
hl.window_rule({
name      = "minecraft-fps",
match     = { class = "^([mM]inecraft.*|[nN]et\\.minecraft.*|com\\.mojang\\.minecraft.*|org\\.prismlauncher.*|[jJ]ava.*)$" },
immediate = true,
})

-- Minecraft (Prism / Fabric, classe com.mojang.minecraft): tela cheia automática.
-- O Hyprland só faz tearing (FPS acima dos Hz do monitor) em janela fullscreen.
hl.window_rule({
name        = "minecraft-game-fullscreen",
match       = { class = "^com\\.mojang\\.minecraft.*" },
fullscreen  = true,
immediate   = true,
border_size = 0,
rounding    = 0,
})

-- Lunar Client (Minecraft 1.8.9 / 26.x): Fullscreen exclusivo automático, tearing ativado, sem bordas
hl.window_rule({
name        = "lunar-client-game-class",
match       = { class = "^Lunar Client [0-9].*" },
fullscreen  = true,
immediate   = true,
border_size = 0,
rounding    = 0,
})

hl.window_rule({
name        = "lunar-client-game-title",
match       = { title = "^Lunar Client [0-9].*" },
fullscreen  = true,
immediate   = true,
border_size = 0,
rounding    = 0,
})

-- Notificações (mako, namespace "notifications"): vidro com blur + entrada deslizando da direita
hl.layer_rule({
name = "mako-glass",
match = { namespace = "notifications" },
blur = true,
ignore_alpha = 0.01,
animation = "slide right",
})

-- QuickShell Layer Rules: Desativa animação externa do Hyprland (animações próprias em QML) + Blur
hl.layer_rule({
name = "quickshell-layer",
match = { namespace = "quickshell" },
no_anim = true,
blur = true,
ignore_alpha = 0.01,
})

-- Terminal (foot / foot-float): 100% Sólido e Preto Simples (Sem Blur / Máxima Economia)
hl.window_rule({
    name     = "terminal-solid",
    match    = { class = "^(foot|foot-float)$" },
    opacity  = "1.0 1.0",
    rounding = 10,
})

-- File Manager (Thunar): cantos arredondados (HyprGlass removido)
hl.window_rule({
    name     = "thunar-rounding",
    match    = { class = "^([tT]hunar)$" },
    rounding = 20,
})

-- Browser (Zen): Padrão normal / 100% Sólido (Sem vidro ou transparência)
hl.window_rule({
    name    = "browser-solid",
    match   = { class = "^(zen|zen-browser)$" },
    opacity = "1.0 1.0",
})






-- USOLINUX: sempre flutuante e centralizado
hl.window_rule({
    name   = "usolinux-float",
    match  = { title = "^(USOLINUX)$" },
    float  = true,
    center = true,
    size   = "820 540",
})


------------------------
---- MODO GAMING ----
------------------------
-- Ligado pelo tile "Gaming" do Quickshell (~/.local/bin/gaming-mode): sem animações,
-- blur, sombra nem dim — tudo instantâneo. Lido a cada reload.
local gm_f = io.open(HOME .. "/.config/hypr/gaming_mode", "r")
if gm_f then
    local gm = gm_f:read("*all") or ""
    gm_f:close()
    if gm:match("on") then
        hl.config({
            animations = { enabled = false },
            decoration = {
                blur = { enabled = false },
                shadow = { enabled = false },
                dim_inactive = false,
            },
            misc = {
                animate_mouse_windowdragging = false,
                animate_manual_resizes = false,
            },
        })
    end
end
