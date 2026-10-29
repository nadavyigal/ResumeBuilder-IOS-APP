// Captures the App Preview frames from preview.html, one PNG per frame at 30 fps.
// Run as a Playwright snippet (for example the Playwright MCP "run code" tool) with preview.html
// served over http from this folder:  python3 -m http.server 8791 --bind 127.0.0.1
// Then encode:  swift encode.swift <framesDir> <out.mov> 886 1920
async (page) => {
  const dir = process.env.FRAMES_DIR || '/tmp/resumely-preview-frames';
  await page.setViewportSize({ width: 886, height: 1920 });
  await page.goto('http://127.0.0.1:8791/preview.html');
  await page.evaluate(() => window.ready);
  const total = 21 * 30;
  for (let i = 0; i < total; i++) {
    await page.evaluate(t => window.render(t), i / 30);
    await page.screenshot({ path: `${dir}/f${String(i).padStart(4, '0')}.png`, scale: 'css' });
  }
  return total;
}
