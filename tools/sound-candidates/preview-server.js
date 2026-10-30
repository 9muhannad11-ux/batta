'use strict';
// سيرفر صغير لمعاينة الأصوات والتأثيرات: node preview-server.js  (المنفذ 8099)
// يعرض ملفات هالمجلد، ويحفظ ملف wav يرسله المتصفح (POST /save?name=xxx.wav)
const http = require('http');
const fs = require('fs');
const path = require('path');
const DIR = process.env.DIR ? path.resolve(process.env.DIR) : __dirname;
const PORT = Number(process.env.PORT ?? 8099);
const MIME = { '.html': 'text/html; charset=utf-8', '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.js': 'text/javascript', '.png': 'image/png', '.ogg': 'audio/ogg', '.json': 'application/json' };

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (req.method === 'POST' && url.pathname === '/save') {
    const name = path.basename(url.searchParams.get('name') || '');
    if (!/^[\w-]+\.(wav|png)$/.test(name)) { res.writeHead(400); return res.end('bad name'); }
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => { fs.writeFileSync(path.join(DIR, name), Buffer.concat(chunks)); res.end('saved ' + name); });
    return;
  }
  const file = path.join(DIR, url.pathname === '/' ? 'hand-slap.html' : path.basename(url.pathname));
  if (!fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}).listen(PORT, () => console.log('preview on :' + PORT));
