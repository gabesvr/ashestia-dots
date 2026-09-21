-- ============================================================
-- HYPRLAND CONFIG - FA607NUG | RTX 4050 | Ryzen 7 7445HS
-- CachyOS | Kernel 7.2.x-cachyos | Zero-latency Gaming Setup
-- ============================================================

-- Carregar variáveis de ambiente (NVIDIA + Wayland)
require("env")

-- Programas padrão (foot standalone lê foot.ini direto, 100% sólido e preto simples)
local terminal    = "foot"
local browser     = "firefox"
local fileManager = "thunar"
local islandMenu    = "/home/gabriel/.local/bin/island-toggle"     -- QuickShell Control Center / Island


------------------
---- MONITORS ----
------------------

-- Monitor externo: AOC 24G4 via HDMI — 1920x1080@180Hz (Sem G-Sync/VRR para máximo FPS e menor latência)
hl.monitor({
output   = "HDMI-A-1",
mode     = "1920x1080@180",
position = "0x0",
scale    = 1,
bitdepth = 8,
vrr      = 0,
})

-- Monitor interno: eDP-1 desativado (usando apenas o monitor externo para máxima performance)
hl.monitor({
output   = "eDP-1",
disabled = true,
})


---------------------
---- AUTOSTART ------
---------------------

-- API correta para Hyprland 0.47+: hl.on("hyprland.start", fn)
-- Equivalente ao exec-once do .conf legado
hl.on("hyprland.start", function()
-- Portal XDG (necessário para screenshare, file picker, etc.)
hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
-- Agente Polkit (permissões gráficas)
hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
-- Persistência de clipboard (copiar e colar não se perde quando app fecha)
hl.exec_cmd("wl-clip-persist --clipboard regular")
hl.exec_cmd("wl-paste --watch cliphist store")
-- Terminal Foot Server (abertura instantânea com zero cold start e memória compartilhada)
hl.exec_cmd("foot --server")
-- Wallpaper daemon ultraleve (swaybg)
hl.exec_cmd("/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh init")
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
-- Desligar completamente o backlight da tela do laptop (eDP-1 desativada, 0% brilho/luz)
hl.exec_cmd("brightnessctl -d nvidia_0 set 0")
-- Carregar plugin HyprGlass (Apple Liquid Glass nativo)
hl.exec_cmd("hyprctl plugin load /home/gabriel/.config/hypr/plugins/hyprglass.so")
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
local xw_f = io.open("/home/gabriel/.config/hypr/xwayland_state", "r")
if xw_f then
    local content = xw_f:read("*all") or ""
    xw_f:close()
    if content:match("false") or content:match("0") then
        xwayland_enabled = false
    end
end

hl.config({
    render = {
        direct_scanout = 1,
    },
    xwayland = {
        enabled = xwayland_enabled,
        force_zero_scaling = true,
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

-- ── Curvas de animação estilo Apple macOS (Vivas, Orgânicas e Fluidas) ──────────
-- macFluid: curva de desaceleração suave e viva da Apple — movimento elegante com tempo para ser apreciado
hl.curve("macFluid",     { type = "bezier", points = { {0.25, 1.00}, {0.50, 1.0} } })
-- macMove: rastreamento dinâmico e suave — no float desliza fluido atrás do mouse, no tiling transiciona limpo sem repelir
hl.curve("macMove",      { type = "bezier", points = { {0.20, 1.00}, {0.40, 1.0} } })
-- macClose: fechamento direto, limpo e orgânico sem hesitação
hl.curve("macClose",     { type = "bezier", points = { {0.25, 0.00}, {0.00, 1.0} } })
-- macSpaces: deslizamento suave idêntico ao Spaces / Mission Control do trackpad macOS
hl.curve("macSpaces",    { type = "bezier", points = { {0.20, 1.00}, {0.20, 1.0} } })
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1.00}, {0.32, 1.0} } })
hl.curve("fast",         { type = "bezier", points = { {0.05, 0.95}, {0.10, 1.0} } })

-- ── Janelas (Física Fluida e Visível) ─────────────────────────────────
-- Abrir: popin visível (começa em 78% e expande suavemente com fade fluido) (~350ms)
hl.animation({ leaf = "windows",     enabled = true, speed = 3.5, bezier = "macFluid", style = "popin 78%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3.5, bezier = "macFluid", style = "popin 78%" })
-- Fechar: saída rápida e limpa (~200ms)
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.0, bezier = "macClose", style = "popin 85%" })
-- Mover e arrastar: animação contínua e visível seguindo o mouse no float, firme no tiling (~360ms)
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.6, bezier = "macMove" })

-- ── Fades (Transparência sincronizada e viva) ────────────────────────
hl.animation({ leaf = "fade",        enabled = true, speed = 2.8, bezier = "macFluid" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 2.8, bezier = "macFluid" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.0, bezier = "macClose" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 2.8, bezier = "macFluid" })
hl.animation({ leaf = "fadeShadow",  enabled = true, speed = 2.8, bezier = "macFluid" })

-- ── Layers (Dynamic Island, launcher, notificações) ──────────────────
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3.0, bezier = "macFluid", style = "popin 88%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2.0, bezier = "macClose", style = "fade" })

-- ── Workspaces (Transição de áreas estilo Spaces do macOS) ───────────
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 3.6, bezier = "macSpaces", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.2, bezier = "macSpaces", style = "slidefade 20%" })


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
min_refresh_rate    = 180,    -- trava atualização do cursor em 180Hz nativos (evita cair para 24Hz)
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
hl.exec_cmd("/home/gabriel/.local/bin/island-toggle")
end
}
})
hl.gesture({
fingers   = 4,
direction = "up",
action    = {
finish = function()
hl.exec_cmd("/home/gabriel/.local/bin/island-toggle")
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
hl.bind(mainMod .. " + W",             hl.dsp.exec_cmd(browser))    -- firefox
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
hl.bind(mainMod .. " + ALT + 2",       hl.dsp.exec_cmd(islandMenu .. " layout 2"))    -- Layout 2: Executive Shelf
hl.bind(mainMod .. " + ALT + 3",       hl.dsp.exec_cmd(islandMenu .. " layout 3"))    -- Layout 3: Smart Sidebar
hl.bind(mainMod .. " + ALT + 4",       hl.dsp.exec_cmd(islandMenu .. " layout 4"))    -- Layout 4: Four Corners
hl.bind(mainMod .. " + ALT + 5",       hl.dsp.exec_cmd(islandMenu .. " layout 5"))    -- Layout 5: Creative Studio
hl.bind(mainMod .. " + V",             hl.dsp.window.pseudo())
hl.bind(mainMod .. " + P",             hl.dsp.layout("togglesplit"))

-- Screenshot — grim + slurp + wl-copy (salva arquivo E copia pro clipboard)
hl.bind("SUPER + SHIFT + S",  hl.dsp.exec_cmd("/home/gabriel/.local/bin/screenshot region"), { locked = false })
hl.bind("Print",               hl.dsp.exec_cmd("/home/gabriel/.local/bin/screenshot full"))
hl.bind("SUPER + Print",       hl.dsp.exec_cmd("/home/gabriel/.local/bin/screenshot window"))

-- Lock screen (SUPER+ALT+L ou SUPER+Escape)
hl.bind(mainMod .. " + ALT + L",       hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Escape",        hl.dsp.exec_cmd("hyprlock"))

-- Reload config
hl.bind(mainMod .. " + SHIFT + R",     hl.dsp.exec_cmd("hyprctl reload"))

-- Exit / Shutdown
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

-- === Gaming Mode toggle ===
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("sudo /usr/local/bin/gaming-mode.sh"), { locked = false })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

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
tag    = "+hyprglass_disabled",
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

-- Minecraft & PrismLauncher: FPS máximo destravado e menor latência de entrada
hl.window_rule({
name      = "minecraft-fps",
match     = { class = "^([mM]inecraft.*|[nN]et\\.minecraft.*|org\\.prismlauncher.*|[jJ]ava.*)$" },
immediate = true,
})

-- QuickShell Layer Rules: Desativa animação externa do Hyprland (animações próprias em QML) + Blur
hl.layer_rule({
name = "quickshell-layer",
match = { namespace = "quickshell" },
no_anim = true,
blur = true,
ignore_alpha = 0.01,
})

--------------------------------
---- HYPRGLASS LIQUID GLASS ----
--------------------------------

if hl.plugin and hl.plugin.hyprglass then
local hg = hl.plugin.hyprglass

-- Preset Crystal Liquid Glass: Apple-style translucent, non-dark, refractive glass
hg.preset("crystal_liquid", {
glass_opacity        = 1.0,
blur_strength        = 2.0,
blur_iterations      = 3,
refraction_strength  = 1.0,
chromatic_aberration = 1.0,
fresnel_strength     = 0.90,
specular_strength    = 1.0,
edge_thickness       = 0.09,
lens_distortion      = 0.60,
brightness           = 1.15,
contrast             = 1.08,
saturation           = 1.25,
vibrancy             = 0.35,
adaptive_dim         = 0.0,
adaptive_boost       = 0.35,
tint_color           = 0xffffff24,
light = {
brightness       = 1.18,
adaptive_dim     = 0.0,
adaptive_boost   = 0.35,
tint_color       = 0xffffff28,
},
dark = {
brightness       = 1.15,
adaptive_dim     = 0.0,
adaptive_boost   = 0.32,
tint_color       = 0xffffff22,
},
})

hg.config({
default_theme  = "light",
layers         = { enabled = false },
})

-- quickshell sem contorno/borda de hyprglass
-- hg.layer("quickshell", { preset = "crystal_liquid", mask_threshold = 0.05 })
-- hg.layer("quickshell:bezel", { preset = "crystal_liquid", mask_threshold = 0.1 })
end

-- Terminal (foot / foot-float): 100% Sólido e Preto Simples (Sem HyprGlass / Sem Blur / Máxima Economia)
hl.window_rule({
    name     = "terminal-solid",
    match    = { class = "^(foot|foot-float)$" },
    tag      = "+hyprglass_disabled",
    opacity  = "1.0 1.0",
    rounding = 10,
})

-- File Manager (Thunar): Efeito Crystal Liquid Glass
hl.window_rule({
    name     = "thunar-liquid-glass",
    match    = { class = "^([tT]hunar)$" },
    tag      = "+hyprglass_preset_crystal_liquid",
    rounding = 20,
})

hl.window_rule({
    name  = "thunar-liquid-light",
    match = { class = "^([tT]hunar)$" },
    tag   = "+hyprglass_theme_light",
})

-- Browser (Firefox): Padrão normal / 100% Sólido (Sem vidro ou transparência)
hl.window_rule({
    name    = "firefox-solid",
    match   = { class = "^(firefox|org\\.mozilla\\.firefox)$" },
    opacity = "1.0 1.0",
})





