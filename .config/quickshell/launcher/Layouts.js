.pragma library
// Definição dos layouts da área de trabalho (funções puras; testadas por tests/layouts.test.mjs).
// compute(W, H, tileKeys, wideTiles) -> lista de layouts; cada posição é { x, y, width, height, variant?, hidden? }.
// wideTiles: tiles que ocupam 2 casas da grade (ex.: a chave de energia).

function compute(W, H, tileKeys, wideTiles) {
    const tileCells = tileKeys.length + wideTiles.length;
    if (!W || W <= 0) W = 1920;
    if (!H || H <= 0) H = 1200;

    const m = Math.round(Math.max(24, Math.min(50, W * 0.025)));  // margem da tela
    const g = 14;                                                  // espaço entre cards
    const R = W - m - 340;                                         // x da coluna direita (340px)
    const bottom = H - m;

    function box(x, y, w, h) { return { x: x, y: y, width: w, height: h }; }
    function grid(x, y, cols, size, gap) { return { x: x, y: y, cols: cols, size: size, gap: gap }; }
    // Grade que cabe em w×hAvail com todos os tiles: escolhe o nº de colunas que dá o maior tile (≤ maxSize)
    function fitGrid(x, y, w, hAvail, maxSize, gap) {
        const n = tileCells;
        let best = null;
        for (let cols = 1; cols <= n; cols++) {
            const rows = Math.ceil(cellsUsed(tileKeys, cols, wideTiles) / cols);
            const s = Math.floor(Math.min(maxSize, (w - (cols - 1) * gap) / cols, (hAvail - (rows - 1) * gap) / rows));
            if (!best || s > best.size) best = grid(x, y, cols, s, gap);
        }
        return best;
    }

    // Duas colunas de painéis (usado nos layouts 1 e 3): coluna A (240px) + coluna B (340px, à direita)
    function flanks(id, name, desc, ax) {
        const clockY = m, calY = m + 140 + g, volY = calY + 195 + g, appsY = volY + 160 + g;
        const musicY = m + 340 + g, tilesY = musicY + 160 + g;
        // Tiles: 4 colunas de 76 se couberem até o fundo; senão (ex.: escala 1.5 → 800 de altura) a grade se ajusta ao espaço
        const tilesAvail = bottom - tilesY;
        const tilesGrid = Math.ceil(cellsUsed(tileKeys, 4, wideTiles) / 4) * 88 - 12 <= tilesAvail
            ? grid(R, tilesY, 4, 76, 12)
            : fitGrid(R, tilesY, 340, tilesAvail, 76, 12);
        // Cava ao lado dos tiles da última linha (se ela não estiver cheia); senão, abaixo da grade
        const tStep = tilesGrid.size + tilesGrid.gap;
        const tUsed = cellsUsed(tileKeys, tilesGrid.cols, wideTiles);
        const tileRows = Math.ceil(tUsed / tilesGrid.cols);
        const lastRowN = tUsed - (tileRows - 1) * tilesGrid.cols;
        const cavaBox = lastRowN < tilesGrid.cols
            ? box(R + lastRowN * tStep, tilesY + (tileRows - 1) * tStep, 340 - lastRowN * tStep, tilesGrid.size)
            : box(R, tilesY + tileRows * tStep - tilesGrid.gap + g, 340, bottom - (tilesY + tileRows * tStep - tilesGrid.gap + g));
        return {
            id: id, name: name, desc: desc, m: m, g: g,
            pos: {
                clock:    box(ax, clockY, 240, 140),
                calendar: box(ax, calY, 240, 195),
                vol:      box(ax, volY, 113, 160),
                br:       box(ax + 127, volY, 113, 160),
                apps:     box(ax, appsY, 240, 68),
                weather:  box(R, m, 340, 340),
                music:    box(R, musicY, 340, 160),
                cava:     cavaBox
            },
            cavaExpand: "below",                            // painel expandido ocupa os tiles → cava desce p/ baixo dele
            cavaLyrics: "below",                            // lyrics (420px) cobre os tiles → cava desce p/ baixo do player
            tiles:  tilesGrid,
            alt:    fitGrid(ax, appsY + 68 + g, 240, bottom - (appsY + 68 + g), 72, 12),   // tiles migram p/ baixo do Apps quando algo expande
            expand: { x: R, y: tilesY },
            lyrics: { music: { x: R, y: musicY, height: 420 }, tiles: "alt" }
        };
    }

    // Layout 2: prateleira no topo, deixa toda a metade de baixo livre para janelas
    const shelfVolX = m + 254 + 240 + g;
    const shelfTilesX = shelfVolX + 172 + g;
    // Player ao lado dos tiles, no topo, quando a largura permite (≥ 4 colunas e ≤ 3 linhas);
    // senão, tiles em 2 linhas e o player logo abaixo deles
    const besideCols = Math.floor((R - g - 340 - g - shelfTilesX + 12) / 88);
    const shelfBeside = besideCols >= 4 && Math.ceil(tileCells / besideCols) <= 3;
    const shelfCols = shelfBeside
        ? Math.min(besideCols, Math.ceil(tileCells / 2))
        : Math.max(4, Math.min(Math.ceil(tileCells / 2), Math.floor((R - g - shelfTilesX + 12) / 88)));
    const shelfRows = Math.ceil(tileCells / shelfCols);
    const shelfMusicX = shelfBeside ? shelfTilesX + shelfCols * 88 - 12 + g : Math.min(shelfTilesX, R - g - 340);
    const shelfMusicY = shelfBeside ? m : m + 76 * shelfRows + 12 * (shelfRows - 1) + g;
    // Tela estreita (ex.: 1280 de largura com escala 1.5): não cabem 4 colunas entre o volume e o clima →
    // os tiles descem para uma 2ª prateleira na largura toda até o clima, e o player fica logo abaixo dela
    const shelfNarrow = Math.floor((R - g - shelfTilesX + 12) / 88) < 4;
    const shelf2Y = m + 140 + g + 68 + g;
    const shelf2Cols = Math.max(1, Math.floor((R - g - m + 12) / 88));
    const shelf2Rows = Math.ceil(cellsUsed(tileKeys, shelf2Cols, wideTiles) / shelf2Cols);
    const shelfTiles = shelfNarrow ? grid(m, shelf2Y, shelf2Cols, 76, 12) : grid(shelfTilesX, m, shelfCols, 76, 12);
    const shelfMX = shelfNarrow ? m : shelfMusicX;
    const shelfMY = shelfNarrow ? shelf2Y + shelf2Rows * 88 - 12 + g : shelfMusicY;

    // Layout 4: quatro cantos + console central
    const rowY = bottom - 72;
    const volY4 = bottom - 88;
    const music4Y = volY4 - g - 160;
    const lyr4H = Math.min(420, volY4 - g - (m + 340 + g));
    // Tiles numa linha, centralizados no vão entre Apps (esq.) e volume/brilho (dir.); encolhem se não couberem
    const n4 = tileCells, x4a = m + 240 + g, x4b = R - g;
    const s4 = Math.min(72, Math.floor((x4b - x4a - (n4 - 1) * 8) / n4));
    const w4 = n4 * s4 + (n4 - 1) * 8;
    const tiles4X = Math.min(x4b - w4, Math.max(x4a, Math.round((W - w4) / 2)));

    // Layout 5: trilho esquerdo + palco direito
    const cal5 = m + 140 + g, wea5 = cal5 + 195 + g;
    const vol5 = m + 160 + g, br5 = vol5 + 68 + g, tiles5 = br5 + 68 + g;
    // Trilho esquerdo alto demais (ex.: 800 de altura): o Apps vai para o lado do último tile, à direita
    const apps5Right = wea5 + 340 + g + 68 > bottom;
    const t5Used = cellsUsed(tileKeys, 4, wideTiles), t5Rows = Math.ceil(t5Used / 4), t5Last = t5Used - (t5Rows - 1) * 4;
    const cava5 = apps5Right ? wea5 + 340 + g : wea5 + 340 + g + 68 + g;

    const list = [
        flanks(1, "Sonoma Flanks", "Equilíbrio Lateral", m),

        {
            id: 2, name: "Top Shelf", desc: "Prateleira Superior", m: m, g: g,
            pos: {
                clock:    box(m, m, 240, 140),
                apps:     box(m, m + 140 + g, 240, 68),
                calendar: box(m + 254, m, 240, 195),
                vol:      box(shelfVolX, m, 172, 68),
                br:       box(shelfVolX, m + 82, 172, 68),
                music:    box(shelfMX, shelfMY, 340, 160),
                weather:  box(R, m, 340, 340),
                cava:     box(R, m + 340 + g, 340, 96)
            },
            tiles:  shelfTiles,
            // estreito: o painel abre ao lado do player (espaço livre) e os tiles ficam onde estão
            alt:    shelfNarrow ? "keep" : fitGrid(m, m + 140 + g + 68 + g, 240, bottom - (m + 140 + g + 68 + g), 72, 12),
            expand: shelfNarrow ? { x: m + 340 + g, y: shelfMY } : { x: shelfTilesX, y: m },
            expandOver: (shelfBeside || shelfNarrow) ? undefined : { music: { y: m + 290 + g } },
            lyrics: { music: { x: shelfMX, y: shelfMY, height: 420 }, tiles: "keep" }
        },

        flanks(3, "Smart Sidebar", "Painel Direito", R - 240 - g),

        {
            id: 4, name: "Four Corners", desc: "Quatro Cantos HUD", m: m, g: g,
            pos: {
                clock:    box(m, m, 240, 140),
                weather:  box(R, m, 340, 340),
                calendar: box(m, rowY - g - 195, 240, 195),
                apps:     box(m, rowY, 240, 72),
                music:    box(R, music4Y, 340, 160),
                vol:      box(R, volY4, 162, 88),
                br:       box(R + 178, volY4, 162, 88),
                cava:     box(Math.round((W - 420) / 2), m, 420, 96)
            },
            tiles:  grid(tiles4X, bottom - s4, n4, s4, 8),
            alt:    "keep",
            expand: { x: Math.round((W - 340) / 2), y: rowY - g - 290 },
            lyrics: { music: { x: R, y: volY4 - g - lyr4H, height: lyr4H }, tiles: "keep" }
        },

        {
            id: 5, name: "Creative Studio", desc: "Trilho Esquerdo + Palco", m: m, g: g,
            pos: {
                clock:    box(m, m, 240, 140),
                calendar: box(m, cal5, 240, 195),
                weather:  box(m, wea5, 240, 340),
                apps:     apps5Right ? box(R + t5Last * 88, tiles5 + (t5Rows - 1) * 88, 340 - t5Last * 88, 76) : box(m, wea5 + 340 + g, 240, 68),
                music:    box(R, m, 340, 160),
                vol:      box(R, vol5, 340, 68),
                br:       box(R, br5, 340, 68),
                cava:     box(m, cava5, 240, bottom - cava5)
            },
            tiles:  grid(R, tiles5, 4, 76, 12),
            alt:    "below",
            expand: { x: R, y: tiles5 },
            lyrics: { music: { x: R, y: m, height: 420 }, tiles: "shift", dy: 260, shift: ["vol", "br"] }
        }
    ];
    return list.concat(creative(W, H, m, g, tileKeys, wideTiles));
}

// Distribui os 6 tiles numa grade
// Nº de casas que placeTiles gasta com `cols` colunas (inclui a casa pulada quando o tile largo não cabe no fim da linha)
function cellsUsed(keys, cols, wideTiles) {
    let cell = 0;
    for (const k of keys) {
        const span = (wideTiles.indexOf(k) >= 0 && cols >= 2) ? 2 : 1;
        if (span === 2 && cell % cols === cols - 1) cell++;
        cell += span;
    }
    return cell;
}

// Preenche a grade em ordem; tiles de wideTiles ocupam 2 casas (pulam p/ a próxima linha se não couberem)
function placeTiles(t, gr, keys, wideTiles) {
    // Órbita: tiles em círculo em volta de (cx, cy), começando no topo
    if (gr.orbit) {
        for (let i = 0; i < keys.length; i++) {
            const a = -Math.PI / 2 + i * 2 * Math.PI / keys.length;
            t[keys[i]] = { x: Math.round(gr.cx + gr.r * Math.cos(a) - gr.size / 2), y: Math.round(gr.cy + gr.r * Math.sin(a) - gr.size / 2),
                           width: gr.size, height: gr.size, variant: gr.variant };
        }
        return;
    }
    let cell = 0;
    for (let i = 0; i < keys.length; i++) {
        const span = (wideTiles.indexOf(keys[i]) >= 0 && gr.cols >= 2) ? 2 : 1;
        if (span === 2 && cell % gr.cols === gr.cols - 1) cell++;
        const c = cell % gr.cols, r = Math.floor(cell / gr.cols);
        t[keys[i]] = { x: gr.x + c * (gr.size + gr.gap), y: gr.y + r * (gr.size + gr.gap), width: span * gr.size + (span - 1) * gr.gap, height: gr.size, variant: gr.variant };
        cell += span;
    }
}

// ── Layouts 6–10: cada widget muda de visual (variant) além de lugar ──
// Widgets que não aparecem em `pos` somem (variant "hidden"; compostos com `shown` ficam escondidos).
// Tiles que não estão em `pos` vão para `tiles` (grade ou órbita).
function creative(W, H, m, g, tileKeys, wideTiles) {
    function box(x, y, w, h, variant) { return { x: Math.round(x), y: Math.round(y), width: Math.round(w), height: Math.round(h), variant: variant }; }
    const out = [];
    const nSmall = tileKeys.length - wideTiles.length;      // tiles de 1 casa

    // 6 · Hero Clock — relógio gigante no centro, clima numa linha, player em pílula, tiles num dock redondo
    {
        const ts = 52, tg = 10, pad = 14;
        const cells = tileKeys.length + wideTiles.length;
        const dw = cells * ts + (cells - 1) * tg + 2 * pad, dh = ts + 2 * pad;
        const dx = (W - dw) / 2, dy = H - m - dh;
        const cw = Math.min(W * 0.7, 980), ch = Math.min(H * 0.34, 300);
        const cy = H * 0.14;
        const music = box((W - 460) / 2, dy - 64 - 18, 460, 64, "pill");
        out.push({
            id: 6, name: "Hero Clock", desc: "Relógio Gigante", m: m, g: g,
            pos: {
                clock: box((W - cw) / 2, cy, cw, ch, "hero"),
                weather: box((W - 470) / 2, cy + ch + 18, 470, 50, "line"),
                music: music,
                dock: box(dx, dy, dw, dh)
            },
            tiles: { x: dx + pad, y: dy + pad, cols: cells, size: ts, gap: tg, variant: "circle" },
            alt: "keep",
            expand: { x: (W - 340) / 2, y: cy },   // painel toma o lugar do relógio gigante (clima, player e dock ficam)
            lyrics: { music: { x: music.x, y: music.y, height: music.height }, tiles: "keep" }
        });
    }

    // 7 · Bento — grade de caixas de tamanhos diferentes à direita, números grandes
    {
        const x0 = Math.round(W * 0.34), wb = W - m - x0;
        const c = Math.floor((wb - 3 * g) / 4);
        const col = i => x0 + i * (c + g), row = i => m + i * (c + g);
        const tilesY = row(2), tilesX = col(1), tilesW = 3 * c + 2 * g;
        const rest = H - m - tilesY;
        const music = box(col(0), row(1), c, H - m - row(1), "cover");
        // tiles: grade que cabe no canto de baixo à direita
        let best = null;
        for (let cols = 3; cols <= 12; cols++) {
            let cell = 0;
            for (const k of tileKeys) { const sp = wideTiles.indexOf(k) >= 0 ? 2 : 1; if (sp === 2 && cell % cols === cols - 1) cell++; cell += sp; }
            const rows = Math.ceil(cell / cols);
            const sz = Math.floor(Math.min(76, (tilesW - (cols - 1) * 12) / cols, (rest - (rows - 1) * 12) / rows));
            if (!best || sz > best.size) best = { x: tilesX, y: tilesY, cols: cols, size: sz, gap: 12 };
        }
        const volH = Math.round((c - g) / 2);
        out.push({
            id: 7, name: "Bento", desc: "Caixas Apple", m: m, g: g,
            pos: {
                clock: box(col(0), row(0), 2 * c + g, c, "bento"),
                weather: box(col(2), row(0), c, c, "number"),
                battery: box(col(3), row(0), c, c, "big"),
                music: music,
                vol: box(col(1), row(1), c, volH),
                br: box(col(1), row(1) + volH + g, c, volH),
                calendar: box(col(2), row(1), Math.min(2 * c + g, 240), Math.min(c, 195)),
                apps: box(col(2) + Math.min(2 * c + g, 240) + g, row(1), Math.max(68, 2 * c + g - Math.min(2 * c + g, 240) - g), 68)
            },
            tiles: best,
            alt: "keep",
            expand: { x: col(1), y: tilesY },
            lyrics: { music: { x: music.x, y: music.y, height: music.height }, tiles: "keep" }
        });
    }

    // 8 · Orbit — relógio redondo no centro, tiles circulares em órbita, vinil girando no canto
    {
        const cx = W / 2, cy = H * 0.47;
        const d = Math.min(H * 0.4, 380), ts = 62;
        const r = d / 2 + ts / 2 + 34;
        const music = box(W - m - 230, H - m - 300, 230, 300, "vinyl");
        out.push({
            id: 8, name: "Orbit", desc: "Órbita", m: m, g: g,
            pos: {
                clock: box(cx - d / 2, cy - d / 2, d, d, "ring"),
                weather: box(m, m, 230, 104, "compact"),
                music: music,
                turbo: box(cx - 90, cy + r + ts / 2 + 22, 180, 58)
            },
            tiles: { orbit: true, cx: cx, cy: cy, r: r, size: ts, variant: "circle" },
            alt: "keep",
            expand: { x: m, y: m + 104 + g },
            lyrics: { music: { x: music.x, y: music.y, height: music.height }, tiles: "keep" }
        });
    }

    // 9 · Island — tudo numa ilha escura no topo + trilho fino de tiles redondos; resto da tela livre
    {
        const ts = 46, tg = 10;
        const railH = nSmall * ts + (nSmall - 1) * tg;
        const rx = W - m * 0.6 - ts, ry = (H - railH) / 2;
        out.push({
            id: 9, name: "Island", desc: "Ilha Minimalista", m: m, g: g,
            pos: {
                island: box((W - 600) / 2, Math.round(m * 0.45), 600, 52),
                turbo: box(rx - 180 - 14, H - m - 50, 180, 50)
            },
            tiles: { x: rx, y: ry, cols: 1, size: ts, gap: tg, variant: "circle" },
            alt: "keep",
            expand: { x: rx - 14 - 340, y: ry },
            lyrics: { music: { x: 0, y: 0, height: 0 }, tiles: "keep" }
        });
    }

    // 10 · Editorial — capa de revista: data gigante em serifa, temperatura fina, pôster do álbum
    {
        const tg = 10, cells = tileKeys.length + wideTiles.length;
        const music = box(W - m - Math.min(560, W * 0.4), H - m - 250, Math.min(560, W * 0.4), 250, "poster");
        // fileira de tiles até o pôster (encolhe em telas estreitas)
        const ts = Math.min(50, Math.floor((music.x - g - m - (cells - 1) * tg) / cells));
        out.push({
            id: 10, name: "Editorial", desc: "Capa de Revista", m: m, g: g,
            pos: {
                clock: box(m, m * 0.6, W * 0.5, H * 0.66, "editorial"),
                weather: box(W - m - 420, m, 420, 250, "text"),
                music: music
            },
            tiles: { x: m, y: H - m - ts, cols: cells, size: ts, gap: tg, variant: "circle" },
            alt: "keep",
            expand: { x: Math.round(m + W * 0.5 + g), y: m + 250 + g },   // entre o relógio e o clima; em tela baixa o pôster sai
            lyrics: { music: { x: music.x, y: music.y, height: music.height }, tiles: "keep" }
        });
    }
    return out;
}

// Painel expandido (Wi-Fi/BT/Bateria/Wallpaper) não fica por cima de nada: o widget que ele cobriria desce para
// logo abaixo dele se esse espaço estiver livre (e couber na tela); senão some até o painel fechar. Sem cascata
// (empurrar em cadeia bagunçava layouts inteiros).
function pushAside(t, panelKey, g, bottom) {
    const hit = (a, b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
    const p = t[panelKey];
    const live = k => k !== panelKey && !t[k].hidden && t[k].variant !== "hidden" && t[k].width > 0 && t[k].height > 0;
    const covered = Object.keys(t).filter(k => live(k) && hit(t[k], p));
    const movedDown = [];
    for (const k of covered.sort((a, b) => t[a].y - t[b].y)) {
        const r = t[k];
        const moved = Object.assign({}, r, { y: p.y + p.height + g });
        const free = moved.y + moved.height <= bottom
            && Object.keys(t).every(o => o === k || !live(o) || covered.indexOf(o) >= 0 || !hit(moved, t[o]))
            && movedDown.every(m => !hit(moved, m));
        if (free) { r.y = moved.y; movedDown.push(r); }
        else { r.variant = "hidden"; r.hidden = true; }
    }
}
