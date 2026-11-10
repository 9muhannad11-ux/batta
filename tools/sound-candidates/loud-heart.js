'use strict';
// node tools/sound-candidates/loud-heart.js [analyze]
// دقات القلب بالباون أعلى بكثير: نرفع الصوت ونضغطه (حد ناعم) عشان يعلى بدون تشويه.
// المصدر gold_orig.wav (نسخة الأصل)، والناتج app/assets/sounds/gold.wav
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', '..');
const orig = path.join(__dirname, 'gold_orig.wav');
const out = path.join(root, 'app/assets/sounds/gold.wav');
if (!fs.existsSync(orig)) fs.copyFileSync(out, orig);

function read(file) {
  const b = fs.readFileSync(file);
  let o = 12, sr = 44100, ch = 1, data;
  while (o < b.length) {
    const id = b.toString('latin1', o, o + 4), sz = b.readUInt32LE(o + 4);
    if (id === 'fmt ') { ch = b.readUInt16LE(o + 10); sr = b.readUInt32LE(o + 12); }
    if (id === 'data') { data = b.subarray(o + 8, o + 8 + sz); break; }
    o += 8 + sz;
  }
  const n = data.length / 2 / ch, x = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = 0; for (let c = 0; c < ch; c++) s += data.readInt16LE((i * ch + c) * 2) / 32768; x[i] = s / ch; }
  return { sr, x };
}
function write(file, x, sr) {
  const body = Buffer.alloc(x.length * 2);
  x.forEach((v, i) => body.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0, 'latin1'); h.writeUInt32LE(36 + body.length, 4); h.write('WAVEfmt ', 8, 'latin1');
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(sr, 24);
  h.writeUInt32LE(sr * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36, 'latin1'); h.writeUInt32LE(body.length, 40);
  fs.writeFileSync(file, Buffer.concat([h, body]));
}
const peak = (x) => x.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
const rms = (x) => { const p = peak(x); let s = 0, n = 0; for (const v of x) if (Math.abs(v) > p * 0.05) { s += v * v; n++; } return Math.sqrt(s / Math.max(1, n)); };
const db = (v) => (20 * Math.log10(v)).toFixed(1);

const { sr, x } = read(orig);
console.log(`original: ${(x.length / sr).toFixed(2)}s peak ${db(peak(x))} dB, loud part rms ${db(rms(x))} dB`);
for (const f of ['collect', 'win', 'bawan', 'joker']) {
  const s = read(path.join(root, `app/assets/sounds/${f}.wav`)).x;
  console.log(`  ${f}: peak ${db(peak(s))} rms ${db(rms(s))}`);
}
if (process.argv[2] === 'analyze') process.exit(0);

// ضغط بحد ناعم (tanh بقوة 10): الدقات وذيولها تعلى حوالي 9 dB والقمة تبقى تحت 0.97 بدون تشويه واضح
const drive = 10, p0 = peak(x);
let y = Array.from(x, (v) => Math.tanh((v / p0) * drive) / Math.tanh(drive));
const k = 0.97 / peak(y);
y = y.map((v) => v * k);
write(out, y, sr);
console.log(`louder:   peak ${db(peak(y))} dB, loud part rms ${db(rms(y))} dB`);
