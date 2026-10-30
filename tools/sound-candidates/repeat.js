'use strict';
// node repeat.js <in_mono.wav> <out.wav> [times] [gapSeconds]
// يكرر صوت قصير (مثل ورقة تنحط) ورا بعض، وكل مرة تختلف شوي بالقوة والطبقة عشان يطلع طبيعي.
const fs = require('fs');
const [, , inFile, outFile, timesArg, gapArg] = process.argv;
const times = +timesArg || 10, gap = +gapArg || 0.13;
const buf = fs.readFileSync(inFile);
let p = 12, rate, data;
while (p < buf.length) {
  const id = buf.toString('ascii', p, p + 4), n = buf.readUInt32LE(p + 4);
  if (id === 'fmt ') { if (buf.readUInt16LE(p + 10) !== 1) throw new Error('mono wav expected (run trim.js first)'); rate = buf.readUInt32LE(p + 12); }
  if (id === 'data') data = buf.subarray(p + 8, p + 8 + n);
  p += 8 + n + (n & 1);
}
const src = new Float32Array(data.length / 2);
for (let i = 0; i < src.length; i++) src[i] = data.readInt16LE(i * 2) / 32768;
let seed = 3;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
const total = Math.ceil((gap * (times - 1)) * rate + src.length * 1.1);
const mix = new Float32Array(total);
for (let k = 0; k < times; k++) {
  const start = Math.round(k * gap * rate + (rnd() - 0.5) * 0.012 * rate * (k ? 1 : 0));
  const gain = 0.72 + 0.28 * rnd(), pitch = 0.95 + 0.1 * rnd();
  for (let j = 0; ; j++) {
    const sp = j * pitch, i0 = sp | 0; if (i0 + 1 >= src.length) break;
    const v = src[i0] + (src[i0 + 1] - src[i0]) * (sp - i0);
    if (start + j < total) mix[start + j] += v * gain;
  }
}
const peak = mix.reduce((m, v) => Math.max(m, Math.abs(v)), 0) || 1;
const norm = peak > 0.95 ? 0.95 / peak : 1;
let end = total - 1; while (end > 0 && Math.abs(mix[end]) < 1e-4) end--;
const out = Buffer.alloc((end + 1) * 2);
for (let i = 0; i <= end; i++) out.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(mix[i] * norm * 32767))), i * 2);
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + out.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
h.writeUInt32LE(rate, 24); h.writeUInt32LE(rate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(out.length, 40);
fs.writeFileSync(outFile, Buffer.concat([h, out]));
console.log(`${times} times, every ${gap}s, length ${((end + 1) / rate).toFixed(2)}s`);
