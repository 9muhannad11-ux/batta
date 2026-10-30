'use strict';
// node gen-oud.js <out.wav> [variant]
// جملة قصيرة هادية بصوت قريب من العود (وتر منقور بطريقة Karplus-Strong + رنين صندوق + صدى خفيف)
// المقام: حجاز على ري (ري، مي♭، فا#، صول، لا)
const fs = require('fs');
const RATE = 44100;
const [, , outFile, variant = 'a'] = process.argv;

const N = { D3: 146.83, Eb3: 155.56, Fs3: 185.0, G3: 196.0, A3: 220.0, Bb3: 233.08, C4: 261.63, D4: 293.66, D2: 73.42, A2: 110.0 };

let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

// نقرة وتر: ضوضاء مفلترة تدور بخط تأخير بطول الموجة، وتخفت مع الوقت
function pluck(freq, dur, gain = 1, bright = 0.5) {
  const n = Math.round(RATE / freq), out = new Float32Array(Math.round(dur * RATE)), buf = new Float32Array(n);
  let lp = 0;
  for (let i = 0; i < n; i++) { lp += (rnd() * 2 - 1 - lp) * bright; buf[i] = lp; }
  let idx = 0, prev = 0;
  for (let i = 0; i < out.length; i++) {
    const cur = buf[idx];
    const next = 0.5 * (cur + prev) * 0.9965; // فلتر متوسط يخلي الصوت يدفى ويخفت
    prev = cur; buf[idx] = next; idx = (idx + 1) % n;
    out[i] = cur * gain;
  }
  // ضربة الريشة: نقرة قصيرة بالبداية
  for (let i = 0; i < Math.min(out.length, 200); i++) out[i] += (rnd() * 2 - 1) * 0.15 * gain * (1 - i / 200);
  return out;
}

// رنين صندوق العود: رنانين على ترددات منخفضة يعطون دفى
function body(x) {
  const res = [[110, 0.985], [205, 0.98], [390, 0.97]], y = new Float32Array(x.length);
  for (const [f, r] of res) {
    const w = 2 * Math.PI * f / RATE, a1 = -2 * r * Math.cos(w), a2 = r * r;
    let y1 = 0, y2 = 0;
    for (let i = 0; i < x.length; i++) { const v = x[i] * (1 - r) - a1 * y1 - a2 * y2; y2 = y1; y1 = v; y[i] += v * 0.9; }
  }
  for (let i = 0; i < x.length; i++) y[i] = x[i] * 0.75 + y[i] * 0.35;
  return y;
}

// صدى خفيف (مثل غرفة)
function reverb(x) {
  const y = new Float32Array(x.length + RATE);
  for (let i = 0; i < x.length; i++) y[i] += x[i];
  for (const [d, g] of [[0.047, 0.32], [0.071, 0.26], [0.113, 0.2], [0.167, 0.15], [0.241, 0.1]]) {
    const off = Math.round(d * RATE);
    let lp = 0;
    for (let i = 0; i < x.length; i++) { lp += (x[i] - lp) * 0.3; y[i + off] += lp * g; }
  }
  return y;
}

// الألحان: [نغمة, وقت البداية بالثواني, القوة] — بطيئة وهادية
const PHRASES = {
  a: [['D3', 0, 0.9], ['Eb3', 0.42, 0.75], ['Fs3', 0.84, 0.8], ['G3', 1.26, 0.85], ['Fs3', 1.86, 0.7], ['Eb3', 2.16, 0.65], ['D3', 2.6, 0.95], ['D2', 2.6, 0.45], ['A2', 2.62, 0.3]],
  b: [['A3', 0, 0.8], ['G3', 0.38, 0.7], ['Fs3', 0.76, 0.75], ['Eb3', 1.14, 0.7], ['D3', 1.6, 0.9], ['D2', 1.6, 0.4], ['Fs3', 2.3, 0.45], ['A3', 2.45, 0.4], ['D4', 2.6, 0.5]],
};
// variant=json: النغمات من ملف (لحن مستخرج من تسجيل): [{midi, start, dur, amp}]
// النغمة الطويلة (أكثر من 0.4 ثانية) تنعزف رِيشة متكررة مثل العود
let notes;
if (variant === 'json') {
  const src = JSON.parse(fs.readFileSync(process.argv[4], 'utf8')).notes;
  const t0 = src[0].start;
  notes = [];
  for (const n of src) {
    const f = 440 * Math.pow(2, (n.midi - 69) / 12), g = 0.55 + 0.45 * n.amp, at = n.start - t0;
    notes.push([f, at, g]);
    if (n.dur > 0.4) for (let k = 1; at + k * 0.11 < at + n.dur; k++) notes.push([f, at + k * 0.11, g * (0.55 - k * 0.04)]);
  }
  const last = notes[notes.length - 1], base = src[src.length - 1];
  notes.push([440 * Math.pow(2, (base.midi - 12 - 69) / 12), src[src.length - 1].start - t0, 0.35]); // نغمة غليظة تحت الأخيرة
} else {
  notes = (PHRASES[variant] || PHRASES.a).map(([n, at, g]) => [N[n], at, g]);
}
const total = Math.max(...notes.map((n) => n[1])) + 2.4;
const mix = new Float32Array(Math.round(total * RATE));
for (const [freq, at, gain] of notes) {
  const s = pluck(freq, 2.4, gain, 0.35 + rnd() * 0.15);
  const off = Math.round(at * RATE);
  for (let i = 0; i < s.length && off + i < mix.length; i++) mix[off + i] += s[i];
}
let y = reverb(body(mix));
// تلاشي بالنهاية، وتطبيع على مستوى هادي
const fade = Math.round(0.6 * RATE);
let end = Math.round((total + 0.3) * RATE);
for (let i = 0; i < fade; i++) y[end - 1 - i] *= i / fade;
y = y.subarray(0, end);
const peak = y.reduce((m, v) => Math.max(m, Math.abs(v)), 0) || 1;
const out = Buffer.alloc(44 + y.length * 2);
out.write('RIFF', 0); out.writeUInt32LE(36 + y.length * 2, 4); out.write('WAVE', 8); out.write('fmt ', 12);
out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(1, 22); out.writeUInt32LE(RATE, 24); out.writeUInt32LE(RATE * 2, 28);
out.writeUInt16LE(2, 32); out.writeUInt16LE(16, 34); out.write('data', 36); out.writeUInt32LE(y.length * 2, 40);
for (let i = 0; i < y.length; i++) out.writeInt16LE(Math.round(y[i] / peak * 0.5 * 32767), 44 + i * 2);
fs.writeFileSync(outFile, out);
console.log(`${variant}: ${(y.length / RATE).toFixed(2)}s -> ${outFile}`);
