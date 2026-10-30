'use strict';
// node joker.js <khanjar_full.png> <blue|grey> <out.png>
// ورقة جوكر: الخنجر بلمعة كروم، خطوطه أوضح، رموز الأنواع الأربعة عليه، وكلمة JOKER بالطول بالزاويتين. بدون إطار.
const fs = require('fs');
const zlib = require('zlib');
const [, , inFile, kind, outFile] = process.argv;
// gr = الجوكر الكبير بمزيج أخضر وأحمر (يقرأ صورة الخنجر الزرقاء)
const BASE = kind === 'grey' ? [110, 110, 110] : [31, 85, 196];
const GREEN = [18, 140, 72], RED = [204, 32, 44];

function decodeRGBA(buf) {
  let pos = 8, w, h, idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8), d = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); }
    if (type === 'IDAT') idat.push(d);
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat)), st = w * 4, out = Buffer.alloc(h * st);
  for (let y = 0; y < h; y++) raw.copy(out, y * st, y * (st + 1) + 1, (y + 1) * (st + 1));
  return { w, h, px: out };
}
const crcT = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (t, d) => { const tb = Buffer.from(t), l = Buffer.alloc(4), c = Buffer.alloc(4); l.writeUInt32BE(d.length); c.writeUInt32BE(crc(Buffer.concat([tb, d]))); return Buffer.concat([l, tb, d, c]); };
function encode(W, H, img) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc(H * (W * 4 + 1));
  for (let y = 0; y < H; y++) img.copy(raw, y * (W * 4 + 1) + 1, y * W * 4, (y + 1) * W * 4);
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

// 1) الخنجر: قناع + قوة الخط الأبيض لكل بكسل
const k = decodeRGBA(fs.readFileSync(inFile));
const KW = k.w, KH = k.h;
const alpha = new Float32Array(KW * KH), line = new Float32Array(KW * KH);
for (let i = 0; i < KW * KH; i++) {
  alpha[i] = k.px[i * 4 + 3] / 255;
  const r = k.px[i * 4];
  line[i] = Math.max(0, Math.min(1, (r - BASE[0]) / (255 - BASE[0])));
}
// تبيين الزخارف: نسمّك الخطوط بكسل ونقوّيها
const line2 = new Float32Array(KW * KH);
for (let y = 0; y < KH; y++) for (let x = 0; x < KW; x++) {
  let m = 0;
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
    const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= KW || yy >= KH) continue;
    const v = line[yy * KW + xx] * (dx && dy ? 0.75 : 1); if (v > m) m = v;
  }
  line2[y * KW + x] = Math.min(1, m * 1.7);
}
// لمعة الكروم: أشرطة مايلة فاتحة وغامقة على لون الخنجر
function chrome(x, y) {
  const u = (x * 0.62 + y * 0.78) / (KW * 0.62 + KH * 0.78);
  const band = Math.sin(u * Math.PI * 5.2 + 0.6);
  const spec = Math.pow(Math.max(0, Math.sin(u * Math.PI * 5.2 + 0.2)), 12);
  const shade = 0.78 + 0.32 * band; // غامق/فاتح
  let base = BASE;
  if (kind === 'gr') { const m = 0.5 + 0.5 * Math.sin(u * Math.PI * 3.1 - 0.9); base = GREEN.map((g, j) => g * (1 - m) + RED[j] * m); }
  return base.map((c) => Math.min(255, c * shade + (255 - c) * (0.18 * (band + 1) / 2 + 0.55 * spec)));
}

// 2) رموز الأنواع (مساحات بالشكل، نحسب التغطية بعينات)
const inHeart = (x, y) => Math.hypot(x + 0.5, y + 0.25) < 0.55 || Math.hypot(x - 0.5, y + 0.25) < 0.55 || (y >= -0.1 && Math.abs(x) <= 1 - (y + 0.1) / 1.1 * 1.0 && y <= 1);
const inDiamond = (x, y) => Math.abs(x) / 0.78 + Math.abs(y) <= 1;
const inClub = (x, y) => Math.hypot(x, y + 0.45) < 0.42 || Math.hypot(x - 0.46, y + 0.02) < 0.42 || Math.hypot(x + 0.46, y + 0.02) < 0.42 || (y > 0 && y < 1 && Math.abs(x) < 0.08 + y * 0.3);
const inSpade = (x, y) => inHeart(x, -y + 0.05) && y < 0.75 || (y > 0.2 && y < 1 && Math.abs(x) < 0.06 + (y - 0.2) * 0.4);
const SUIT = { H: [inHeart, [214, 30, 36]], D: [inDiamond, [214, 30, 36]], C: [inClub, [17, 17, 17]], S: [inSpade, [17, 17, 17]] };
// أماكنها على الخنجر (بإحداثيات صورة الخنجر) — بين خطوط الغمد وعلى طرفي راس القبضة
const PLACES = JSON.parse(process.env.PLACES || '[]');

// 3) حروف JOKER (خطوط على شبكة 10×14)
const GLYPH = {
  J: [[[3, 0], [10, 0]], [[7, 0], [7, 10]], [[7, 10], [6, 12.6], [4, 13.6], [2, 13], [1, 11]]],
  O: [[...Array.from({ length: 25 }, (_, i) => { const a = i / 24 * Math.PI * 2; return [5 + 4.3 * Math.sin(a), 7 - 6.6 * Math.cos(a)]; })]],
  K: [[[1.5, 0], [1.5, 14]], [[9.5, 0], [1.5, 8]], [[4.5, 5.2], [9.5, 14]]],
  E: [[[9, 0], [1.5, 0], [1.5, 14], [9, 14]], [[1.5, 7], [7.5, 7]]],
  R: [[[1.5, 14], [1.5, 0], [6, 0], [8.3, 1.2], [9, 3.6], [8.3, 6], [6, 7.2], [1.5, 7.2]], [[5.5, 7.2], [9.5, 14]]],
};
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(px - ax - t * dx, py - ay - t * dy);
}
function glyphCov(ch, gx, gy, half) {
  let d = 1e9;
  for (const pl of GLYPH[ch]) for (let i = 0; i + 1 < pl.length; i++) d = Math.min(d, segDist(gx, gy, pl[i][0], pl[i][1], pl[i + 1][0], pl[i + 1][1]));
  return d <= half;
}

// 4) نرسم الورقة
const W = 400, H = 580, img = Buffer.alloc(W * H * 4);
const blend = (x, y, rgb, a) => { x = Math.round(x); y = Math.round(y); if (a <= 0 || x < 0 || y < 0 || x >= W || y >= H) return; const o = (y * W + x) * 4; for (let c = 0; c < 3; c++) img[o + c] = img[o + c] * (1 - a) + rgb[c] * a; img[o + 3] = 255; };
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const R = 24, cx = Math.min(Math.max(x, R), W - 1 - R), cy = Math.min(Math.max(y, R), H - 1 - R);
  const o = (y * W + x) * 4; img[o] = img[o + 1] = img[o + 2] = Math.hypot(x - cx, y - cy) <= R ? 255 : 17; img[o + 3] = 255;
}
const s = Math.min(300 / KW, 520 / KH), dw = Math.round(KW * s), dh = Math.round(KH * s), ox = Math.round((W - dw) / 2) + 8, oy = Math.round((H - dh) / 2);
const SS = 4; // عينات لكل بكسل (حواف أنعم)
for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
  let ar = 0, ag = 0, ab = 0, aa = 0;
  for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
    const kx = Math.min(KW - 1, ((x + (sx + 0.5) / SS) / s) | 0), ky = Math.min(KH - 1, ((y + (sy + 0.5) / SS) / s) | 0), i = ky * KW + kx;
    const a = alpha[i]; if (!a) continue;
    let col = chrome(kx, ky);
    const t = line2[i]; col = col.map((c) => c + (255 - c) * t);
    // رمز النوع فوقه
    for (const [suit, px, py, r] of PLACES) {
      const ux = (kx - px) / r, uy = (ky - py) / r; if (Math.abs(ux) > 1.4 || Math.abs(uy) > 1.4) continue;
      const [fn, rgb] = SUIT[suit];
      if (kind === 'blue') {
        if (fn(ux / 1.0, uy / 1.0)) col = rgb; else if (fn(ux / 1.22, uy / 1.22)) col = [255, 255, 255];
      } else if (fn(ux, uy)) col = [255, 255, 255];
    }
    ar += col[0] * a; ag += col[1] * a; ab += col[2] * a; aa += a;
  }
  const n = SS * SS; if (!aa) continue;
  blend(ox + x, oy + y, [ar / aa, ag / aa, ab / aa], aa / n);
}
// كلمة JOKER بالطول: فوق يسار، ومقلوبة تحت يمين
const unit = 1.55, half = 1.05, letterH = 14 * unit, gap = 6;
function drawWord(x0, y0, flip) {
  [...'JOKER'].forEach((ch, li) => {
    const top = y0 + li * (letterH + gap);
    for (let y = -2; y < letterH + 2; y++) for (let x = -2; x < 10 * unit + 2; x++) {
      let cov = 0;
      for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) if (glyphCov(ch, (x + (sx + 0.5) / 3) / unit, (y + (sy + 0.5) / 3) / unit, half)) cov++;
      if (!cov) continue;
      let X = x0 + x, Y = top + y;
      if (flip) { X = W - 1 - X; Y = H - 1 - Y; }
      blend(X, Y, kind === 'gr' ? (li % 2 ? RED : GREEN) : kind === 'grey' ? [17, 17, 17] : BASE, cov / 9);
    }
  });
}
drawWord(16, 22, false);
drawWord(16, 22, true);
fs.writeFileSync(outFile, encode(W, H, img));
console.log('wrote', outFile);
