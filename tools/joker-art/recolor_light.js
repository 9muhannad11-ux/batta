'use strict';
// node recolor_light.js <in.png> <outDir>
// صورة خنجر أسود على خلفية بيضاء: نشيل الأبيض اللي برا، والأسود يصير لون الجوكر، والخطوط البيضاء اللي داخله تبقى بيضاء.
const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

function decode(buf) {
  let pos = 8, w, h, ctype, idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); ctype = data[9]; }
    if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  const bpp = ctype === 6 ? 4 : 3, raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * bpp, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, b = y ? out[(y - 1) * stride + x] : 0, c = x >= bpp && y ? out[(y - 1) * stride + x - bpp] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, bpp, px: out };
}
const crcT = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (t, d) => { const tb = Buffer.from(t), l = Buffer.alloc(4), c = Buffer.alloc(4); l.writeUInt32BE(d.length); c.writeUInt32BE(crc(Buffer.concat([tb, d]))); return Buffer.concat([l, tb, d, c]); };
function encode(w, h, rgba) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc(h * (w * 4 + 1));
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

const [, , inFile, outDir] = process.argv;
const { w, h, bpp, px } = decode(fs.readFileSync(inFile));
const lum = new Float32Array(w * h);
for (let i = 0; i < w * h; i++) lum[i] = 0.299 * px[i * bpp] + 0.587 * px[i * bpp + 1] + 0.114 * px[i * bpp + 2];

// الخلفية = الفاتح المتصل بنقطة بالزاوية الفاتحة، وبعد من داخل فتحتي الحلقتين
const LIGHT = 150;
const bg = new Uint8Array(w * h), stack = [];
const push = (x, y) => { if (x < 0 || y < 0 || x >= w || y >= h) return; const i = y * w + x; if (!bg[i] && lum[i] > LIGHT) { bg[i] = 1; stack.push(i); } };
const seeds = (process.env.SEEDS || '60,60;1020,60;60,1020;1020,1020;403,595;783,595').split(';').map((s) => s.split(',').map(Number));
for (const [x, y] of seeds) push(x, y);
while (stack.length) { const i = stack.pop(), x = i % w, y = (i / w) | 0; push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1); }

// نخلي القطع الكبيرة بس (الخطوط البيضاء تقسم الخنجر لأكثر من قطعة)، والنقط الصغيرة تنشال
const comp = new Int32Array(w * h).fill(-1), sizes = [];
for (let s = 0; s < w * h; s++) {
  if (bg[s] || comp[s] >= 0) continue;
  const id = sizes.length; let n = 0; const st = [s]; comp[s] = id;
  while (st.length) {
    const i = st.pop(), x = i % w, y = (i / w) | 0; n++;
    for (const j of [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, y > 0 ? i - w : -1, y < h - 1 ? i + w : -1])
      if (j >= 0 && !bg[j] && comp[j] < 0) { comp[j] = id; st.push(j); }
  }
  sizes.push(n);
}
const keep = sizes.map((n) => n > 1500);
const bigBox = () => { let a = w, b = h, c = 0, d = 0; for (let i = 0; i < w * h; i++) if (comp[i] >= 0 && keep[comp[i]]) { const x = i % w, y = (i / w) | 0; a = Math.min(a, x); c = Math.max(c, x); b = Math.min(b, y); d = Math.max(d, y); } return [a, b, c, d]; };
// الزوايا الغامقة وحافة الصورة مو من الخنجر
for (let x = 0; x < w; x++) for (const y of [0, 1, 2, h - 3, h - 2, h - 1]) { const c = comp[y * w + x]; if (c >= 0) keep[c] = false; }
for (let y = 0; y < h; y++) for (const x of [0, 1, 2, w - 3, w - 2, w - 1]) { const c = comp[y * w + x]; if (c >= 0) keep[c] = false; }
// القطع الصغيرة (الأشرطة الرفيعة والوصلات ونص المعيّن) نرجعها إذا هي داخل حدود الخنجر
{ const [a, b, c, d] = bigBox(); const cx = new Float64Array(sizes.length), cy = new Float64Array(sizes.length);
  for (let i = 0; i < w * h; i++) if (comp[i] >= 0) { cx[comp[i]] += i % w; cy[comp[i]] += (i / w) | 0; }
  sizes.forEach((n, id) => { if (keep[id] || n < 20) return; const X = cx[id] / n, Y = cy[id] / n; if (X > a && X < c && Y > b && Y < d) keep[id] = true; });
  for (let x = 0; x < w; x++) for (const y of [0, 1, 2, h - 3, h - 2, h - 1]) { const q = comp[y * w + x]; if (q >= 0) keep[q] = false; } }
let minX = w, minY = h, maxX = 0, maxY = 0;
for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
  const i = y * w + x; if (comp[i] < 0 || !keep[comp[i]]) { bg[i] = 1; continue; }
  minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
}
console.log(`size ${w}x${h}, pieces ${sizes.length}, kept ${keep.filter(Boolean).length}, box x${minX}-${maxX} y${minY}-${maxY}`);

// حواف ناعمة: البكسلات اللي على الحد (من الجهتين) تاخذ شفافية حسب فتاحتها بدل ما تكون يا كلها يا لا
const near = (i, r, want) => { const x = i % w, y = (i / w) | 0;
  for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) { const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue; if (!!bg[yy * w + xx] === want) return true; }
  return false; };
const soft = (l) => Math.min(1, Math.max(0, (248 - l) / 208));
minX -= 2; minY -= 2; maxX += 2; maxY += 2;
const colors = { blue: [31, 85, 196], grey: [110, 110, 110] };
const cw = maxX - minX + 1, ch = maxY - minY + 1;
fs.mkdirSync(outDir, { recursive: true });
for (const [name, [r, g, b]] of Object.entries(colors)) {
  const out = Buffer.alloc(cw * ch * 4);
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const X = minX + x, Y = minY + y; if (X < 0 || Y < 0 || X >= w || Y >= h) continue;
    const i = Y * w + X, o = (y * cw + x) * 4;
    let t = 0, a = 1;
    if (bg[i]) {
      // برا الخنجر بس ملاصق له: نص شفاف حسب الرمادي اللي بالصورة
      if (lum[i] <= LIGHT || !near(i, 2, false)) continue;
      a = soft(lum[i]); if (a <= 0) continue;
    } else if (near(i, 1, true)) a = soft(lum[i]); // على الحد من جوا
    else t = Math.min(1, Math.max(0, (lum[i] - 40) / 170)); // 0 = لون الجوكر، 1 = خط أبيض
    out[o] = r + (255 - r) * t; out[o + 1] = g + (255 - g) * t; out[o + 2] = b + (255 - b) * t; out[o + 3] = Math.round(255 * a);
  }
  const file = path.join(outDir, `khanjar_${name}.png`);
  fs.writeFileSync(file, encode(cw, ch, out));
  console.log('wrote', file, cw + 'x' + ch);
}
