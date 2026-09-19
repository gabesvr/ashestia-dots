# ❄️ Ashestia Hyprland Rice

> Setup minimalista, moderno e focado em zero-latency para jogos e produtividade diária no Linux (CachyOS / Arch Linux).

---

## 🖥️ Especificações do Setup do Criador
* **Sistema Operacional:** CachyOS (Linux Kernel BORE / cachyos)
* **Hardware:** ASUS TUF Gaming FA607NUG (AMD Ryzen 7 7445HS | NVIDIA GeForce RTX 4050 Laptop 140W)
* **Window Manager / Compositor:** Hyprland 0.47+ (Configurado em Lua puro com `hyprland.lua`)
* **Barra & Widgets:** QuickShell Control Center / Island (Dynamic widgets & LiquidGlass)
* **Terminal:** foot / footclient (instantâneo via daemon systemd, transparência 0.80)
* **Paleta & Cores:** Matugen (geração dinâmica de cores baseada no wallpaper)
* **Fetch & Imagens no Terminal:** Fastfetch integrado com exibição gráfica via Sixel e rotação automática de imagens em `~/Pictures/Goticas`
* **Visualizador de Áudio:** Cava
* **Notificações:** Mako

---

## 🖤 Foot Terminal & Fastfetch Sixel
O **Foot** vem configurado com:
* **Transparência suave (`alpha=0.80`)** e fonte `JetBrainsMono Nerd Font`.
* **Tema Dinâmico:** Cores sincronizadas em tempo real com o wallpaper via Matugen.
* **Fish Greeting & Fastfetch:** Toda vez que você abre o terminal, o script seleciona automaticamente a próxima imagem da coleção em `~/Pictures/Goticas` e renderiza em alta definição direto no terminal via **Sixel Graphics**.

---

## 🚀 Instalação Rápida

Clone o repositório ou baixe o arquivo comprimido, entre na pasta e execute:

```bash
git clone https://github.com/gabesvr/ashestia-dots.git
cd ashestia-dots
chmod +x install.sh
./install.sh
```

---

## ⌨️ Principais Atalhos (Keybindings)

| Teclas de Atalho | Ação |
| :--- | :--- |
| `Super + Enter` | Abrir Terminal (`footclient`) |
| `Super + B` | Abrir Navegador (`Firefox`) |
| `Super + E` | Abrir Gerenciador de Arquivos (`Thunar`) |
| `Super + Space` | Abrir Island Menu / QuickShell Control Center |
| `Super + Shift + S` | Captura de tela por seleção de região |
| `Print` | Captura de tela cheia |
| `Super + Q` | Fechar janela ativa |
| `Super + V` | Alternar janela flutuante |
| `Super + [1-9]` | Alternar para o Workspace correspondente |

---

## 📺 Configuração de Monitores
Por padrão, o arquivo `hyprland.lua` vem configurado para **modo universal automático** (`preferred, auto, 1`), adaptando-se a qualquer monitor e resolução. Caso queira configurar uma taxa de quadros fixa (como 144Hz ou 180Hz) ou múltiplos monitores, basta editar a seção `---- MONITORS ----` em `~/.config/hypr/hyprland.lua`.

---
*Criado por Gabriel • Comunidade Ashestia*
