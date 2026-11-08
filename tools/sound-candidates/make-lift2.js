'use strict';
// node tools/sound-candidates/make-lift2.js
// الدفعة الثانية لصوت ارتفاع الورقة الفايزة (الأولى ما عجبت):
// lift_c: سحبة ورق قصيرة (فرّة ورقة)، lift_d: نقرة خشب ناعمة، lift_e: «بُب» منخفض ناعم
const fs = require('fs');
const path = require('path');
const SR = 44100;

function wav(file, x) {
  const body = Buffer.alloc(x.length * 2);
  x.forEach((v, i) => body.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0, 'latin1'); h.writeUInt32LE(36 + body.length, 4); h.write('WAVEfmt ', 8, 'latin1');
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36, 'latin1'); h.writeUInt32LE(body.length, 40);
  fs.writeFileSync(file, Buffer.concat([h, body]));
}
const norm = (y, peak = 0.5) => { let pk = 0; for (const v of y) pk = Math.max(pk, Math.abs(v)); return y.map((v) => (v / pk) * peak); };
let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 * 2 - 1; };

// فرّة ورقة: ضجيج عالي بحبيبات (تقطّع سريع) وطلعة قصيرة
function flick() {
  const n = Math.round(0.13 * SR), y = new Float64Array(n);
  let hp = 0, prev = 0;
  for (let i = 0; i < n; i++) {
    const t = i / n;
    const w = rnd();
    hp = 0.86 * (hp + w - prev); prev = w; // عالي
    const grain = 0.6 + 0.4 * Math.sin(i / SR * 2 * Math.PI * 140); // خشخشة الورق
    const env = Math.min(1, t / 0.08) * Math.exp(-t * 6);
    y[i] = hp * grain * env;
  }
  return norm(y, 0.45);
}

// نقرة خشب: رنين قصير لتردد 1900 مع خفوت سريع
function wood() {
  const n = Math.round(0.09 * SR), y = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const env = Math.exp(-t / 0.018);
    y[i] = (Math.sin(2 * Math.PI * 1900 * t) * 0.7 + Math.sin(2 * Math.PI * 2950 * t) * 0.3) * env + rnd() * 0.15 * Math.exp(-t / 0.003);
  }
  return norm(y, 0.45);
}

// «بُب» ناعم: نغمة تنزل بسرعة من 520 لـ 260
function pop() {
  const n = Math.round(0.12 * SR), y = new Float64Array(n);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = 260 + 260 * Math.exp(-t / 0.02);
    ph += 2 * Math.PI * f / SR;
    const env = Math.min(1, t / 0.003) * Math.exp(-t / 0.035);
    y[i] = Math.sin(ph) * env;
  }
  return norm(y, 0.5);
}

const dir = __dirname;
wav(path.join(dir, 'lift_c.wav'), flick());
wav(path.join(dir, 'lift_d.wav'), wood());
wav(path.join(dir, 'lift_e.wav'), pop());
console.log('saved lift_c.wav, lift_d.wav, lift_e.wav');
