'use strict';
// node tools/voices/denoise.js <in.wav> <out.wav> [قوة=2]
// يشيل التشويش الثابت (هسهسة وطنين) من تسجيل: يتعلّم شكل التشويش من أهدى المقاطع،
// وينقصه من كل الصوت (طرح طيفي بتنعيم عشان ما يطلع صوت معدني). يشتغل قبل master.js.
const fs = require('fs');

const [, , src, dst, strengthArg] = process.argv;
const STRENGTH = Number(strengthArg ?? 2); // كم مرة ننقص التشويش (أعلى = أنظف بس ممكن يأثر على الصوت)
const FLOOR = Number(process.env.FLOOR ?? 0.06); // أقل نسبة تبقى من أي تردد (عشان ما يصير صمت مقطوع)
const GATE = Number(process.env.GATE ?? 0); // dB تحت أعلى علو: أي شي أوطى منه (بين الكلمات) يصير صمت. 0 = بدون
const N = 1024, HOP = 256;

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, ch, sr, off, len;
  while (p < b.length) {
    const id = b.toString('latin1', p, p + 4), n = b.readUInt32LE(p + 4);
    if (id === 'fmt ') { ch = b.readUInt16LE(p + 10); sr = b.readUInt32LE(p + 12); }
    if (id === 'data') { off = p + 8; len = n; }
    p += 8 + n + (n & 1);
  }
  const frames = Math.floor(len / 2 / ch), x = new Float64Array(frames);
  for (let i = 0; i < frames; i++) for (let c = 0; c < ch; c++) x[i] += b.readInt16LE(off + (i * ch + c) * 2) / 32768 / ch;
  return { sr, x };
}

function writeWav(file, sr, x) {
  const body = Buffer.alloc(x.length * 2);
  x.forEach((v, i) => body.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0, 'latin1'); h.writeUInt32LE(36 + body.length, 4); h.write('WAVEfmt ', 8, 'latin1');
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(sr, 24);
  h.writeUInt32LE(sr * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36, 'latin1'); h.writeUInt32LE(body.length, 40);
  fs.writeFileSync(file, Buffer.concat([h, body]));
}

// FFT بسيط (radix-2) على re/im
function fft(re, im, inverse) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (2 * Math.PI / len) * (inverse ? 1 : -1), wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const ar = re[i + k], ai = im[i + k];
        const br = re[i + k + len / 2] * cr - im[i + k + len / 2] * ci, bi = re[i + k + len / 2] * ci + im[i + k + len / 2] * cr;
        re[i + k] = ar + br; im[i + k] = ai + bi;
        re[i + k + len / 2] = ar - br; im[i + k + len / 2] = ai - bi;
        const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
      }
    }
  }
  if (inverse) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
}

const { sr, x } = readWav(src);
const win = Float64Array.from({ length: N }, (_, i) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / N));
const pad = new Float64Array(x.length + 2 * N);
pad.set(x, N);
const spectra = [];
for (let s = 0; s + N <= pad.length; s += HOP) {
  const re = new Float64Array(N), im = new Float64Array(N);
  for (let i = 0; i < N; i++) re[i] = pad[s + i] * win[i];
  fft(re, im, false);
  spectra.push({ re, im });
}
const bins = N / 2 + 1;
const mag = spectra.map(({ re, im }) => Float64Array.from({ length: bins }, (_, k) => Math.hypot(re[k], im[k])));
// شكل التشويش: معدل أهدى 15% من المقاطع
const energy = mag.map((m) => m.reduce((a, v) => a + v * v, 0));
const order = energy.map((e, i) => [e, i]).sort((a, b) => a[0] - b[0]);
const quiet = order.slice(0, Math.max(4, Math.floor(order.length * 0.15))).map(([, i]) => i);
const noise = new Float64Array(bins);
for (const i of quiet) for (let k = 0; k < bins; k++) noise[k] += mag[i][k] / quiet.length;
// الكسب لكل تردد، ومنعّم مع الوقت (عشان ما تطلع فقاعات)
let prev = new Float64Array(bins).fill(1);
const out = new Float64Array(pad.length), norm = new Float64Array(pad.length);
spectra.forEach(({ re, im }, f) => {
  const g = new Float64Array(bins);
  for (let k = 0; k < bins; k++) {
    const target = Math.max(FLOOR, 1 - (STRENGTH * noise[k]) / (mag[f][k] + 1e-12));
    g[k] = target > prev[k] ? 0.6 * target + 0.4 * prev[k] : 0.35 * target + 0.65 * prev[k];
  }
  // تنعيم خفيف بين الترددات المتجاورة
  const gs = Float64Array.from(g, (v, k) => (g[Math.max(0, k - 1)] + 2 * v + g[Math.min(bins - 1, k + 1)]) / 4);
  prev = gs;
  for (let k = 0; k < bins; k++) {
    re[k] *= gs[k]; im[k] *= gs[k];
    if (k > 0 && k < N / 2) { re[N - k] = re[k]; im[N - k] = -im[k]; }
  }
  fft(re, im, true);
  const s = f * HOP;
  for (let i = 0; i < N; i++) { out[s + i] += re[i] * win[i]; norm[s + i] += win[i] * win[i]; }
});
let y = Float64Array.from({ length: x.length }, (_, i) => (norm[i + N] > 1e-6 ? out[i + N] / norm[i + N] : 0));
// هسهسة داخل الكلام نفسه (فوق 7kHz): نقصّها بفلتر ناعم مرتين (الصوت ما يحتاج هالترددات)
const LOWPASS = Number(process.env.LOWPASS ?? 7000);
if (LOWPASS > 0 && LOWPASS < sr / 2) {
  const w0 = (2 * Math.PI * LOWPASS) / sr, a = Math.sin(w0) / (2 * 0.707), c = Math.cos(w0), a0 = 1 + a;
  const k = [(1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, (-2 * c) / a0, (1 - a) / a0];
  for (let pass = 0; pass < 2; pass++) {
    const z = new Float64Array(y.length);
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (let i = 0; i < y.length; i++) {
      const v = k[0] * y[i] + k[1] * x1 + k[2] * x2 - k[3] * y1 - k[4] * y2;
      x2 = x1; x1 = y[i]; y2 = y1; y1 = v; z[i] = v;
    }
    y = z;
  }
}
// بوابة: بين الكلمات (أوطى من GATE dB تحت القمة) الصوت ينطفي بنعومة، عشان الخلفية ما تبين بالسكتات
if (GATE > 0) {
  const peak = y.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
  const thr = peak * 10 ** (-GATE / 20);
  const att = Math.exp(-1 / (0.003 * sr)), rel = Math.exp(-1 / (0.06 * sr)); // يفتح بسرعة ويسكّر بهدوء
  const hold = Math.round(0.08 * sr); // يبقى مفتوح شوي بعد آخر صوت (نهايات الكلمات الهادية)
  let env = 0, g = 0, open = 0;
  // نمشي من الطرفين: من البداية للنهاية للإغلاق، ونفتح قبل بداية الكلمة بشوي (look-ahead)
  const ahead = Math.round(0.012 * sr);
  const want = new Float64Array(y.length);
  for (let i = 0; i < y.length; i++) {
    const v = Math.abs(y[Math.min(y.length - 1, i + ahead)]);
    env = v > env ? v : env * 0.995;
    if (env > thr) open = hold;
    want[i] = open-- > 0 ? 1 : 0;
  }
  for (let i = 0; i < y.length; i++) {
    g = want[i] > g ? att * g + (1 - att) * want[i] : rel * g + (1 - rel) * want[i];
    y[i] *= g;
  }
}
// دمدمة وطنين تحت (مكيف، مروحة، مسكة الجوال): فلتر يشيل اللي تحت 120Hz مرتين
const HIGHPASS = Number(process.env.HIGHPASS ?? 120);
if (HIGHPASS > 0) {
  const w0 = (2 * Math.PI * HIGHPASS) / sr, a = Math.sin(w0) / (2 * 0.707), c = Math.cos(w0), a0 = 1 + a;
  const k = [(1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, (-2 * c) / a0, (1 - a) / a0];
  for (let pass = 0; pass < 2; pass++) {
    const z = new Float64Array(y.length);
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (let i = 0; i < y.length; i++) {
      const v = k[0] * y[i] + k[1] * x1 + k[2] * x2 - k[3] * y1 - k[4] * y2;
      x2 = x1; x1 = y[i]; y2 = y1; y1 = v; z[i] = v;
    }
    y = z;
  }
}
writeWav(dst, sr, y);
const db = (v) => (20 * Math.log10(v + 1e-12)).toFixed(1);
console.log(`denoised ${src.split(/[\\/]/).pop()} (strength ${STRENGTH}), noise profile from ${quiet.length} quiet frames, avg noise ${db(noise.reduce((a, v) => a + v, 0) / bins / N)} dB`);
