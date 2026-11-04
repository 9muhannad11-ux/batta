'use strict';
// صوت التوزيع: صوت المستخدم deal_user.wav يتكرر بانتظام كصوت واحد، من بداية أنميشن التوزيع ويوقف قبل نهايته
// (نفس حساب _dealLayer بـ app/lib/table.dart، وبنفس الصوت للـ6 والـ4 لاعبين).
// node tools/sound-candidates/make-deal.js -> app/assets/sounds/deal.wav
const fs = require('fs');
const path = require('path');

const SOUND_S = 2.25; // الأنميشن 2.6 ثانية، والصوت يوقف قبله
const SOFT_HZ = 2600; // يخفف حدّة الطقّة
const SPEED = 0.85, EVERY = 0.16, MIX = 0.8; // سرعة المقطع، الوقت بين تكراره، وقوته لأنه يتداخل
const src = fs.readFileSync(path.join(__dirname, 'deal_user.wav'));
const sr = src.readUInt32LE(24);
const pcm = Array.from({ length: (src.length - 44) / 2 }, (_, i) => src.readInt16LE(44 + i * 2));
// الصوت يبدأ من أول طقّة، عشان يوافق طلعة الورق
const start = pcm.findIndex((v) => Math.abs(v) > 1000);
const raw = pcm.slice(Math.max(0, start - Math.round(sr * 0.005)));
const hit = Array.from({ length: Math.floor(raw.length / SPEED) - 1 }, (_, i) => {
  const x = i * SPEED, k = Math.floor(x);
  return (raw[k] + (raw[k + 1] - raw[k]) * (x - k)) * MIX;
});

while (Math.abs(hit[hit.length - 1]) < 300) hit.pop(); // السكوت بآخر المقطع
const a = 1 - Math.exp(-2 * Math.PI * SOFT_HZ / sr);
let soft = 0;
hit.forEach((v, i) => { soft += (v - soft) * a; hit[i] = soft; });

// آخر تكرار يخلص مع نهاية الصوت
const span = SOUND_S - hit.length / sr, hits = Math.round(span / EVERY) + 1, step = span / (hits - 1);
const out = new Int16Array(Math.round(sr * SOUND_S));
for (let k = 0; k < hits; k++) {
  const at = Math.round(k * step * sr);
  hit.forEach((v, j) => { if (at + j < out.length) out[at + j] = Math.max(-32768, Math.min(32767, out[at + j] + v)); });
}
const body = Buffer.from(out.buffer);
const head = Buffer.alloc(44);
head.write('RIFF', 0, 'latin1'); head.writeUInt32LE(36 + body.length, 4); head.write('WAVEfmt ', 8, 'latin1');
head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(sr, 24);
head.writeUInt32LE(sr * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
head.write('data', 36, 'latin1'); head.writeUInt32LE(body.length, 40);
fs.writeFileSync(path.join(__dirname, '..', '..', 'app', 'assets', 'sounds', 'deal.wav'), Buffer.concat([head, body]));
console.log(`deal.wav ${hits} hits every ${(step * 1000).toFixed(0)}ms, ${(out.length / sr).toFixed(2)}s`);
