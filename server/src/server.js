'use strict';
// سيرفر الغرف: كل غرفة لها كود، 6 أو 4 مقاعد، والسيرفر هو الحكم الوحيد على القوانين.
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const E = require('./engine');
const Bot = require('./bot');

const PORT = Number(process.env.PORT ?? 8080);
const BOT_DELAY_MS = Number(process.env.BOT_DELAY_MS ?? 900);
const TRICK_PAUSE_MS = Number(process.env.TRICK_PAUSE_MS ?? 1600); // وقت أنميشن لمّ اللمّة
const DEAL_PAUSE_MS = Number(process.env.DEAL_PAUSE_MS ?? 1500); // وقت أنميشن التوزيع
const NEXT_ROUND_MS = Number(process.env.NEXT_ROUND_MS ?? 5000);
const TURN_MS = Number(process.env.TURN_MS ?? 12500); // وقت كل لاعب للمزايدة واللعب (12.5 ثانية)
const TRUMP_MS = Number(process.env.TRUMP_MS ?? 10000); // وقت اختيار الحكم

// الشخصيات: البوت ياخذ اسم الشخصية، واللاعب ياخذ وجهها ويبقى اسمه
const CHARACTERS = [
  { id: 'khalfan', name: 'خلفان التفق' },
  { id: 'khusaib', name: 'خصيب' },
  { id: 'marhoon', name: 'مرهون' },
  { id: 'musabbah', name: 'مصبّح' },
  { id: 'bodhirs', name: 'محمد بو ضرس' },
  { id: 'abdo', name: 'عبدو اليابس' },
  { id: 'sadiq', name: 'صديق' },
  { id: 'mundaghit', name: 'المنضغط' },
  { id: 'wadamtih', name: 'ود عمتيه' },
  { id: 'buhamdan', name: 'بو حمدان' },
];

const rooms = new Map(); // code -> room

function newCode() {
  let code;
  do code = String(Math.floor(1000 + Math.random() * 9000)); while (rooms.has(code));
  return code;
}

function createRoom() {
  const room = {
    code: newCode(),
    mode: E.PLAYERS,
    seats: Array(E.PLAYERS).fill(null), // {name, token, bot, ws, char}
    host: null, // token
    game: null,
    timer: null,
    deadline: null, // متى يخلص وقت اللاعب الحالي
    touched: Date.now(),
  };
  rooms.set(room.code, room);
  return room;
}

// شخصية عشوائية ما أحد ماخذها بالغرفة
function freeCharacter(room) {
  const used = new Set(room.seats.filter(Boolean).map((s) => s.char));
  const free = CHARACTERS.filter((c) => !used.has(c.id));
  return free[Math.floor(Math.random() * free.length)];
}

function newSeat(room, { name, ws = null, bot = false }) {
  const ch = freeCharacter(room);
  return { name: bot ? ch.name : name, token: crypto.randomUUID(), bot, ws, char: ch.id };
}

function send(ws, msg) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

function lobbyInfo(room) {
  return {
    t: 'room',
    code: room.code,
    mode: room.mode,
    started: !!room.game,
    seats: room.seats.map((s) => s && { name: s.name, bot: s.bot, connected: s.bot || !!s.ws, char: s.char }),
  };
}

function broadcast(room) {
  room.touched = Date.now();
  // إشارة جوكر تحددت مع الورقة (صاحب الجوكرين): توصل قبل الحالة عشان الكف يلحق الورقة
  const resolved = room.game?.resolvedSignal;
  if (resolved) {
    room.game.resolvedSignal = null;
    emitAll(room, { t: 'signal', ...resolved });
  }
  const info = lobbyInfo(room);
  const turnMsLeft = room.deadline ? Math.max(0, room.deadline - Date.now()) : null;
  room.seats.forEach((s, seat) => {
    if (!s || s.bot) return;
    send(s.ws, { ...info, you: seat, isHost: s.token === room.host });
    if (room.game) send(s.ws, { t: 'state', view: { ...E.viewFor(room.game, seat), turnMsLeft } });
  });
}

function emitAll(room, msg) {
  room.seats.forEach((s) => s && !s.bot && send(s.ws, msg));
}

function actor(game) {
  if (game.phase === 'bawanOffer' || game.phase === 'trump') return game.buyer;
  if (game.phase === 'bidding' || game.phase === 'playing') return game.turn;
  return null;
}

// بعد كل حركة: نعطي وقت للأنميشن، نشغّل البوتات، نحسب وقت اللاعب، ونبدأ الجولة التالية تلقائياً
function schedule(room) {
  clearTimeout(room.timer);
  room.deadline = null;
  const g = room.game;
  if (!g) return;
  if (g.phase === 'roundEnd') {
    room.timer = setTimeout(() => { E.nextRound(g); schedule(room); broadcast(room); }, NEXT_ROUND_MS);
    return;
  }
  const seat = actor(g);
  if (seat === null) return;
  const justFinishedTrick = g.phase === 'playing' && g.trick.length === 0 && g.lastTrick && g.trickNo > 0;
  const justDealt = g.phase === 'bidding' && g.bids.length === 0;
  const pause = (justFinishedTrick ? TRICK_PAUSE_MS : 0) + (justDealt ? DEAL_PAUSE_MS : 0);
  const act = (opts) => {
    const action = Bot.decide(g, seat, opts);
    if (!action) return;
    Bot.apply(g, seat, action);
    schedule(room);
    broadcast(room);
  };
  if (room.seats[seat]?.bot) {
    room.timer = setTimeout(() => act({}), BOT_DELAY_MS + pause);
    return;
  }
  // اللاعب عنده 12.5 ثانية يزايد أو يلعب، وإذا خلص الوقت السيرفر يلعب عنه
  if (g.phase === 'bidding' || g.phase === 'playing') {
    room.deadline = Date.now() + TURN_MS + pause;
    room.timer = setTimeout(() => act({ timeout: true }), TURN_MS + pause);
  } else if (g.phase === 'trump') {
    // 10 ثواني لاختيار الحكم، وبعدها السيرفر يختار النوع اللي عنده منه أكثر
    room.deadline = Date.now() + TRUMP_MS;
    room.timer = setTimeout(() => act({ timeout: true }), TRUMP_MS);
  }
}

function seatOf(room, token) {
  return room.seats.findIndex((s) => s && s.token === token);
}

function handle(ws, msg) {
  const ctx = ws.ctx;
  switch (msg.t) {
    case 'create': {
      const room = createRoom();
      const seat = newSeat(room, { name: cleanName(msg.name), ws });
      room.seats[0] = seat;
      room.host = seat.token;
      ctx.room = room; ctx.token = seat.token;
      send(ws, { t: 'joined', code: room.code, token: seat.token });
      return broadcast(room);
    }
    case 'join': {
      const room = rooms.get(String(msg.code));
      if (!room) return send(ws, { t: 'error', msg: 'ما فيه غرفة بهالكود' });
      if (msg.token && seatOf(room, msg.token) >= 0) {
        // رجوع لاعب انقطع اتصاله
        const s = room.seats[seatOf(room, msg.token)];
        s.ws = ws; ctx.room = room; ctx.token = msg.token;
        send(ws, { t: 'joined', code: room.code, token: msg.token });
        return broadcast(room);
      }
      if (room.game) return send(ws, { t: 'error', msg: 'اللعبة بدأت' });
      const free = room.seats.findIndex((s) => !s);
      if (free < 0) return send(ws, { t: 'error', msg: 'الغرفة مليانة' });
      const seat = newSeat(room, { name: cleanName(msg.name), ws });
      room.seats[free] = seat;
      ctx.room = room; ctx.token = seat.token;
      send(ws, { t: 'joined', code: room.code, token: seat.token });
      return broadcast(room);
    }
  }

  const room = ctx.room;
  if (!room) return send(ws, { t: 'error', msg: 'ادخل غرفة أول' });
  const seat = seatOf(room, ctx.token);
  if (seat < 0) return send(ws, { t: 'error', msg: 'مو موجود بالغرفة' });
  const isHost = ctx.token === room.host;

  try {
    switch (msg.t) {
      case 'sit': { // تغيير المقعد في اللوبي (لاختيار الفريق)
        const to = Number(msg.seat);
        if (room.game || !(to >= 0 && to < room.mode)) throw illegal('ما تقدر تغير المقعد');
        const other = room.seats[to];
        if (other && !other.bot) throw illegal('المقعد محجوز');
        room.seats[to] = room.seats[seat];
        room.seats[seat] = other || null;
        break;
      }
      case 'mode': { // 6 أو 4 لاعبين
        const mode = Number(msg.mode);
        if (!isHost || room.game) throw illegal('للمضيف قبل البداية');
        if (!E.MODES.includes(mode)) throw illegal('نمط غير معروف');
        const extra = room.seats.slice(mode).filter(Boolean);
        if (extra.some((s) => !s.bot)) throw illegal('فيه لاعبين بالمقاعد اللي بتنشال، خلهم ينتقلون أول');
        room.seats = Array.from({ length: mode }, (_, i) => room.seats[i] || null);
        room.mode = mode;
        break;
      }
      case 'addBots':
        if (!isHost || room.game) throw illegal('للمضيف قبل البداية');
        room.seats.forEach((s, i) => { if (!s) room.seats[i] = newSeat(room, { bot: true }); });
        break;
      case 'kick': {
        if (!isHost || room.game) throw illegal('للمضيف قبل البداية');
        const i = Number(msg.seat);
        if (room.seats[i] && room.seats[i].token !== room.host) {
          send(room.seats[i].ws, { t: 'kicked' });
          room.seats[i] = null;
        }
        break;
      }
      case 'start':
        if (!isHost || room.game) throw illegal('للمضيف قبل البداية');
        if (room.seats.some((s) => !s)) throw illegal(`لازم ${room.mode} لاعبين (أو عبّي بالبوتات)`);
        room.game = E.createMatch({ players: room.mode });
        break;
      case 'bid': E.bid(game(room), seat, msg.value === 'pass' || msg.value === E.MAJBUR ? msg.value : Number(msg.value)); break;
      case 'trump': E.chooseTrump(game(room), seat, msg.suit); break;
      case 'play': E.playCard(game(room), seat, msg.card); break;
      case 'bawan': E.answerBawan(game(room), seat, !!msg.accept); break;
      case 'signal': {
        const sig = E.signal(game(room), seat, msg.suits ?? msg.suit);
        if (sig.suits.length) emitAll(room, { t: 'signal', ...sig });
        return broadcast(room); // عشان تتحدث لوحة الإشارة عند صاحبها
      }
      case 'rematch':
        if (!isHost || room.game?.phase !== 'matchEnd') throw illegal('للمضيف بعد نهاية المباراة');
        room.game = E.createMatch({ players: room.mode });
        break;
      default:
        throw illegal('رسالة غير معروفة');
    }
  } catch (e) {
    if (e.code !== 'ILLEGAL') throw e;
    return send(ws, { t: 'error', msg: e.message });
  }
  schedule(room);
  broadcast(room);
}

function game(room) {
  if (!room.game) throw illegal('اللعبة ما بدأت');
  return room.game;
}

function illegal(msg) {
  const e = new Error(msg);
  e.code = 'ILLEGAL';
  return e;
}

function cleanName(name) {
  return String(name || 'لاعب').trim().slice(0, 20) || 'لاعب';
}

// اختياري: STATIC_DIR يخلي السيرفر يقدّم نسخة الويب من التطبيق (flutter build web)
const STATIC_DIR = process.env.STATIC_DIR && path.resolve(process.env.STATIC_DIR);
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css',
  '.png': 'image/png', '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.svg': 'image/svg+xml',
  '.wav': 'audio/wav', '.apk': 'application/vnd.android.package-archive' };

const server = http.createServer((req, res) => {
  if (!STATIC_DIR) {
    res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
    return res.end(`kout server ok - rooms: ${rooms.size}\n`);
  }
  const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = path.join(STATIC_DIR, urlPath === '/' ? 'index.html' : urlPath);
  if (!file.startsWith(STATIC_DIR)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(STATIC_DIR, 'index.html');
  res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  ws.ctx = {};
  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data); } catch { return send(ws, { t: 'error', msg: 'رسالة غير صالحة' }); }
    try { handle(ws, msg); } catch (e) {
      console.error(e);
      send(ws, { t: 'error', msg: 'خطأ في السيرفر' });
    }
  });
  ws.on('close', () => {
    const room = ws.ctx.room;
    if (!room) return;
    const i = seatOf(room, ws.ctx.token);
    if (i < 0 || room.seats[i].ws !== ws) return;
    if (room.game) room.seats[i].ws = null; // يبقى مقعده محجوز لين يرجع
    else if (ws.ctx.token !== room.host) room.seats[i] = null;
    else room.seats[i].ws = null;
    broadcast(room);
  });
});

// تنظيف الغرف المهجورة كل 10 دقائق
setInterval(() => {
  const cutoff = Date.now() - 60 * 60 * 1000;
  for (const [code, room] of rooms) {
    const anyone = room.seats.some((s) => s && !s.bot && s.ws);
    if (!anyone && room.touched < cutoff) { clearTimeout(room.timer); rooms.delete(code); }
  }
}, 10 * 60 * 1000).unref();

server.listen(PORT, () => console.log(`kout server listening on :${PORT}`));

module.exports = { server, rooms, CHARACTERS };
