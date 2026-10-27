'use strict';
const test = require('node:test');
const assert = require('node:assert');

process.env.PORT = '0';
process.env.BOT_DELAY_MS = '0';
process.env.TRICK_PAUSE_MS = '0';
process.env.NEXT_ROUND_MS = '0';
process.env.DEAL_PAUSE_MS = '0';
process.env.TURN_MS = '300';
const { server } = require('../src/server');
const WebSocket = require('ws');

const ready = () => new Promise((r) => (server.listening ? r() : server.once('listening', r)));

test('a human with 5 bots can play a full match over websockets', async () => {
  await ready();
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  const sendMsg = (m) => ws.send(JSON.stringify(m));
  let signals = 0;

  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), 60000);
    let botsAdded = false;
    let started = false;
    let lastKey = null;
    ws.on('open', () => sendMsg({ t: 'create', name: 'مختبر' }));
    ws.on('message', (raw) => {
      const m = JSON.parse(raw);
      // الوقت قصير بالاختبار، فممكن السيرفر يلعب عنا قبل لا نرد
      if (m.t === 'error' && !/مو دورك|ما تقدر تلعب|غير مسموحة|الإشارة/.test(m.msg)) return reject(new Error(m.msg));
      if (m.t === 'signal') signals++;
      if (m.t === 'room' && !botsAdded) { botsAdded = true; return sendMsg({ t: 'addBots' }); }
      if (m.t === 'room' && !started && m.seats.every(Boolean)) { started = true; return sendMsg({ t: 'start' }); }
      if (m.t !== 'state') return;
      const v = m.view;
      if (v.phase === 'matchEnd') { clearTimeout(timer); return resolve(v); }
      // نتصرف مرة وحدة بكل دور (الإشارة ترسل حالة إضافية لنفس الدور)
      const key = `${v.round}/${v.phase}/${v.bids.length}/${v.trickNo}/${v.trick.length}`;
      if (key === lastKey) return;
      lastKey = key;
      if (v.legalBids.length) return sendMsg({ t: 'bid', value: 'pass' });
      if (v.phase === 'trump' && v.buyer === v.seat) return sendMsg({ t: 'trump', suit: 'H' });
      if (v.bawanOffer) return sendMsg({ t: 'bawan', accept: false });
      if (v.legalCards.length) {
        if (v.canSignal && signals === 0) sendMsg({ t: 'signal', suits: ['D', 'S'] });
        const safe = v.legalCards.filter((c) => !(c === 'JB' && v.blueLoses));
        return sendMsg({ t: 'play', card: (safe.length ? safe : v.legalCards)[0] });
      }
    });
  });

  assert.ok(result.winner === 0 || result.winner === 1);
  assert.ok(signals >= 1, 'signal was broadcast');
  ws.close();
});

test('an idle player is played for by the turn timer, and seats get characters', async () => {
  await ready();
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  const sendMsg = (m) => ws.send(JSON.stringify(m));
  const result = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), 120000);
    let stage = 0;
    ws.on('open', () => sendMsg({ t: 'create', name: 'نايم' }));
    ws.on('message', (raw) => {
      const m = JSON.parse(raw);
      if (m.t === 'error') return reject(new Error(m.msg));
      if (m.t === 'room' && stage === 0) { stage = 1; return sendMsg({ t: 'mode', mode: 4 }); }
      if (m.t === 'room' && stage === 1 && m.mode === 4) { stage = 2; return sendMsg({ t: 'addBots' }); }
      if (m.t === 'room' && stage === 2 && m.seats.every(Boolean)) {
        stage = 3;
        assert.strictEqual(m.seats.length, 4);
        assert.strictEqual(new Set(m.seats.map((s) => s.char)).size, 4);
        assert.strictEqual(m.seats[0].name, 'نايم');
        assert.ok(m.seats.slice(1).every((s) => s.bot && !s.name.includes('بوت')));
        return sendMsg({ t: 'start' });
      }
      if (m.t !== 'state') return;
      if (m.view.phase === 'matchEnd') { clearTimeout(timer); return resolve(m.view); }
      // اللاعب ما يزايد ولا يلعب أبداً، بس يختار الحكم (ما عليه وقت)
      if (m.view.phase === 'trump' && m.view.buyer === m.view.seat) sendMsg({ t: 'trump', suit: 'H' });
      if (m.view.bawanOffer) sendMsg({ t: 'bawan', accept: false });
    });
  });
  assert.strictEqual(result.players, 4);
  ws.close();
  server.close();
});
