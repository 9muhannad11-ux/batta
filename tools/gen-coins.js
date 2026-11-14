'use strict';
// صوت العملات (الغوازي): عملات معدن تطيح ورا بعض: node tools/gen-coins.js
// ملف لحاله عشان ما نعيد توليد باقي الأصوات
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const out = path.join(__dirname, '..', 'app', 'assets', 'sounds');

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

let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

// رنّة عملة: نغمات معدنية غير متناسقة تخفت بسرعة، وطقة خفيفة بالبداية
function clink(buf, at, base, gain) {
  const start = Math.round(at * RATE);
  const partials = [[1, 1, 18], [2.76, 0.55, 26], [5.4, 0.35, 38], [8.93, 0.2, 55]];
  for (let i = 0; i < 0.35 * RATE && start + i < buf.length; i++) {
    const t = i / RATE;
    let v = 0;
    for (const [m, g, d] of partials) v += g * Math.sin(2 * Math.PI * base * m * t) * Math.exp(-t * d);
    const click = t < 0.004 ? (rnd() * 2 - 1) * (1 - t / 0.004) * 0.5 : 0;
    buf[start + i] += gain * (v * Math.min(1, t / 0.0015) + click);
  }
}

const buf = new Float32Array(Math.round(0.85 * RATE));
// 7 عملات: تتسارع شوي، وآخر وحدة أوضح
const times = [0, 0.07, 0.13, 0.2, 0.26, 0.33, 0.42];
times.forEach((t, k) => clink(buf, t, 1900 + rnd() * 1300, k === times.length - 1 ? 0.5 : 0.32 + rnd() * 0.12));
let peak = 0;
for (const v of buf) peak = Math.max(peak, Math.abs(v));
for (let i = 0; i < buf.length; i++) buf[i] *= 0.6 / peak;
wav('coins', buf);
console.log('coins.wav');
