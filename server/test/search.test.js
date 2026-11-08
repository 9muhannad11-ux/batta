'use strict';
const test = require('node:test');
const assert = require('node:assert');

process.env.PORT = '0';
process.env.BOT_DELAY_MS = '0';
process.env.DEAL_PAUSE_MS = '0';
process.env.SEARCH_MS = '400';
const { server, rooms, schedule } = require('../src/server');
const E = require('../src/engine');
const WebSocket = require('ws');

const ready = () => new Promise((r) => (server.listening ? r() : server.once('listening', r)));

function player(onMessage) {
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  ws.on('message', (raw) => onMessage(JSON.parse(raw)));
  ws.say = (m) => ws.send(JSON.stringify(m));
  return new Promise((r) => ws.on('open', () => r(ws)));
}

const until = (test) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('timeout')), 3000);
  const poll = setInterval(() => {
    const v = test();
    if (v) { clearTimeout(timer); clearInterval(poll); resolve(v); }
  }, 10);
});

test('searching players share a room and bots fill it when time runs out', async () => {
  await ready();
  let a, b;
  const p1 = await player((m) => { if (m.t === 'room') a = m; });
  const p2 = await player((m) => { if (m.t === 'room') b = m; });
  p1.say({ t: 'search', mode: 4, score: 34, name: 'أ' });
  await until(() => a);
  p2.say({ t: 'search', mode: 4, score: 34, name: 'ب' });
  await until(() => b);
  assert.strictEqual(b.code, a.code);
  assert.strictEqual(b.search, true);
  assert.strictEqual(b.mode, 4);
  const done = await until(() => b.started && b);
  assert.strictEqual(done.search, false);
  assert.strictEqual(done.seats.filter((s) => s.bot).length, 2);
  assert.strictEqual(rooms.get(done.code).game.winScore, 34);
  p1.close();
  p2.close();
});

test('a full search starts at once, and a different target does not mix', async () => {
  const seen = [];
  const players = [];
  for (let i = 0; i < 4; i++) {
    players.push(await player((m) => { if (m.t === 'room') seen[i] = m; }));
    players[i].say({ t: 'search', mode: 4, score: i === 3 ? 54 : 34, name: `${i}` });
    await until(() => seen[i]);
  }
  assert.notStrictEqual(seen[3].code, seen[0].code);
  players.forEach((p) => p.close());
  await until(() => [...rooms.values()].every((r) => !r.search));
  const six = [];
  const again = [];
  for (let i = 0; i < 6; i++) {
    again.push(await player((m) => { if (m.t === 'room') six[i] = m; }));
    again[i].say({ t: 'search', mode: 6, score: 54, name: `${i}` });
    await until(() => six[i]);
  }
  await until(() => six[0].started);
  assert.ok(six[0].seats.every((s) => !s.bot));
  again.forEach((p) => p.close());
});

test('leaving the search removes the room', async () => {
  let room;
  const p = await player((m) => { if (m.t === 'room') room = m; });
  p.say({ t: 'search', mode: 6, score: 34, name: 'أ' });
  await until(() => room);
  p.close();
  await until(() => !rooms.has(room.code));
});

test('practice starts at once with bots and has no turn timer', async () => {
  let room, view;
  const p = await player((m) => {
    if (m.t === 'room') room = m;
    if (m.t === 'state') view = m.view;
  });
  p.say({ t: 'practice', name: 'أ' });
  await until(() => room?.started && view);
  assert.strictEqual(room.practice, true);
  assert.strictEqual(room.seats.filter((s) => s.bot).length, 5);
  await until(() => view.legalBids.length > 0);
  await until(() => view.turnMsLeft === null);
  p.close();
});

test('practice can be played with 4 players', async () => {
  let room;
  const p = await player((m) => { if (m.t === 'room') room = m; });
  p.say({ t: 'practice', mode: 4, name: 'أ' });
  await until(() => room?.started);
  assert.strictEqual(room.mode, 4);
  assert.strictEqual(room.seats.filter((s) => s.bot).length, 3);
  assert.strictEqual(rooms.get(room.code).game.hands.length, 4);
  p.close();
});

test('the last card in hand is played automatically', async () => {
  let room;
  const p = await player((m) => { if (m.t === 'room') room = m; });
  p.say({ t: 'practice', name: 'أ' });
  await until(() => room?.started);
  const r = rooms.get(room.code), g = r.game;
  clearTimeout(r.timer);
  Object.assign(g, {
    phase: 'playing', trump: 'S', buyer: 1, currentBid: 6, turn: 0, trick: [], trickNo: 8, greyPlayed: true,
    hands: [['S-14'], ['S-13'], ['S-12'], ['S-11'], ['S-10'], ['S-9']],
  });
  schedule(r);
  await until(() => g.hands[0].length === 0);
  assert.strictEqual(g.hands.flat().length < 6, true);
  p.close();
});

test('a match can be played to 34 points', () => {
  const g = E.createMatch({ winScore: 34 });
  assert.strictEqual(E.viewFor(g, 0).winScore, 34);
  server.close();
});
