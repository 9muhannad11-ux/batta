'use strict';
// node tools/voices/master.js
// المرحلة الأخيرة لكل أصوات الشخصيات: تقرا tools/voices/<شخصية>_<رقم>.wav وتكتب app/assets/voices.
// تنظف الدمدمة، تقرّب الكلمات الهادية من القوية (ضغط)، تعطي جو مجلس خفيف،
// وتوحّد العلو على نفس المستوى (LUFS)، بحد أعلى للقمة. آخر خطوة بعدها: tools/voices/lipsync.js
// تعيد التشغيل من نفس الأصل، فما يتراكم أثرها إذا اشتغلت أكثر من مرة.
const fs = require('fs');
const path = require('path');

const DIR = __dirname, OUT = path.join(__dirname, '..', '..', 'app', 'assets', 'voices');
const TARGET = -16; // LUFS
const TRIM = { wadamtih: -3, aslam: -2.5, sulaiman: -2.5, musabbah: -2.5, medhat: -2.5, khusaib: -3 }; // dB: شخصية تطلع بالسمع أعلى من غيرها رغم نفس القياس (صوته أفخم)
const KEEP = new Set(['wadamtih_1.wav']); // معالج وجاهز بـ app/assets/voices، وتسجيله الأصلي ضاع: لا تعيد معالجته
const CEILING = -1.5; // dBFS أعلى قمة
const THRESHOLD = -22, RATIO = 2.5, ATTACK = 0.006, RELEASE = 0.09; // الضاغط
const ROOM = [[0.017, 0.085], [0.031, 0.06], [0.053, 0.04], [0.083, 0.025], [0.127, 0.012]]; // انعكاسات الجو: ثانية وقوة
const TAIL = 0.16; // وقت إضافي للجو بعد آخر الكلام

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, ch, sr, off, len;
  while (p < b.length) {
    const id = b.toString('latin1', p, p + 4), n = b.readUInt32LE(p + 4);
    if (id === 'fmt ') { ch = b.readUInt16LE(p + 10); sr = b.readUInt32LE(p + 12); }
    if (id === 'data') { off = p + 8; len = n; }
    p += 8 + n + (n & 1);
  }
  const frames = len / 2 / ch, x = new Float64Array(frames);
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < ch; c++) x[i] += b.readInt16LE(off + (i * ch + c) * 2) / 32768 / ch;
  }
  return { sr, x };
}

function writeWav(file, sr, x) {
  const body = Buffer.alloc(x.length * 2);
  x.forEach((v, i) => body.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0, 'latin1'); head.writeUInt32LE(36 + body.length, 4); head.write('WAVEfmt ', 8, 'latin1');
  head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(sr, 24);
  head.writeUInt32LE(sr * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
  head.write('data', 36, 'latin1'); head.writeUInt32LE(body.length, 40);
  fs.writeFileSync(file, Buffer.concat([head, body]));
}

function biquad(x, [b0, b1, b2, a1, a2]) {
  const y = new Float64Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
  }
  return y;
}

const highpass = (f, q, sr) => {
  const w = 2 * Math.PI * f / sr, a = Math.sin(w) / (2 * q), c = Math.cos(w), n = 1 + a;
  return [(1 + c) / 2 / n, -(1 + c) / n, (1 + c) / 2 / n, -2 * c / n, (1 - a) / n];
};
const highshelf = (f, db, q, sr) => {
  const A = 10 ** (db / 40), w = 2 * Math.PI * f / sr, a = Math.sin(w) / (2 * q), c = Math.cos(w), r = 2 * Math.sqrt(A) * a;
  const n = (A + 1) - (A - 1) * c + r;
  return [A * ((A + 1) + (A - 1) * c + r) / n, -2 * A * ((A - 1) + (A + 1) * c) / n, A * ((A + 1) + (A - 1) * c - r) / n,
    2 * ((A - 1) - (A + 1) * c) / n, ((A + 1) - (A - 1) * c - r) / n];
};

// العلو المحسوس (BS.1770) بكتل 100ms لأن المقاطع قصيرة، بدون السكوت
function lufs(x, sr) {
  const k = biquad(biquad(x, highshelf(1681.97, 4, 0.7072, sr)), highpass(38.135, 0.5003, sr));
  const size = Math.round(sr * 0.1), hop = Math.round(size / 2), blocks = [];
  for (let i = 0; i + size <= k.length; i += hop) {
    let e = 0;
    for (let j = i; j < i + size; j++) e += k[j] * k[j];
    blocks.push(e / size);
  }
  const load = (e) => -0.691 + 10 * Math.log10(e || 1e-12);
  const avg = (list) => list.reduce((a, b) => a + b, 0) / (list.length || 1);
  const loud = blocks.filter((e) => load(e) > -70);
  const gate = load(avg(loud)) - 10;
  return load(avg(loud.filter((e) => load(e) > gate)));
}

function compress(x, sr) {
  const at = Math.exp(-1 / (ATTACK * sr)), rel = Math.exp(-1 / (RELEASE * sr));
  const y = new Float64Array(x.length);
  let env = 0;
  for (let i = 0; i < x.length; i++) {
    const v = Math.abs(x[i]);
    env = v > env ? at * env + (1 - at) * v : rel * env + (1 - rel) * v;
    const db = 20 * Math.log10(env || 1e-9), over = db - THRESHOLD;
    y[i] = x[i] * (over > 0 ? 10 ** (-over * (1 - 1 / RATIO) / 20) : 1);
  }
  return y;
}

function room(x, sr) {
  const y = new Float64Array(x.length + Math.round(TAIL * sr));
  x.forEach((v, i) => { y[i] = v; });
  for (const [delay, level] of ROOM) {
    const shift = Math.round(delay * sr);
    x.forEach((v, i) => { y[i + shift] += v * level; });
  }
  const fade = Math.round(sr * 0.04);
  for (let i = 0; i < fade; i++) y[y.length - 1 - i] *= i / fade;
  return y;
}

// حد القمة: يخفض بنعومة قبل القمة بدل ما يقصها
function limit(x, sr, ceiling) {
  const look = Math.round(sr * 0.004), rel = Math.exp(-1 / (0.05 * sr));
  const need = Float64Array.from(x, (v) => (Math.abs(v) > ceiling ? ceiling / Math.abs(v) : 1));
  const y = new Float64Array(x.length);
  let gain = 1;
  for (let i = 0; i < x.length; i++) {
    let want = 1;
    for (let j = i; j < Math.min(x.length, i + look); j++) want = Math.min(want, need[j]);
    gain = want < gain ? want : rel * gain + (1 - rel) * want;
    y[i] = x[i] * Math.min(gain, want);
  }
  return y;
}

const ceiling = 10 ** (CEILING / 20);
const files = fs.readdirSync(DIR).filter((f) => /^[a-z]+_\d+\.wav$/.test(f) && !KEEP.has(f)).sort((a, b) => a.localeCompare(b, 'en', { numeric: true }));
const before = [], after = [];
for (const f of files) {
  const { sr, x } = readWav(path.join(DIR, f));
  before.push(lufs(x, sr));
  let y = room(compress(biquad(x, highpass(85, 0.707, sr)), sr), sr);
  const target = TARGET + (TRIM[f.split('_')[0]] ?? 0);
  const gain = 10 ** ((target - lufs(y, sr)) / 20);
  y = limit(y.map((v) => v * gain), sr, ceiling);
  // الحد ينزل العلو شوي، فنرجعه مرة وحدة
  const again = 10 ** ((target - lufs(y, sr)) / 20);
  y = limit(y.map((v) => v * again), sr, ceiling);
  after.push(lufs(y, sr));
  writeWav(path.join(OUT, f), sr, y);
  console.log(f.padEnd(18), `${before.at(-1).toFixed(1)} -> ${after.at(-1).toFixed(1)} LUFS, peak ${(20 * Math.log10(y.reduce((m, v) => Math.max(m, Math.abs(v)), 0))).toFixed(1)} dB`);
}
const spread = (list) => (Math.max(...list) - Math.min(...list)).toFixed(1);
console.log(`${files.length} files, spread ${spread(before)} dB -> ${spread(after)} dB`);
