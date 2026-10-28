'use strict';
const test = require('node:test');
const assert = require('node:assert');
const E = require('../src/engine');
const Bot = require('../src/bot');

// يبني حالة لعب جاهزة بأوراق محددة
function setup({ hands, buyer = 0, bidValue = 6, trump = 'S', khabis = 5 }) {
  const s = E.createMatch({ khabis });
  s.hands = hands.map((h) => h.slice());
  s.greyHolder = s.hands.findIndex((h) => h.includes(E.GREY));
  s.bids = [];
  s.currentBid = bidValue;
  s.buyer = buyer;
  s.bawan = bidValue === 9;
  s.phase = 'trump';
  s.turn = buyer;
  E.chooseTrump(s, buyer, trump);
  return s;
}

function filler(n, suit, start = 2) {
  return Array.from({ length: n }, (_, i) => `${suit}-${start + i}`);
}

test('deck has 54 unique cards and each player gets 9', () => {
  const s = E.createMatch();
  const all = s.hands.flat();
  assert.strictEqual(all.length, 54);
  assert.strictEqual(new Set(all).size, 54);
  s.hands.forEach((h) => assert.strictEqual(h.length, 9));
});

test('bidding: single round, khabis last, must go higher, majbur when all pass', () => {
  const s = E.createMatch({ khabis: 2 });
  assert.strictEqual(s.turn, 3);
  for (const seat of [3, 4, 5, 0, 1, 2]) E.bid(s, seat, 'pass');
  assert.strictEqual(s.majbur, true);
  assert.strictEqual(s.buyer, 2);
  assert.strictEqual(s.currentBid, 6);
  assert.strictEqual(s.phase, 'trump');

  const t = E.createMatch({ khabis: 2 });
  E.bid(t, 3, 7);
  assert.deepStrictEqual(E.legalBids(t, 4), ['pass', 8, 9]);
  assert.throws(() => E.bid(t, 4, 7));
  E.bid(t, 4, 9); // باون ينهي المزايدة
  assert.strictEqual(t.phase, 'trump');
  assert.strictEqual(t.buyer, 4);
  assert.strictEqual(t.bawan, true);
});

test('first leader is right of buyer; jokers never lead (non-madmoon)', () => {
  const hands = [
    filler(9, 'H', 2),
    [E.GREY, ...filler(8, 'C', 2)],
    filler(9, 'D', 2),
    [E.BLUE, ...filler(8, 'S', 2)],
    [], [],
  ];
  const s = setup({ hands, buyer: 0 });
  assert.strictEqual(s.turn, 1);
  assert.ok(!E.legalCards(s, 1).includes(E.GREY));
  s.turn = 3;
  assert.ok(!E.legalCards(s, 3).includes(E.BLUE));
  s.hands[3] = [E.BLUE]; // ما عنده غير الجوكر: يُسمح له عشان ما ينحبس
  assert.deepStrictEqual(E.legalCards(s, 3), [E.BLUE]);
});

test('blue blocked until grey played; grey playable over follow-suit in first 3 tricks', () => {
  const hands = [
    filler(9, 'H', 2),
    ['D-2', ...filler(8, 'C', 2)],
    [E.GREY, 'H-11', ...filler(7, 'C', 9).slice(0, 7)],
    [E.BLUE, 'H-12', 'S-2', 'S-3', 'S-4', 'S-5', 'S-6', 'S-7', 'S-8'],
    ['H-13', 'S-9', 'S-10', 'S-11', 'S-12', 'S-13', 'S-14', 'D-3', 'D-4'],
    ['H-14', 'D-5', 'D-6', 'D-7', 'D-8', 'D-9', 'D-10', 'D-11', 'D-12'],
  ];
  const s = setup({ hands, buyer: 0 });
  E.playCard(s, 1, 'D-2');
  // مقعد 2 ما عنده ديمن: أي ورقة
  assert.ok(E.legalCards(s, 2).includes(E.GREY));
  E.playCard(s, 2, 'H-11');
  // مقعد 3 ما عنده ديمن: يقدر يرمي الكبير، بس بيخسّر فريقه المباراة
  assert.ok(E.legalCards(s, 3).includes(E.BLUE));
  assert.ok(E.blueLosesMatch(s, 3));
  E.playCard(s, 3, 'S-2');
  // مقعد 4 عنده ديمن: لازم يتبع
  assert.deepStrictEqual(E.legalCards(s, 4).sort(), ['D-3', 'D-4']);
});

test('grey exemption: may be played even when holding the led suit', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[], ['D-2'], [E.GREY, 'D-9'], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.turn = 2;
  s.trick = [{ seat: 1, card: 'D-2' }];
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['D-9', E.GREY].sort());
  s.trickNo = 3;
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['D-9', E.GREY].sort());
});

test('grey is not an ordinary trump: no obligation to play it when trump is led', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[], [], [E.GREY, 'H-4', 'D-5'], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.turn = 2; s.trickNo = 1;
  s.trick = [{ seat: 1, card: 'S-9' }];
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['D-5', 'H-4', E.GREY].sort());
});

test('madmoon: grey deadline is waived only once blue is out; label shows after blue', () => {
  // بدون نزول الأزرق: العقوبة تنطبق حتى في مضمون
  const a = E.createMatch({ khabis: 4 });
  Object.assign(a, { phase: 'playing', trump: 'S', buyer: 0, currentBid: 6, madmoon: true, greyHolder: 0,
    greyPlayed: false, bluePlayed: false, tricksWon: [1, 1], trickNo: 2, hands: [[], [], [], [], [], ['H-2']], turn: 5 });
  a.trick = [0, 1, 2, 3, 4].map((seat) => ({ seat, card: `H-${seat + 3}` }));
  assert.strictEqual(E.viewFor(a, 3).madmoon, false);
  E.playCard(a, 5, 'H-2');
  assert.strictEqual(a.lastRound.type, 'greyPenalty');
  // بعد نزول الأزرق: ما فيه موعد للرمادي، ومضمون يظهر للكل
  const b = E.createMatch({ khabis: 4 });
  Object.assign(b, { phase: 'playing', trump: 'S', buyer: 0, currentBid: 6, madmoon: true, greyHolder: 0,
    greyPlayed: false, bluePlayed: true, tricksWon: [1, 1], trickNo: 2, hands: [[], [], [], [], [], ['H-2']], turn: 5 });
  b.trick = [0, 1, 2, 3, 4].map((seat) => ({ seat, card: `H-${seat + 3}` }));
  assert.strictEqual(E.viewFor(b, 3).madmoon, true);
  E.playCard(b, 5, 'H-2');
  assert.strictEqual(b.phase, 'playing');
});

test('trick winner: blue > grey > trump ace > led suit', () => {
  const T = 'S';
  assert.strictEqual(E.trickWinner([{ seat: 0, card: 'H-14' }, { seat: 1, card: 'S-2' }], T), 1);
  assert.strictEqual(E.trickWinner([{ seat: 0, card: 'H-14' }, { seat: 1, card: E.GREY }, { seat: 2, card: 'S-14' }], T), 1);
  assert.strictEqual(E.trickWinner([{ seat: 0, card: 'H-3' }, { seat: 1, card: E.GREY }, { seat: 2, card: E.BLUE }], T), 2);
  assert.strictEqual(E.trickWinner([{ seat: 0, card: 'H-3' }, { seat: 1, card: 'D-14' }, { seat: 2, card: 'H-4' }], T), 2);
});

test('bid 8: first leader must lead a (non-joker) trump if available', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[], ['S-3', 'H-14', E.GREY], [], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 8; s.turn = 1;
  assert.deepStrictEqual(E.legalCards(s, 1), ['S-3']);
  s.currentBid = 7;
  assert.deepStrictEqual(E.legalCards(s, 1).sort(), ['H-14', 'S-3']);
});

test('madmoon: blue never leads; grey leads only after blue is out', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[E.BLUE, E.GREY, 'H-2'], [], [], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.madmoon = true; s.turn = 0;
  s.trickNo = 1;
  assert.deepStrictEqual(E.legalCards(s, 0), ['H-2']);
  s.hands[0] = [E.GREY, 'H-2'];
  s.bluePlayed = true;
  assert.deepStrictEqual(E.legalCards(s, 0).sort(), [E.GREY, 'H-2'].sort());
});

test('madmoon: buyer may play blue before grey when following', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[E.BLUE, E.GREY, 'H-2'], [], [], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.madmoon = true; s.turn = 0;
  s.trick = [{ seat: 1, card: 'H-9' }];
  assert.ok(E.legalCards(s, 0).includes(E.BLUE));
});

test('grey lead in madmoon does not force others to play trump', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[], ['S-3', 'H-4', 'D-5'], [], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.madmoon = true; s.bluePlayed = true; s.greyPlayed = true;
  s.trickNo = 2; s.turn = 1;
  s.trick = [{ seat: 0, card: E.GREY }];
  assert.deepStrictEqual(E.legalCards(s, 1).sort(), ['D-5', 'H-4', 'S-3']);
});

test('blue (once allowed) may be played instead of any suit, even trump', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[], [], ['S-3', 'H-4', E.BLUE], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.trickNo = 4; s.turn = 2;
  s.greyPlayed = true;
  s.trick = [{ seat: 1, card: 'S-9' }];
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['S-3', E.BLUE].sort());
  s.trick = [{ seat: 1, card: 'H-9' }];
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['H-4', E.BLUE].sort());
  // ما يلزم يلعب الأزرق إذا ما عنده من الحكم غيره
  s.hands[2] = ['H-4', 'D-2', E.BLUE];
  s.trick = [{ seat: 1, card: 'S-9' }];
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['D-2', 'H-4', E.BLUE].sort());
  // قبل نزول الصغير: الكبير مسموح بس رميه يخسّر المباراة
  s.greyPlayed = false;
  assert.deepStrictEqual(E.legalCards(s, 2).sort(), ['D-2', 'H-4', E.BLUE].sort());
  E.playCard(s, 2, E.BLUE);
  assert.deepStrictEqual([s.phase, s.winner, s.winReason], ['matchEnd', 1, 'blueEarly']);
});

test('madmoon buyer playing blue before grey does not lose', () => {
  const s = E.createMatch({ khabis: 5 });
  s.hands = [[E.BLUE, E.GREY, 'H-2'], ['H-9'], [], [], [], []];
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = 6; s.madmoon = true; s.turn = 0;
  s.trick = [{ seat: 5, card: 'D-9' }];
  E.playCard(s, 0, E.BLUE);
  assert.strictEqual(s.phase, 'playing');
  assert.strictEqual(E.viewFor(s, 3).madmoon, true);
});

// يجهّز آخر ورقة في لمّة: 5 أوراق نازلة ومقعد 5 يلعب الأخيرة
function finishTrick({ bidValue, majbur = false, tricksWon, winnerSeat, bawan = false }) {
  const s = E.createMatch({ khabis: 4 });
  s.phase = 'playing'; s.trump = 'S'; s.buyer = 0; s.currentBid = bidValue; s.majbur = majbur;
  s.bawan = bawan; s.greyPlayed = true; s.tricksWon = tricksWon.slice();
  s.trickNo = tricksWon[0] + tricksWon[1];
  s.hands = [[], [], [], [], [], ['H-2']];
  s.trick = [0, 1, 2, 3, 4].map((seat) => ({ seat, card: seat === winnerSeat ? 'H-14' : `H-${seat + 3}` }));
  s.turn = 5;
  E.playCard(s, 5, 'H-2');
  return s;
}

test('scoring: made gives bid, failed gives double, majbur gives 6', () => {
  let s = finishTrick({ bidValue: 7, tricksWon: [6, 1], winnerSeat: 0 });
  assert.deepStrictEqual([s.lastRound.type, s.scores], ['made', [7, 0]]);
  s = finishTrick({ bidValue: 7, tricksWon: [5, 2], winnerSeat: 1 });
  assert.deepStrictEqual([s.lastRound.type, s.scores], ['failed', [0, 14]]);
  s = finishTrick({ bidValue: 6, majbur: true, tricksWon: [4, 3], winnerSeat: 1 });
  assert.deepStrictEqual([s.lastRound.type, s.scores], ['failed', [0, 6]]);
  s = finishTrick({ bidValue: 8, tricksWon: [7, 0], winnerSeat: 2 });
  assert.deepStrictEqual([s.lastRound.type, s.scores], ['made', [8, 0]]);
});

test('bawan offer appears one trick before the bid while sweeping', () => {
  const s = finishTrick({ bidValue: 6, tricksWon: [4, 0], winnerSeat: 0 });
  assert.strictEqual(s.phase, 'bawanOffer');
  assert.ok(E.viewFor(s, 0).bawanOffer);
  assert.ok(!E.viewFor(s, 2).bawanOffer);
  E.answerBawan(s, 0, true);
  assert.strictEqual(s.bawan, true);
  assert.strictEqual(s.phase, 'playing');

  const lose = finishTrick({ bidValue: 6, bawan: true, tricksWon: [5, 0], winnerSeat: 1 });
  assert.deepStrictEqual([lose.phase, lose.winner, lose.winReason], ['matchEnd', 1, 'bawanFail']);
  const win = finishTrick({ bidValue: 6, bawan: true, tricksWon: [8, 0], winnerSeat: 2 });
  assert.deepStrictEqual([win.phase, win.winner, win.winReason], ['matchEnd', 0, 'bawanWin']);
});

test('khabis moves only when his team takes the lead', () => {
  let s = finishTrick({ bidValue: 7, tricksWon: [6, 1], winnerSeat: 0 }); // khabis 4 = فريق 0، فاز فريق 0
  assert.strictEqual(s.khabis, 5);
  s = finishTrick({ bidValue: 7, tricksWon: [5, 2], winnerSeat: 1 }); // فاز الخصم
  assert.strictEqual(s.khabis, 4);
});

for (const players of [6, 4]) {
  test(`full random ${players}-player matches with bots never break the rules`, () => {
    let seed = players;
    const rng = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    const outcomes = {};
    for (let g = 0; g < 200; g++) {
      const s = E.createMatch({ rng, players });
      assert.strictEqual(s.hands.flat().length, players === 6 ? 54 : 36);
      let steps = 0;
      while (s.phase !== 'matchEnd') {
        if (s.phase === 'roundEnd') {
          outcomes[s.lastRound.type] = (outcomes[s.lastRound.type] || 0) + 1;
          E.nextRound(s, rng);
          continue;
        }
        const seat = s.phase === 'bawanOffer' ? s.buyer : s.turn;
        const action = Bot.decide(s, seat);
        // البوت ما يزايد فوق 6
        if (action.type === 'bid') assert.ok(action.value === 'pass' || action.value === 6);
        Bot.apply(s, seat, action);
        assert.ok(++steps < 100000, 'match did not terminate');
      }
      assert.ok(s.winner === 0 || s.winner === 1);
      assert.notStrictEqual(s.winReason, 'blueEarly', 'bot threw the big joker too early');
      assert.ok(s.winReason === 'score' ? Math.max(...s.scores) >= 54 : ['bawanWin', 'bawanFail'].includes(s.winReason));
    }
    for (const k of ['made', 'failed']) assert.ok(outcomes[k] > 0, `no ${k} outcome`);
  });
}

test('4-player deck drops clubs/hearts 2-6 and spades/diamonds 2-5', () => {
  const deck = E.newDeck(4);
  assert.strictEqual(deck.length, 36);
  for (const c of ['C-6', 'H-2', 'S-5', 'D-3']) assert.ok(!deck.includes(c));
  for (const c of ['C-7', 'H-7', 'S-6', 'D-6', E.BLUE, E.GREY]) assert.ok(deck.includes(c));
});

test('hand order: jokers, hearts, clubs, diamonds, spades', () => {
  assert.deepStrictEqual(E.sortHand(['S-14', 'D-2', 'C-9', 'H-3', E.GREY, 'H-12', E.BLUE]),
    [E.BLUE, E.GREY, 'H-12', 'H-3', 'C-9', 'D-2', 'S-14']);
});

test('bot: leads strongest, but not trump when opponents bought; follows to win or under a winning mate', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: true, trickNo: 3, turn: 0 });
  s.hands[0] = ['S-14', 'H-13', 'H-4', 'D-9'];
  assert.strictEqual(Bot.decide(s, 0).card, 'H-13'); // الخصم مزايد: ما يفتتح بحكم
  s.buyer = 2;
  assert.strictEqual(Bot.decide(s, 0).card, 'S-14');
  // يتبع: الخصم ماسك اللمّة والخال نازل من قبل → أعلى ورقة من النوع
  s.turn = 0; s.played = ['H-14']; s.trick = [{ seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, 'H-13');
  // الزميل ماسك اللمّة → أصغر ورقة من النوع
  s.trick = [{ seat: 4, card: 'H-14' }, { seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, 'H-4');
  // ما عنده النوع: أصغر حكم
  s.hands[0] = ['S-14', 'S-3', 'D-9'];
  s.trick = [{ seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, 'S-3');
  // ما عنده النوع ولا حكم: أصغر ورقة
  s.hands[0] = ['D-14', 'D-9', 'C-2'];
  assert.strictEqual(Bot.decide(s, 0).card, 'C-2');
});

test('bot: third-trick lead is lowest card while small joker is out; never bawan', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 2, greyPlayed: false, trickNo: 2, turn: 0, trick: [] });
  s.hands[0] = ['S-14', 'H-13', 'H-4', 'D-9'];
  // الشاري من فريقه: أصغر حكم (وهنا ما عنده غير حكم واحد)
  assert.strictEqual(Bot.decide(s, 0).card, 'S-14');
  // الشاري من الخصم: أصغر ورقة غير الحكم
  s.buyer = 1;
  assert.strictEqual(Bot.decide(s, 0).card, 'H-4');
  s.phase = 'bawanOffer'; s.buyer = 0;
  assert.deepStrictEqual(Bot.decide(s, 0), { type: 'bawan', accept: false });
});

test('grey penalty: 15 points to opponents of holder when grey not played in 3 tricks', () => {
  const hands = [
    ['H-2', 'H-3', 'H-4', 'H-5', 'H-6', 'H-7', 'H-8', 'H-9', 'H-10'],
    ['D-2', 'D-3', 'D-4', 'D-5', 'D-6', 'D-7', 'D-8', 'D-9', 'D-10'],
    ['C-2', 'C-3', 'C-4', 'C-5', 'C-6', 'C-7', 'C-8', 'C-9', 'C-10'],
    [E.GREY, 'D-11', 'D-12', 'D-13', 'S-2', 'S-3', 'S-4', 'S-5', 'S-6'],
    [E.BLUE, 'S-7', 'S-8', 'S-9', 'S-10', 'S-11', 'S-12', 'S-13', 'S-14'],
    ['H-11', 'H-12', 'H-13', 'H-14', 'C-11', 'C-12', 'C-13', 'C-14', 'D-14'],
  ];
  const s = setup({ hands, buyer: 0, trump: 'S' });
  // 3 لمّات بدون رمادي: مقعد 3 دايماً يتبع ديمن
  for (let t = 0; t < 3; t++) {
    while (s.trick.length < 6 && s.phase === 'playing') {
      const seat = s.turn;
      const legal = E.legalCards(s, seat).filter((c) => !E.isJoker(c));
      E.playCard(s, seat, legal[0]);
    }
  }
  assert.strictEqual(s.lastRound.type, 'greyPenalty');
  assert.strictEqual(s.lastRound.team, 0); // الرمادي عند مقعد 3 (فريق 1)
  assert.strictEqual(s.scores[0], 15);
});

test('signals: only on your turn, several at once, joker signal rules', () => {
  const s = E.createMatch({ khabis: 5 });
  s.phase = 'playing'; s.trump = 'S'; s.turn = 2; s.signalsThisTurn = 0; s.greyPlayed = false;
  s.hands[2] = ['H-2', 'D-4'];
  assert.throws(() => E.signal(s, 1, ['H']));
  assert.deepStrictEqual(E.signal(s, 2, ['H', 'D']), { seat: 2, suits: ['H', 'D'] });
  assert.deepStrictEqual(E.signal(s, 2, ['C']), { seat: 2, suits: ['C'] });
  // بدون جوكر: ما فيه إشارة جوكر
  assert.throws(() => E.signal(s, 2, ['J']));
  // حامل الكبير ما يقدر لين ينزل الصغير
  s.hands[2] = [E.BLUE, 'H-2'];
  assert.throws(() => E.signal(s, 2, ['J']));
  s.greyPlayed = true;
  assert.deepStrictEqual(E.signal(s, 2, ['J']).suits, ['J']);
  // حامل الصغير يقدر
  s.signalsThisTurn = 0; s.greyPlayed = false; s.hands[2] = [E.GREY, 'H-2'];
  assert.deepStrictEqual(E.signal(s, 2, ['J', 'H']).suits, ['J', 'H']);
});

test('biased deal gives longer suits than a plain deal, still 54 unique cards', () => {
  const longest = (bias) => {
    let total = 0;
    for (let i = 0; i < 2000; i++) {
      const hands = E.deal(Math.random, bias);
      const all = hands.flat();
      assert.strictEqual(new Set(all).size, 54);
      for (const h of hands) {
        assert.strictEqual(h.length, 9);
        const c = {};
        for (const x of h) if (!E.isJoker(x)) c[x[0]] = (c[x[0]] || 0) + 1;
        total += Math.max(...Object.values(c));
      }
    }
    return total / 12000;
  };
  assert.ok(longest(0.4) > longest(0) + 0.5);
});

test('bot: does not take the trick from a winning teammate with the small joker (unless last chance)', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: false, trickNo: 1, turn: 0 });
  s.hands[0] = [E.GREY, 'H-9', 'H-3', 'D-2'];
  s.trick = [{ seat: 4, card: 'H-14' }, { seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, 'H-3');
  // الخصم ماسك اللمّة: ينزّل الصغير
  s.trick = [{ seat: 4, card: 'H-4' }, { seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, E.GREY);
  // آخر فرصة للصغير: ينزّله حتى لو زميله ماسك
  s.trickNo = 2; s.trick = [{ seat: 4, card: 'H-14' }, { seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, E.GREY);
});

test('bot: throws a joker when an opponent holds the trick and no normal card can beat it', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: true, trickNo: 4, turn: 0 });
  // الخصم نزّل الخال، والبوت عنده أصغر من النوع وعنده الكبير
  s.hands[0] = [E.BLUE, 'H-9', 'H-3'];
  s.trick = [{ seat: 5, card: 'H-14' }];
  assert.strictEqual(Bot.decide(s, 0).card, E.BLUE);
  // يقدر يغلبه بورقة عادية (الخال نازل من قبل): ما يضيّع الجوكر
  s.hands[0] = [E.BLUE, 'H-13', 'H-3'];
  s.played = ['H-14'];
  s.trick = [{ seat: 5, card: 'H-10' }];
  assert.strictEqual(Bot.decide(s, 0).card, 'H-13');
  s.played = [];
  // الكبير قبل نزول الصغير يخسّر المباراة: ما يرميه
  s.greyPlayed = false;
  s.hands[0] = [E.BLUE, 'H-9', 'H-3'];
  s.trick = [{ seat: 5, card: 'H-14' }];
  assert.notStrictEqual(Bot.decide(s, 0).card, E.BLUE);
  // الصغير يغلب الخال
  s.hands[0] = [E.GREY, 'H-9', 'H-3'];
  assert.strictEqual(Bot.decide(s, 0).card, E.GREY);
});

test('bot leads: highest trump when own team bought, lowest trump on 3rd trick before small joker', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 2, greyPlayed: true, trickNo: 4, turn: 0, trick: [] });
  s.hands[0] = ['S-13', 'S-4', 'H-14', 'D-9'];
  assert.strictEqual(Bot.decide(s, 0).card, 'S-13');
  s.trickNo = 2; s.greyPlayed = false;
  assert.strictEqual(Bot.decide(s, 0).card, 'S-4');
  // الشاري من الخصم: ما يفتتح بحكم
  s.buyer = 1; s.trickNo = 4; s.greyPlayed = true;
  assert.strictEqual(Bot.decide(s, 0).card, 'H-14');
});

test('bot: never misses a winnable trick (void suit: lowest winning trump over the opponent)', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: true, trickNo: 4, turn: 0 });
  s.hands[0] = ['S-3', 'S-12', 'D-2'];
  s.trick = [{ seat: 4, card: 'H-9' }, { seat: 5, card: 'S-10' }]; // الخصم قطع بحكم
  assert.strictEqual(Bot.decide(s, 0).card, 'S-12');
});

test('bot buys (6) only with 6+ cards of one suit, otherwise passes', () => {
  const s = E.createMatch({ khabis: 5 });
  assert.strictEqual(s.phase, 'bidding');
  const seat = s.turn;
  // خمس سبيت قوية + جوكرين + خالين: ما يكفي
  s.hands[seat] = [E.BLUE, E.GREY, 'S-14', 'S-13', 'S-12', 'S-11', 'S-10', 'H-14', 'D-14'];
  assert.strictEqual(Bot.decide(s, seat).value, 'pass');
  s.hands[seat] = ['H-2', 'H-3', 'H-4', 'H-5', 'H-6', 'H-7', 'C-2', 'D-3', 'S-4'];
  assert.strictEqual(Bot.decide(s, seat).value, 6);
});

test('bot: madmoon buyer leads the small joker -> lowest non-trump card of any suit', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 0, madmoon: true, bluePlayed: true, greyPlayed: true, trickNo: 4, turn: 1 });
  s.trick = [{ seat: 0, card: E.GREY }];
  s.hands[1] = ['S-2', 'H-9', 'D-4', 'C-13'];
  assert.strictEqual(Bot.decide(s, 1).card, 'D-4'); // خصم: ما يرمي حكم
  s.hands[1] = ['S-2', 'S-9'];
  assert.strictEqual(Bot.decide(s, 1).card, 'S-2'); // ما عنده إلا حكم
  s.turn = 3; s.trick.push({ seat: 1, card: 'D-4' }, { seat: 2, card: 'H-3' });
  s.hands[3] = ['S-3', 'C-10', 'H-5'];
  assert.strictEqual(Bot.decide(s, 3).card, 'H-5'); // زميل الشاري بعد
});

test('bot follows with its top card only if it is the highest left, otherwise its lowest', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: true, trickNo: 4, turn: 2 });
  s.trick = [{ seat: 1, card: 'H-7' }];
  s.hands[2] = ['H-13', 'H-3', 'D-2'];
  s.played = [];
  assert.strictEqual(Bot.decide(s, 2).card, 'H-3'); // الخال ما نزل: يرمي الأصغر
  s.played = ['H-14', 'C-2', 'C-3', 'C-4', 'C-5', 'C-6'];
  assert.strictEqual(Bot.decide(s, 2).card, 'H-13'); // الخال نزل: الشايب هو الأكبر
  s.hands[2] = ['H-12', 'H-3'];
  s.played = ['H-14'];
  assert.strictEqual(Bot.decide(s, 2).card, 'H-3'); // الشايب ما نزل: البنت ما تنرمي
  s.played = ['H-14', 'H-13'];
  assert.strictEqual(Bot.decide(s, 2).card, 'H-12');
});

test('bot: teammate buyer leads a low trump -> joker if held, else highest trump', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 0, greyPlayed: false, trickNo: 2, turn: 1 });
  s.played = [];
  s.trick = [{ seat: 0, card: 'S-3' }, { seat: 1, card: 'S-5' }];
  s.turn = 2;
  s.hands[2] = [E.GREY, 'S-4', 'S-11', 'H-2'];
  assert.strictEqual(Bot.decide(s, 2).card, E.GREY);
  s.hands[2] = ['S-4', 'S-11', 'H-2'];
  s.greyPlayed = true;
  assert.strictEqual(Bot.decide(s, 2).card, 'S-11');
});

test('bot void in led suit, opponent trumped: over-trump, else joker, else no wasted trump', () => {
  const s = E.createMatch({ khabis: 5 });
  Object.assign(s, { phase: 'playing', trump: 'S', currentBid: 6, buyer: 1, greyPlayed: true, trickNo: 4, turn: 0, played: [] });
  s.trick = [{ seat: 4, card: 'H-9' }, { seat: 5, card: 'S-8' }];
  s.hands[0] = ['S-3', 'S-10', 'S-13', 'D-2', E.GREY];
  assert.strictEqual(Bot.decide(s, 0).card, 'S-10'); // أصغر حكم يغلب، والجوكر يتخلّى
  s.hands[0] = ['S-3', E.GREY, 'D-2'];
  assert.strictEqual(Bot.decide(s, 0).card, E.GREY);
  s.hands[0] = ['S-3', E.BLUE, 'D-2'];
  assert.strictEqual(Bot.decide(s, 0).card, E.BLUE);
  s.hands[0] = ['S-3', 'D-2', 'C-9'];
  assert.strictEqual(Bot.decide(s, 0).card, 'D-2'); // ما يضيّع حكمه الصغير
});
