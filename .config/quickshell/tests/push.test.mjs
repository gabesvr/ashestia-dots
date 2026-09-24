// pushAside: o painel expandido empurra para logo abaixo dele o que ele cobre, se lá estiver livre; senão, some (sem cascata).
// uso: node tests/push.test.mjs
import fs from "node:fs"; import assert from "node:assert";
const src = fs.readFileSync(new URL("../launcher/Layouts.js", import.meta.url), "utf8").replace(/^\.pragma library\s*$/m, "");
const L = new Function(src + "; return { pushAside };")();
const g = 14, bottom = 768;
// 1. widget coberto pelo painel desce para logo abaixo dele
let t = { panel: { x: 0, y: 100, width: 340, height: 290 }, a: { x: 10, y: 200, width: 100, height: 76 } };
L.pushAside(t, "panel", g, bottom);
assert.equal(t.a.y, 100 + 290 + g);
// 2. sem cascata: se o espaço abaixo do painel já está ocupado, o coberto some e o outro fica onde está
t = { panel: { x: 0, y: 100, width: 340, height: 290 }, a: { x: 10, y: 200, width: 100, height: 76 }, b: { x: 10, y: 420, width: 100, height: 76 } };
L.pushAside(t, "panel", g, bottom);
assert.equal(t.a.variant, "hidden"); assert.equal(t.b.y, 420); assert.notEqual(t.b.variant, "hidden");
// 3. sem espaço até o fundo: some (variant "hidden" + hidden)
t = { panel: { x: 0, y: 478, width: 340, height: 290 }, music: { x: 0, y: 386, width: 340, height: 160 } };
L.pushAside(t, "panel", g, bottom);
assert.equal(t.music.variant, "hidden"); assert.equal(t.music.hidden, true);
// 4. quem não encosta no painel não se mexe; quem está oculto é ignorado
t = { panel: { x: 0, y: 100, width: 340, height: 290 }, c: { x: 400, y: 150, width: 100, height: 76 }, h: { x: 10, y: 200, width: 50, height: 50, hidden: true } };
L.pushAside(t, "panel", g, bottom);
assert.equal(t.c.y, 150); assert.equal(t.h.y, 200);
// 5. dois cobertos um sobre o outro: só o primeiro desce, o segundo some (não empilham no mesmo lugar)
t = { panel: { x: 0, y: 100, width: 340, height: 290 }, a: { x: 10, y: 150, width: 76, height: 76 }, b: { x: 10, y: 238, width: 76, height: 76 } };
L.pushAside(t, "panel", g, bottom);
assert.equal(t.a.y, 404); assert.equal(t.b.variant, "hidden");
console.log("ok");
