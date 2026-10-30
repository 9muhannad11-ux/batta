'use strict';
// node trim.js <in.wav> <out.wav>
// يقص السكوت من البداية والنهاية، يحول لقناة وحدة، ويخلي آخر الصوت يتلاشى بنعومة.
const fs = require('fs');
const [, , inFile, outFile] = process.argv;
const buf = fs.readFileSync(inFile);
let p = 12, fmt, data;
while (p < buf.length) {
  const id = buf.toString('ascii', p, p + 4), n = buf.readUInt32LE(p + 4);
  if (id === 'fmt ') fmt = { channels: buf.readUInt16LE(p + 10), rate: buf.readUInt32LE(p + 12), bits: buf.readUInt16LE(p + 22) };
  if (id === 'data') data = buf.subarray(p + 8, p + 8 + n);
  p += 8 + n + (n & 1);
}
if (fmt.bits !== 16) throw new Error('only 16-bit wav');
const frames = data.length / (2 * fmt.channels);
const mono = new Float32Array(frames);
for (let i = 0; i < frames; i++) {
  let s = 0;
  for (let c = 0; c < fmt.channels; c++) s += data.readInt16LE((i * fmt.channels + c) * 2) / 32768;
  mono[i] = s / fmt.channels;
}
// البداية والنهاية: أول وآخر عينة فوق -40dB (مع هامش صغير)
const thr = Math.pow(10, (+process.env.DB || -40) / 20); // حد السكوت بالديسيبل
let a = mono.findIndex((v) => Math.abs(v) > thr);
let b = frames - 1; while (b > a && Math.abs(mono[b]) < thr) b--;
a = Math.max(0, a - Math.round(fmt.rate * 0.003));
b = Math.min(frames - 1, b + Math.round(fmt.rate * 0.04));
const fade = Math.round(fmt.rate * 0.04);
const out = Buffer.alloc((b - a + 1) * 2);
for (let i = a; i <= b; i++) {
  let v = mono[i];
  const fromEnd = b - i; if (fromEnd < fade) v *= fromEnd / fade;
  out.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(v * 32767))), (i - a) * 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + out.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
h.writeUInt32LE(fmt.rate, 24); h.writeUInt32LE(fmt.rate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(out.length, 40);
fs.writeFileSync(outFile, Buffer.concat([h, out]));
console.log(`kept ${(a / fmt.rate).toFixed(3)}s - ${(b / fmt.rate).toFixed(3)}s (${((b - a) / fmt.rate).toFixed(2)}s), ${out.length + 44} bytes`);
