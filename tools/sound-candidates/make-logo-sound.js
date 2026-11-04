'use strict';
// صوت أنميشن الشعار بطابع عماني، مولّد بالكامل بنفس توقيت animate() بـ tools/logo-art/logo.html:
// طبل الرزحة والمرواس للدقات، عود على مقام البياتي للمروحة، وجلاجل مع اللمعة.
// node tools/sound-candidates/make-logo-sound.js -> tools/logo-art/logo_intro.wav
const fs = require('fs');
const path = require('path');

const SR = 44100, LENGTH = 3.2;
const out = new Float64Array(Math.round(SR * LENGTH));
let seed = 11;
const noise = () => (seed = (seed * 16807) % 2147483647) / 1073741823.5 - 1;
const put = (i, v) => { if (i < out.length) out[i] += v; };

// طبل الرزحة: دقة عميقة («دم»)
function dum(at, gain = 0.5, freq = 92) {
  const start = Math.round(at * SR);
  let phase = 0;
  for (let i = 0; i < 0.5 * SR; i++) {
    const t = i / SR;
    phase += 2 * Math.PI * (freq + 55 * Math.exp(-t * 35)) / SR;
    put(start + i, (Math.sin(phase) + 0.25 * Math.sin(phase * 1.6)) * Math.exp(-t * 7) * gain + noise() * Math.exp(-t * 180) * gain * 0.25);
  }
}

// المرواس: دقة صغيرة باليد («تك»)
function tak(at, gain = 0.18) {
  const start = Math.round(at * SR);
  let low = 0;
  for (let i = 0; i < 0.14 * SR; i++) {
    const t = i / SR;
    low += (noise() - low) * 0.35;
    put(start + i, (Math.sin(2 * Math.PI * 410 * t) * 0.55 + low * 0.9) * Math.exp(-t * 34) * gain);
  }
}

// العود: وتر منقور (Karplus-Strong) بصوت دافي
function oud(at, freq, gain = 0.3, length = 1.2, fade = 3) {
  const start = Math.round(at * SR);
  const n = Math.round(SR / freq), line = new Float64Array(n);
  let smooth = 0;
  for (let i = 0; i < n; i++) { smooth += (noise() - smooth) * 0.55; line[i] = smooth; }
  let last = 0;
  for (let i = 0; i < length * SR; i++) {
    const p = i % n, v = line[p];
    line[p] = (v * 0.5 + last * 0.5) * 0.996;
    last = v;
    put(start + i, v * gain * Math.min(1, i / (SR * 0.002)) * Math.exp(-i / SR * fade));
  }
}

// الجلاجل: رنين معدني صغير
function jingles(at, gain = 0.05) {
  const start = Math.round(at * SR);
  for (const [delay, f] of [[0, 5230], [0.045, 6170], [0.09, 7040], [0.14, 5890]]) {
    const s = start + Math.round(delay * SR);
    for (let i = 0; i < 0.3 * SR; i++) {
      const t = i / SR;
      put(s + i, (Math.sin(2 * Math.PI * f * t) + Math.sin(2 * Math.PI * f * 1.41 * t) * 0.6) * Math.exp(-t * 16) * gain);
    }
  }
}

// الكومة تنزل
dum(0.15, 0.28);
// المروحة: مقام البياتي على ري، والمي نص بيمول (ربع تون)، والمرواس يمشي مع كل ورقة
const bayati = [293.66, 320.2, 349.23, 392, 440];
bayati.forEach((f, i) => {
  oud(0.6 + i * 0.09, f, 0.28);
  tak(0.6 + i * 0.09, i === 4 ? 0.16 : 0.09);
});
// «بتّه»: دقة كبيرة وقفلة العود
dum(1.4, 0.3, 82);
oud(1.4, 146.83, 0.34, 1.2, 4);
oud(1.42, 293.66, 0.2, 1.2, 4);
tak(1.62, 0.08);
tak(1.8, 0.07);
// لمعة الجوكر
jingles(1.75);

// صدى خفيف مثل ساحة مفتوحة
const dry = out.slice();
for (const [delay, level] of [[0.13, 0.14], [0.27, 0.08]]) {
  const shift = Math.round(delay * SR);
  for (let i = shift; i < out.length; i++) out[i] += dry[i - shift] * level;
}
// آخر الملف يخفت لين يسكت
const tail = Math.round(SR * 0.4);
for (let i = 0; i < tail; i++) out[out.length - 1 - i] *= i / tail;

let peak = 0;
for (const v of out) peak = Math.max(peak, Math.abs(v));
const gain = 0.55 / peak;
const body = Buffer.alloc(out.length * 2);
out.forEach((v, i) => body.writeInt16LE(Math.round(v * gain * 32767), i * 2));
const head = Buffer.alloc(44);
head.write('RIFF', 0, 'latin1'); head.writeUInt32LE(36 + body.length, 4); head.write('WAVEfmt ', 8, 'latin1');
head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(SR, 24);
head.writeUInt32LE(SR * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
head.write('data', 36, 'latin1'); head.writeUInt32LE(body.length, 40);
fs.writeFileSync(path.join(__dirname, '..', 'logo-art', 'logo_intro.wav'), Buffer.concat([head, body]));
console.log(`logo_intro.wav ${LENGTH}s, mix peak ${(peak * 100).toFixed(0)}%, gain ${gain.toFixed(2)}`);
