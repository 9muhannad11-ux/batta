'use strict';
// node tools/voices/f0.js <file.wav> [...]
// طبقة الصوت (الوسيط بالهيرتز) من لحظات الكلام: autocorrelation لكل 40ms بين 70 و 350Hz.
// نستخدمها عشان نعرف كم نصف درجة نرفع أو ننزل تسجيل اللاعب ليشبه صوت مرجع (clean.html &pitch=).
const fs = require('fs');

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, ch, sr, off, len;
  while (p < b.length - 8) {
    const id = b.toString('latin1', p, p + 4), n = b.readUInt32LE(p + 4);
    if (id === 'fmt ') { ch = b.readUInt16LE(p + 10); sr = b.readUInt32LE(p + 12); }
    if (id === 'data') { off = p + 8; len = n; }
    p += 8 + n + (n & 1);
  }
  const frames = Math.floor(len / (2 * ch)), x = new Float64Array(frames);
  for (let i = 0; i < frames; i++) for (let c = 0; c < ch; c++) x[i] += b.readInt16LE(off + (i * ch + c) * 2) / 32768 / ch;
  return { sr, x };
}

function f0(file) {
  const { sr, x } = readWav(file);
  const w = Math.round(sr * 0.04), lo = Math.floor(sr / 350), hi = Math.ceil(sr / 70);
  let peak = 0;
  for (const v of x) peak = Math.max(peak, Math.abs(v));
  const found = [];
  for (let a = 0; a + w + hi < x.length; a += Math.round(w / 2)) {
    let e = 0;
    for (let i = 0; i < w; i++) e += x[a + i] ** 2;
    if (Math.sqrt(e / w) < peak * 0.08) continue;
    let best = 0, lag = 0;
    for (let l = lo; l <= hi; l++) {
      let s = 0, n1 = 0, n2 = 0;
      for (let i = 0; i < w; i++) { s += x[a + i] * x[a + i + l]; n1 += x[a + i] ** 2; n2 += x[a + i + l] ** 2; }
      const r = s / Math.sqrt(n1 * n2 + 1e-12);
      if (r > best) { best = r; lag = l; }
    }
    if (best > 0.6) found.push(sr / lag);
  }
  found.sort((a, b) => a - b);
  return { median: found[found.length >> 1], frames: found.length };
}

for (const f of process.argv.slice(2)) {
  const r = f0(f);
  console.log(`${f}: ${r.median ? r.median.toFixed(0) + ' Hz' : 'no voice'} (${r.frames} voiced frames)`);
}
