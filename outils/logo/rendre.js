// Rend un SVG en PNG avec Chromium (Playwright), fond transparent conservé.
//   node outils/logo/rendre.js <entree.svg> <taille> <sortie.png> [rayon_coins_%]
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [entree, taille, sortie, coins] = process.argv.slice(2);
  const n = parseInt(taille, 10);
  const svg = fs.readFileSync(entree, 'utf8');
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: n, height: n }, deviceScaleFactor: 1 });
  const r = coins ? `border-radius:${coins}%;overflow:hidden;` : '';
  await p.setContent(`<html><body style="margin:0;background:transparent">
    <div style="width:${n}px;height:${n}px;${r}">
    <img style="width:${n}px;height:${n}px;display:block" src="data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}"></div></body></html>`);
  await p.waitForTimeout(50);
  await p.screenshot({ path: sortie, omitBackground: true, clip: { x: 0, y: 0, width: n, height: n } });
  await b.close();
})();
