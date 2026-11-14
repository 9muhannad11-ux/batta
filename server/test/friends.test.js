'use strict';
const test = require('node:test');
const assert = require('node:assert');

process.env.PORT = '0';
const { server } = require('../src/server');
const WebSocket = require('ws');

const ready = () => new Promise((r) => (server.listening ? r() : server.once('listening', r)));

// اتصال: نرسل رسائل وننتظر أول رسالة من نوع معيّن
async function client() {
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  await new Promise((r) => ws.once('open', r));
  const inbox = [], waiters = [];
  ws.on('message', (raw) => {
    const m = JSON.parse(raw);
    const i = waiters.findIndex((w) => w.t === m.t);
    if (i >= 0) waiters.splice(i, 1)[0].resolve(m);
    else inbox.push(m);
  });
  return {
    ws,
    send: (m) => ws.send(JSON.stringify(m)),
    next: (t) => {
      const i = inbox.findIndex((m) => m.t === t);
      if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
      return new Promise((resolve) => waiters.push({ t, resolve }));
    },
  };
}

test('friends: who is online, in a room, and room invites', async () => {
  await ready();
  const a = await client(), b = await client(), bGame = await client();
  a.send({ t: 'hello', fc: 'aaa111', name: 'مهند', char: 'aslam' });
  await a.next('hello');
  b.send({ t: 'hello', fc: 'BBB222', name: 'سالم', char: 'wadamtih' });
  await b.next('hello');

  a.send({ t: 'friends', list: ['BBB222', 'ZZZ999'] });
  let f = await a.next('friends');
  assert.deepStrictEqual(f.online, { BBB222: { s: 'online', name: 'سالم', char: 'wadamtih' } });

  // سالم سوّى غرفة: حالته «بغرفة»، وكوده يطلع للي بالغرفة
  bGame.send({ t: 'create', name: 'سالم', fc: 'BBB222' });
  const joined = await bGame.next('joined');
  const room = await bGame.next('room');
  assert.strictEqual(room.seats[0].fc, 'BBB222');
  a.send({ t: 'friends', list: ['BBB222'] });
  f = await a.next('friends');
  assert.strictEqual(f.online.BBB222.s, 'room');

  // سالم يدعو مهند لغرفته: توصل لاتصال الحضور حق مهند
  b.send({ t: 'invite', to: 'AAA111', code: joined.code });
  assert.strictEqual((await b.next('inviteSent')).ok, true);
  assert.deepStrictEqual(await a.next('invited'), { t: 'invited', from: 'سالم', code: joined.code });

  // طلع: ما يبين متصل
  b.ws.close();
  bGame.ws.close();
  await new Promise((r) => setTimeout(r, 150));
  a.send({ t: 'friends', list: ['BBB222'] });
  f = await a.next('friends');
  assert.deepStrictEqual(f.online, {});
  a.ws.close();
  server.close();
});
