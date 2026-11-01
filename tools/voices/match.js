'use strict';
// node tools/voices/match.js <src.wav> <ref.wav> <out.wav>
// يركّب نبرة صوت المرجع (ref) على التسجيل (src): نقيس متوسط طيف الكلام بالاثنين،
// والفرق بينهم (منعّم على ثلث أوكتاف، بحد ±9dB) يصير فلتر ينطبق على التسجيل. العلو يبقى نفسه.
// (الطبقة تتظبط قبلها بـ clean.html &pitch=)  CURVE=tools/voices/aslam_curve.json يثبّت نبرة الشخصية
const fs = require('fs');
const [, , srcFile, refFile, outFile] = process.argv;
const N = 2048, H = N / 4;

function readWav(file) {
  const buf = fs.readFileSync(file);
  let p = 12, fmt, data;
  while (p < buf.length) {
    const id = buf.toString('ascii', p, p + 4), n = buf.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = { channels: buf.readUInt16LE(p + 10), rate: buf.readUInt32LE(p + 12) };
    if (id === 'data') data = buf.subarray(p + 8, p + 8 + n);
    p += 8 + n + (n & 1);
  }
  const frames = Math.floor(data.length / (2 * fmt.channels)), x = new Float64Array(frames);
  for (let i = 0; i < frames; i++) {
    let s = 0;
    for (let c = 0; c < fmt.channels; c++) s += data.readInt16LE((i * fmt.channels + c) * 2) / 32768;
    x[i] = s / fmt.channels;
  }
  return { rate: fmt.rate, x };
}

function fft(re, im, inv) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (inv ? 2 : -2) * Math.PI / len, wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k, b = a + len / 2;
        const br = re[b] * cr - im[b] * ci, bi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - br; im[b] = im[a] - bi; re[a] += br; im[a] += bi;
        const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
      }
    }
  }
  if (inv) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
}

const win = Float64Array.from({ length: N }, (_, i) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / N));

// متوسط طيف لحظات الكلام بس (أعلى من -30dB تحت أعلى لحظة)
function ltas(x) {
  const frames = [];
  for (let a = 0; a + N <= x.length; a += H) {
    let e = 0;
    for (let i = 0; i < N; i++) e += x[a + i] ** 2;
    frames.push({ a, e });
  }
  const peak = Math.max(...frames.map((f) => f.e));
  const sum = new Float64Array(N / 2 + 1);
  let n = 0;
  for (const { a, e } of frames) {
    if (e < peak * 1e-3) continue;
    const re = Float64Array.from({ length: N }, (_, i) => x[a + i] * win[i]), im = new Float64Array(N);
    fft(re, im);
    for (let k = 0; k <= N / 2; k++) sum[k] += re[k] ** 2 + im[k] ** 2;
    n++;
  }
  return sum.map((v) => v / n);
}

const src = readWav(srcFile), ref = readWav(refFile);
const S = ltas(src.x), R = ltas(ref.x);
// الفرق منعّم على ثلث أوكتاف، وفوق 7kHz وتحت 80Hz ما نلمسه
const gain = new Float64Array(N / 2 + 1);
for (let k = 1; k <= N / 2; k++) {
  const f = (k * src.rate) / N;
  if (f < 80 || f > 7000) { gain[k] = 1; continue; }
  const lo = Math.max(1, Math.floor(k / 2 ** (1 / 6))), hi = Math.min(N / 2, Math.ceil(k * 2 ** (1 / 6)));
  let s = 0, r = 0;
  for (let j = lo; j <= hi; j++) { s += S[j]; r += R[j]; }
  const db = 10 * Math.log10((r + 1e-12) / (s + 1e-12));
  gain[k] = db;
}
// نشيل الوسيط (العلو العام يبقى نفسه)، بحد ±9dB، ونحوّل لنسبة
const band = [...gain].filter((g, k) => k > 0 && (k * src.rate) / N >= 80 && (k * src.rate) / N <= 7000);
const mid = [...band].sort((a, b) => a - b)[band.length >> 1];
for (let k = 0; k <= N / 2; k++) {
  const f = (k * src.rate) / N;
  gain[k] = f < 80 || f > 7000 ? 1 : 10 ** (Math.max(-9, Math.min(9, gain[k] - mid)) / 20);
}
// CURVE=x.json: نحفظ الفلتر، أو إذا موجود نستخدمه بدل القياس (نفس النبرة لكل تسجيلات الشخصية،
// لأن التسجيلات القصيرة طيفها يتأثر بالكلمات)
if (process.env.CURVE) {
  if (fs.existsSync(process.env.CURVE)) gain.set(JSON.parse(fs.readFileSync(process.env.CURVE, 'utf8')));
  else fs.writeFileSync(process.env.CURVE, JSON.stringify([...gain].map((g) => +g.toFixed(5))));
}

// الفلتر على التسجيل (overlap-add)
const x = src.x, y = new Float64Array(x.length + N), norm = new Float64Array(x.length + N);
for (let a = -N; a < x.length; a += H) {
  const re = Float64Array.from({ length: N }, (_, i) => (x[a + i] || 0) * win[i]), im = new Float64Array(N);
  fft(re, im);
  for (let k = 0; k <= N / 2; k++) {
    re[k] *= gain[k]; im[k] *= gain[k];
    if (k && k < N / 2) { re[N - k] *= gain[k]; im[N - k] *= gain[k]; }
  }
  fft(re, im, true);
  for (let i = 0; i < N; i++) if (a + i >= 0) { y[a + i] += re[i] * win[i]; norm[a + i] += win[i] ** 2; }
}
const out = Float64Array.from(x, (_, i) => y[i] / (norm[i] || 1));
// نفس العلو (RMS) ونفس الحد
const rms = (v) => Math.sqrt(v.reduce((a, b) => a + b * b, 0) / v.length);
let k = rms(x) / rms(out);
const pk = Math.max(...out.map(Math.abs)) * k;
if (pk > 0.98) k *= 0.98 / pk;
const pcm = Buffer.alloc(out.length * 2);
out.forEach((v, i) => pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v * k)) * 32767), i * 2));
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
h.writeUInt32LE(src.rate, 24); h.writeUInt32LE(src.rate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
fs.writeFileSync(outFile, Buffer.concat([h, pcm]));
const curve = [150, 300, 600, 1200, 2500, 5000].map((f) => `${f}Hz ${(20 * Math.log10(gain[Math.round((f * N) / src.rate)])).toFixed(1)}dB`).join(', ');
console.log('saved', outFile, '| EQ:', curve);
