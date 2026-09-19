-- ============================================================
-- ENVIRONMENT VARIABLES - NVIDIA + Wayland + Performance
-- ============================================================

-- NVIDIA Wayland obrigatório
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Forçar Hyprland / Aquamarine a priorizar a dGPU NVIDIA (RTX 4050)
-- NOTA: caminhos com ':' (como by-path pci-0000:01:00.0-card) quebram o parser do Aquamarine (que usa ':' como delimitador).
-- Usamos symlinks udev sem ':' criados em /etc/udev/rules.d/99-gpu-devices.rules
hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/amd-igpu")

-- Forçar Vulkan e EGL a usar diretamente o driver proprietário NVIDIA
hl.env("VK_DRIVER_FILES", "/usr/share/vulkan/icd.d/nvidia_icd.json")
hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/10_nvidia.json")


-- Wayland nativo para apps Qt/GTK
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")            -- Firefox em Wayland puro nativo (zero Xwayland)
hl.env("MOZ_WEBRENDER", "1")                 -- Aceleração total WebRender na GPU
hl.env("NO_AT_BRIDGE", "1")                 -- Desativa barramento de acessibilidade (economiza ~25MB de RAM)
hl.env("MALLOC_TRIM_THRESHOLD_", "131072")  -- Força glibc a devolver RAM desalocada imediatamente (128 KB)

-- NVIDIA performance (Máximo FPS e menor latência)
hl.env("__GL_GSYNC_ALLOWED", "0")      -- sem G-Sync (elimina overhead e travamentos)
hl.env("__GL_VRR_ALLOWED", "0")        -- sem VRR
hl.env("__GL_SYNC_TO_VBLANK", "0")     -- destrava FPS sem sincronização vertical
hl.env("vblank_mode", "0")             -- desativa V-Sync Mesa/OpenGL
hl.env("__GL_MaxFramesAllowed", "1")   -- buffer de 1 frame = latência mínima de resposta
hl.env("__GL_THREADED_OPTIMIZATIONS", "1") -- multithreading no driver OpenGL
hl.env("PROTON_ENABLE_NVAPI", "1")     -- NVAPI para Proton/Wine
hl.env("DXVK_ASYNC", "1")             -- DXVK async shaders

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Terminal padrão
hl.env("TERMINAL", "foot")

-- Dark Theme Global (GTK + Qt)
hl.env("GTK_THEME", "adw-gtk3-dark")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")
