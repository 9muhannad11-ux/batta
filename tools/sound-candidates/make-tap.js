'use strict';
// صوت الضغط على القوائم: نقرة هادية منخفضة، بدون حدّة
// node tools/sound-candidates/make-tap.js -> app/assets/sounds/tap.wav
const fs = require('fs');
const path = require('path');

const SR = 44100, n = Math.round(SR * 0.1);
const body = Buffer.alloc(n * 2);
let phase = 0;
for (let i = 0; i < n; i++) {
  const t = i / SR;
  phase += 2 * Math.PI * (300 + 110 * Math.exp(-t * 70)) / SR;
  const v = Math.sin(phase) * Math.min(1, t / 0.005) * Math.exp(-t * 48);
  body.writeInt16LE(Math.round(v * 11000), i * 2);
}
const head = Buffer.alloc(44);
head.write('RIFF', 0, 'latin1'); head.writeUInt32LE(36 + body.length, 4); head.write('WAVEfmt ', 8, 'latin1');
head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(SR, 24);
head.writeUInt32LE(SR * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
head.write('data', 36, 'latin1'); head.writeUInt32LE(body.length, 40);
fs.writeFileSync(path.join(__dirname, '..', '..', 'app', 'assets', 'sounds', 'tap.wav'), Buffer.concat([head, body]));
console.log('tap.wav', n / SR);
