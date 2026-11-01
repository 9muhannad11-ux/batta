'use strict';
// node tools/voices/lipsync.js
// يقرا كل أصوات الشخصيات (app/assets/voices/*.wav) ويطلع فتحة الفم لكل 20ms من علو الصوت،
// ويكتبها بـ app/lib/lipsync.dart. شغّله كل ما ينضاف أو يتغير صوت.
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const DIR = path.join(ROOT, 'app/assets/voices');
const OUT = path.join(ROOT, 'app/lib/lipsync.dart');
const STEP = 0.02; // ثانية لكل خانة

function readWav(file) {
  const buf = fs.readFileSync(file);
  let p = 12, fmt, data;
  while (p < buf.length) {
    const id = buf.toString('ascii', p, p + 4), n = buf.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = { channels: buf.readUInt16LE(p + 10), rate: buf.readUInt32LE(p + 12), bits: buf.readUInt16LE(p + 22) };
    if (id === 'data') data = buf.subarray(p + 8, p + 8 + n);
    p += 8 + n + (n & 1);
  }
  if (fmt.bits !== 16) throw new Error(file + ': only 16-bit wav');
  const frames = Math.floor(data.length / (2 * fmt.channels));
  const mono = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    let s = 0;
    for (let c = 0; c < fmt.channels; c++) s += data.readInt16LE((i * fmt.channels + c) * 2) / 32768;
    mono[i] = s / fmt.channels;
  }
  return { rate: fmt.rate, mono };
}

function mouth({ rate, mono: raw }) {
  // نخلي الترددات الواطية بس (حروف العلة تفتح الفم، والسين والشين لا)
  const mono = new Float32Array(raw.length), k = 1 - Math.exp(-2 * Math.PI * 900 / rate);
  for (let i = 0, y = 0; i < raw.length; i++) mono[i] = y += k * (raw[i] - y);
  const hop = Math.round(rate * STEP), win = Math.round(rate * 0.03);
  const rms = [];
  for (let a = 0; a < mono.length; a += hop) {
    let s = 0, n = 0;
    for (let i = Math.max(0, a - (win - hop) / 2); i < Math.min(mono.length, a + hop + (win - hop) / 2); i++, n++) s += mono[i | 0] ** 2;
    rms.push(Math.sqrt(s / Math.max(1, n)));
  }
  // العلو نسبة لأعلى مقاطع الصوت (95٪) عشان كل تسجيل يفتح الفم كامل وقت أعلى كلامه
  const ref = [...rms].sort((x, y) => x - y)[Math.floor(rms.length * 0.95)] || 1;
  let prev = 0;
  return rms.map((r) => {
    let v = Math.min(1, r / ref);
    v = v < 0.15 ? 0 : Math.pow((v - 0.15) / 0.85, 1.3); // السكوت = فم مسكّر
    v = Math.max(v, prev * 0.6); // يفتح بسرعة ويسكّر بنعومة
    prev = v;
    return Math.round(v * 100);
  });
}

const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.wav')).sort();
const lines = files.map((f) => `  '${f.replace('.wav', '')}': [${mouth(readWav(path.join(DIR, f))).join(', ')}],`);
fs.writeFileSync(OUT, `// ملف مولّد من tools/voices/lipsync.js (لا تعدله باليد)
/// فتحة الفم (0..100) لكل ${STEP * 1000}ms من كل صوت شخصية، من علو الصوت.
const lipSyncStepMs = ${STEP * 1000};
const lipSync = <String, List<int>>{
${lines.join('\n')}
};
`);
console.log('wrote', files.length, 'clips to', path.relative(ROOT, OUT));
// نفس البيانات لصفحة المعاينة (tools/voices/lipsync.html)
fs.writeFileSync(path.join(__dirname, 'lipsync.json'), JSON.stringify({ stepMs: STEP * 1000, clips: Object.fromEntries(files.map((f) => [f.replace('.wav', ''), mouth(readWav(path.join(DIR, f)))])) }));
