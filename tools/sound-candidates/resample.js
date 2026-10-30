'use strict';
// node resample.js <mono16.wav> : يحوّل الملف لـ 44.1kHz (مكانه) عشان يصغر حجمه
const fs = require('fs');
const f = process.argv[2], b = fs.readFileSync(f), rate = b.readUInt32LE(24), n = (b.length - 44) / 2;
const src = new Float32Array(n);
for (let i = 0; i < n; i++) src[i] = b.readInt16LE(44 + i * 2) / 32768;
const R = 44100, m = Math.floor(n * R / rate), out = Buffer.alloc(44 + m * 2);
let pk = 0;
for (let i = 0; i < m; i++) {
  const x = i * rate / R, i0 = x | 0, t = x - i0, v = src[i0] + ((src[i0 + 1] || 0) - src[i0]) * t;
  pk = Math.max(pk, Math.abs(v));
  out.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), 44 + i * 2);
}
b.copy(out, 0, 0, 44); out.writeUInt32LE(36 + m * 2, 4); out.writeUInt32LE(R, 24); out.writeUInt32LE(R * 2, 28); out.writeUInt32LE(m * 2, 40);
fs.writeFileSync(f, out);
console.log(`${rate} -> ${R}, ${(m / R).toFixed(2)}s, peak ${pk.toFixed(2)}`);
