'use strict';
// يولّد أصوات اللعبة كملفات WAV بسيطة: node tools/gen-sounds.js
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const out = path.join(__dirname, '..', 'app', 'assets', 'sounds');
fs.mkdirSync(out, { recursive: true });

function wav(name, samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.max(-1, Math.min(1, v)) * 32767 | 0, i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(RATE, 24); h.writeUInt32LE(RATE * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(out, `${name}.wav`), Buffer.concat([h, data]));
}

const len = (sec) => new Float32Array(Math.round(sec * RATE));
let seed = 7;
const noise = () => { seed = (seed * 16807) % 2147483647; return (seed / 2147483647) * 2 - 1; };

function tone(buf, at, freq, dur, gain = 0.4, shape = 'tri') {
  const start = Math.round(at * RATE);
  for (let i = 0; i < dur * RATE && start + i < buf.length; i++) {
    const t = i / RATE;
    const ph = (freq * t) % 1;
    const w = shape === 'sine' ? Math.sin(2 * Math.PI * ph) : 4 * Math.abs(ph - 0.5) - 1;
    const env = Math.min(1, t / 0.01) * Math.exp(-t * (3 / dur));
    buf[start + i] += gain * w * env;
  }
}

// انزلاق ورقة ناعم على قماش الطاولة: ضوضاء مفلترة تطلع بهدوء وتخفت، مع لمسة نزول خفيفة
function softCard(buf, at, gain = 1, dur = 0.16) {
  const start = Math.round(at * RATE);
  let lp = 0, lp2 = 0, hpPrev = 0, hpOut = 0;
  for (let i = 0; i < dur * RATE && start + i < buf.length; i++) {
    const t = i / RATE;
    const x = noise();
    lp += (x - lp) * 0.22;
    lp2 += (lp - lp2) * 0.35;
    hpOut = 0.92 * (hpOut + lp2 - hpPrev); // يشيل الهمهمة الثقيلة
    hpPrev = lp2;
    const env = Math.min(1, t / 0.012) * Math.exp(-t * (5 / dur));
    const land = t > dur * 0.45 ? Math.sin(2 * Math.PI * 180 * (t - dur * 0.45)) * Math.exp(-(t - dur * 0.45) * 90) * 0.18 : 0;
    buf[start + i] += gain * (hpOut * env * 1.6 + land);
  }
}

// فلتر تمرير حزمة (biquad) عشان نطلع صوت الورق من الضوضاء
function bandpass(freq, q) {
  const w = 2 * Math.PI * freq / RATE, a = Math.sin(w) / (2 * q), c = Math.cos(w);
  const b0 = a / (1 + a), b2 = -a / (1 + a), a1 = -2 * c / (1 + a), a2 = (1 - a) / (1 + a);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  return (x) => { const y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2; x2 = x1; x1 = x; y2 = y1; y1 = y; return y; };
}

// ورقة تنحط على الطاولة: سحبة هوا خفيفة، بعدين طقّة ورق ناعمة، مع لمسة قماش
function paperSnap(buf, at, gain = 1, pitch = 1) {
  const start = Math.round(at * RATE);
  const swish = bandpass(1800 * pitch, 0.7), snap = bandpass(3200 * pitch, 1.1), body = bandpass(600 * pitch, 0.8);
  const pre = 0.035, dur = 0.12;
  for (let i = 0; i < (pre + dur) * RATE && start + i < buf.length; i++) {
    const t = i / RATE, x = noise();
    let v = swish(x) * Math.pow(Math.min(1, t / pre), 2) * (t < pre ? 0.35 : 0.35 * Math.exp(-(t - pre) * 60));
    if (t >= pre) {
      const u = t - pre, env = Math.min(1, u / 0.0015) * Math.exp(-u * 75);
      v += snap(x) * env * 1.3 + body(x) * env * 0.6;
    }
    buf[start + i] += gain * v;
  }
}

function normalize(buf, peak = 0.7) {
  const m = buf.reduce((a, v) => Math.max(a, Math.abs(v)), 0) || 1;
  for (let i = 0; i < buf.length; i++) buf[i] *= peak / m;
  return buf;
}

// رمي ورقة
{ const b = len(0.2); paperSnap(b, 0); wav('play', normalize(b, 0.6)); }

// توزيع: أوراق تنزل ورا بعض بخفة، كل وحدة تختلف شوي
{
  const b = len(1.25);
  for (let i = 0; i < 12; i++) paperSnap(b, i * 0.095, 0.75 + 0.25 * Math.abs(noise()), 0.9 + 0.2 * Math.abs(noise()));
  wav('deal', normalize(b, 0.45));
}

// لمّ اللمّة: كم ورقة تنسحب ورا بعض بنعومة
{ const b = len(0.45); for (let i = 0; i < 4; i++) softCard(b, i * 0.055, 0.75 - i * 0.1, 0.22); wav('collect', b); }

// تكة العداد
{ const b = len(0.06); tone(b, 0, 1200, 0.05, 0.5, 'sine'); wav('tick', b); }

// فوز بالجولة: نغمات صاعدة
{ const b = len(0.9); [523, 659, 784, 1047].forEach((f, i) => tone(b, i * 0.12, f, 0.45, 0.35)); wav('win', b); }

// خسارة الجولة: نغمات نازلة
{ const b = len(0.9); [392, 330, 262, 196].forEach((f, i) => tone(b, i * 0.15, f, 0.5, 0.35)); wav('lose', b); }

// تحوّل الطاولة للذهبي (باون)
{ const b = len(0.8); [784, 988, 1175, 1568].forEach((f, i) => tone(b, i * 0.06, f, 0.6, 0.25, 'sine')); wav('gold', b); }

// باون: فانفار الفوز بالمباراة
{
  const b = len(2.2);
  const notes = [[523, 0], [523, 0.15], [523, 0.3], [659, 0.45], [784, 0.75], [659, 1.0], [784, 1.15]];
  notes.forEach(([f, at]) => { tone(b, at, f, 0.5, 0.3); tone(b, at, f * 2, 0.4, 0.1, 'sine'); });
  [523, 659, 784, 1047].forEach((f) => tone(b, 1.35, f, 0.85, 0.18));
  wav('bawan', b);
}

console.log('sounds written to', out);
