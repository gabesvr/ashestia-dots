// Invariantes dos layouts (Layouts.js): todos os tiles dentro da tela, sem sobreposição, turbo ocupa 2 casas.
// uso: node tests/layouts.test.mjs
import fs from "node:fs"; import assert from "node:assert";
const src = fs.readFileSync(new URL("../launcher/Layouts.js", import.meta.url), "utf8").replace(/^\.pragma library\s*$/m, "");
const L = new Function(src + "; return { compute, placeTiles, cellsUsed };")();
const keys = ["wifi","bt","turbo","battery","gaming","dnd","xwayland","wallpaper","theme","claude","laptop","gpu"];
for (const [W,H] of [[1280,800],[1536,960],[1920,1080]]) {
  const ls = L.compute(W, H, keys, ["turbo"]);
  assert.equal(ls.length, 10);
  for (const l of ls) {
    const gridKeys = keys.filter(k => !l.pos[k]);
    const t = {}; L.placeTiles(t, l.tiles, gridKeys, ["turbo"]);
    for (const k of keys) if (l.pos[k]) t[k] = l.pos[k];
    const r = keys.map(k => t[k]);
    // tudo que o layout posiciona também cabe na tela
    for (const k in l.pos) { const b = l.pos[k]; if (b.height > 0) assert(b.x >= 0 && b.y >= 0 && b.x + b.width <= W + 1 && b.y + b.height <= H + 1, `${k} fora da tela no layout ${l.id}: ${JSON.stringify(b)}`); }
    for (const a of r) assert(a.x >= 0 && a.y >= 0 && a.x + a.width <= W && a.y + a.height <= H, `fora da tela layout ${l.id}`);
    for (let i = 0; i < r.length; i++) for (let j = i + 1; j < r.length; j++) {
      const a = r[i], b = r[j];
      assert(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y, `sobreposição layout ${l.id}: ${keys[i]} × ${keys[j]}`);
    }
    // tiles não invadem os cards do layout (clima, player, relógio…)
    for (const k of keys) for (const pk in l.pos) {
      if (keys.includes(pk)) continue;
      const a = t[k], b = l.pos[pk];
      if (!b.height || pk === "dock" || pk === "cava") continue;   // o dock fica atrás dos tiles; o cava some se não couber
      if (b.variant === "ring") {   // relógio redondo (Orbit): distância ao centro, não o retângulo
        const dx = a.x + a.width / 2 - (b.x + b.width / 2), dy = a.y + a.height / 2 - (b.y + b.height / 2);
        assert(Math.hypot(dx, dy) >= b.width / 2 + Math.min(a.width, a.height) / 2 - 1, `tile ${k} invade o relógio redondo no layout ${l.id} (${W}x${H})`);
        continue;
      }
      assert(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y, `tile ${k} invade ${pk} no layout ${l.id} (${W}x${H})`);
    }
    if (!l.pos.turbo && !l.tiles.orbit && l.tiles.cols >= 2) assert.equal(t.turbo.width, 2 * l.tiles.size + l.tiles.gap);
  }
}
console.log("ok");
