'use strict';
// محرك قوانين لعبة بتّه (مبنية على كوت بو ثمانية بقوانين معدّلة).
// المقاعد 0..n-1 بترتيب اللعب (عكس عقارب الساعة): اللاعب "على يمين" المقعد s هو (s + 1) % n.
// الفريق = المقعد % 2، فاللاعبون يجلسون بالتناوب. n = 6 أو 4.

const SUITS = ['S', 'H', 'D', 'C']; // سبيت، هاس، ديمن، كلفس
const BLUE = 'JB'; // الجوكر الكبير (الملوّن) - الأعلى
const GREY = 'JG'; // الجوكر الصغير (غير الملوّن)
const JOKER_SIGNAL = 'J'; // إشارة الجوكر
const PLAYERS = 6; // الافتراضي
const MODES = [6, 4];
const TRICKS = 9;
const WIN_SCORE = 54;
const GREY_PENALTY = 15;
const GREY_DEADLINE = 3; // لازم ينزل الجوكر الصغير خلال أول 3 لمّات
const MIN_BID = 6;
const BAWAN = 9;
const MAX_SIGNALS_PER_TURN = 5; // كل نوع ينرسل لحاله لما ينضغط

const nextSeat = (seat, n = PLAYERS) => (seat + 1) % n;
const teamOf = (seat) => seat % 2;
const isJoker = (card) => card === BLUE || card === GREY;
const rankOf = (card) => Number(card.split('-')[1]);

// نمط 4 لاعبين: تنشال الكلفس والهاس من 2 إلى 6، والسبيت والديمن من 2 إلى 5 (36 ورقة)
function lowestRank(suit, players) {
  if (players !== 4) return 2;
  return suit === 'C' || suit === 'H' ? 7 : 6;
}

function newDeck(players = PLAYERS) {
  const deck = [BLUE, GREY];
  for (const s of SUITS) for (let r = lowestRank(s, players); r <= 14; r++) deck.push(`${s}-${r}`);
  return deck;
}

function shuffle(arr, rng = Math.random) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// احتمال إن الورقة الجاية للاعب تكون من النوع اللي عنده منه أكثر (0 = توزيع عادي)
const SUIT_BIAS = Number(process.env.SUIT_BIAS ?? 0.4);

// توزيع منحاز: يزيد فرصة إن اللاعب ياخذ أوراق من نفس النوع.
// الأوراق توزّع لفّة لفّة، وبكل مرة باحتمال `bias` تجي الورقة من النوع الغالب عند اللاعب.
function deal(rng = Math.random, bias = SUIT_BIAS, players = PLAYERS) {
  const pool = shuffle(newDeck(players), rng);
  const hands = Array.from({ length: players }, () => []);
  for (let r = 0; r < TRICKS; r++) {
    for (const hand of hands) {
      let idx = pool.length - 1;
      if (hand.length && rng() < bias) {
        const counts = {};
        for (const c of hand) if (!isJoker(c)) counts[c[0]] = (counts[c[0]] || 0) + 1;
        const top = Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0];
        const found = top ? pool.findIndex((c) => c[0] === top && !isJoker(c)) : -1;
        if (found >= 0) idx = found;
      }
      hand.push(pool.splice(idx, 1)[0]);
    }
  }
  return hands;
}

// الجوكرات تُعامل كورق حكم في تحديد الفائز.
function suitOf(card, trump) {
  return isJoker(card) ? trump : card.split('-')[0];
}

function power(card) {
  if (card === BLUE) return 100;
  if (card === GREY) return 99;
  return rankOf(card);
}

function createMatch({ rng = Math.random, khabis, players = PLAYERS } = {}) {
  if (!MODES.includes(players)) throw new Error('عدد لاعبين غير مدعوم');
  const state = {
    players,
    phase: 'bidding',
    scores: [0, 0],
    khabis: khabis ?? Math.floor(rng() * players),
    round: 0,
    winner: null,
    winReason: null,
    lastRound: null,
  };
  startRound(state, rng);
  return state;
}

function startRound(state, rng = Math.random) {
  state.round += 1;
  state.phase = 'bidding';
  state.hands = deal(rng, SUIT_BIAS, state.players);
  state.bids = []; // [{seat, bid}] حيث bid رقم أو 'pass'
  state.currentBid = 0;
  state.buyer = null;
  state.majbur = false;
  state.trump = null;
  state.madmoon = false;
  state.turn = nextSeat(state.khabis, state.players); // المزايدة تبدأ من يمين الخابص
  state.trick = []; // [{seat, card}]
  state.trickNo = 0; // عدد اللمّات المكتملة
  state.tricksWon = [0, 0];
  state.greyPlayed = false;
  state.bluePlayed = false;
  state.greyHolder = state.hands.findIndex((h) => h.includes(GREY));
  state.bawan = false; // هل الفريق المزايد ملتزم بكل اللمّات
  state.lastTrick = null;
  state.played = []; // كل الأوراق اللي نزلت في اللمّات المكتملة هالجولة
  state.signalsThisTurn = 0;
  return state;
}

function fail(msg) {
  const e = new Error(msg);
  e.code = 'ILLEGAL';
  throw e;
}

// ---------- المزايدة ----------

// الخابص إذا وصله الدور ومحد زايد: بدل «طاف» عنده «6 مجبور» (MAJBUR)
const MAJBUR = 'majbur';

function legalBids(state, seat) {
  if (state.phase !== 'bidding' || state.turn !== seat) return [];
  const out = [seat === state.khabis && state.buyer === null ? MAJBUR : 'pass'];
  for (let b = Math.max(MIN_BID, state.currentBid + 1); b <= BAWAN; b++) out.push(b);
  return out;
}

function bid(state, seat, value) {
  if (!legalBids(state, seat).includes(value)) fail('مزايدة غير مسموحة');
  state.bids.push({ seat, bid: value });
  if (value === MAJBUR) {
    // 6 مجبور: الخسارة 6 بس للخصم بدون مضاعفة، وبدون باون
    state.currentBid = MIN_BID;
    state.buyer = seat;
    state.majbur = true;
  } else if (value !== 'pass') {
    state.currentBid = value;
    state.buyer = seat;
  }
  const finished = value === BAWAN || seat === state.khabis;
  if (!finished) {
    state.turn = nextSeat(seat, state.players);
    return state;
  }
  state.bawan = state.currentBid === BAWAN;
  state.phase = 'trump';
  state.turn = state.buyer;
  return state;
}

function chooseTrump(state, seat, suit) {
  if (state.phase !== 'trump' || seat !== state.buyer) fail('مو دورك تختار الحكم');
  if (!SUITS.includes(suit)) fail('نوع غير معروف');
  state.trump = suit;
  const hand = state.hands[state.buyer];
  state.madmoon = hand.includes(BLUE) && hand.includes(GREY);
  state.phase = 'playing';
  state.turn = nextSeat(state.buyer, state.players); // أول لاعب على يمين الشاري يبدأ، والشاري آخر واحد
  state.signalsThisTurn = 0;
  return state;
}

// ---------- اللعب ----------

// رمي الجوكر الكبير قبل الصغير يخسّر فريق اللي رماه المباراة، إلا الشاري في مضمون
function blueLosesMatch(state, seat) {
  return !state.greyPlayed && !(state.madmoon && seat === state.buyer);
}

function legalCards(state, seat) {
  if (state.phase !== 'playing' || state.turn !== seat) return [];
  const hand = state.hands[seat];
  const trump = state.trump;
  const any = () => hand.slice();

  if (state.trick.length === 0) {
    // الكبير ما يفتتح أبداً. الصغير يفتتح بس للشاري في مضمون بعد ما ينزل الكبير
    const canLeadGrey = state.madmoon && seat === state.buyer && state.bluePlayed;
    let options = hand.filter((c) => !isJoker(c) || (c === GREY && canLeadGrey));
    if (state.currentBid === 8 && state.trickNo === 0) {
      const trumps = options.filter((c) => suitOf(c, trump) === trump);
      if (trumps.length) options = trumps;
    }
    return options.length ? options : any();
  }

  // افتتاح الصغير في مضمون ما يجبر أحد يرمي حكم: أي ورقة
  if (state.trick[0].card === GREY) return any();

  const led = suitOf(state.trick[0].card, trump);
  // الجوكرين مو ورق حكم عادي: ما يلزم أحد يرميهم، وينلعبون بدل أي نوع
  const follow = hand.filter((c) => !isJoker(c) && suitOf(c, trump) === led);
  if (!follow.length) return any();
  for (const j of [GREY, BLUE]) if (hand.includes(j)) follow.push(j);
  return follow;
}

function trickWinner(trick, trump) {
  const led = suitOf(trick[0].card, trump);
  let best = trick[0];
  for (const t of trick.slice(1)) {
    const tTrump = suitOf(t.card, trump) === trump;
    const bTrump = suitOf(best.card, trump) === trump;
    if (tTrump && !bTrump) best = t;
    else if (tTrump === bTrump && suitOf(t.card, trump) === suitOf(best.card, trump) && power(t.card) > power(best.card)) best = t;
    else if (!tTrump && !bTrump && suitOf(t.card, trump) === led && suitOf(best.card, trump) !== led) best = t;
  }
  return best.seat;
}

function playCard(state, seat, card) {
  if (!legalCards(state, seat).includes(card)) fail('ما تقدر تلعب هالورقة');
  const hand = state.hands[seat];
  hand.splice(hand.indexOf(card), 1);
  state.trick.push({ seat, card });
  state.signalsThisTurn = 0;

  if (card === BLUE) {
    const loses = blueLosesMatch(state, seat);
    state.bluePlayed = true;
    if (loses) return endRound(state, { type: 'blueEarly', team: 1 - teamOf(seat), matchWin: true, offender: seat });
  }
  if (card === GREY) state.greyPlayed = true;

  if (state.trick.length < state.players) {
    state.turn = nextSeat(seat, state.players);
    return state;
  }

  const winner = trickWinner(state.trick, state.trump);
  state.tricksWon[teamOf(winner)] += 1;
  state.trickNo += 1;
  state.lastTrick = { cards: state.trick, winner };
  state.played.push(...state.trick.map((t) => t.card));
  state.trick = [];
  state.turn = winner;
  resolveAfterTrick(state);
  return state;
}

function resolveAfterTrick(state) {
  const bidTeam = teamOf(state.buyer);
  const opp = 1 - bidTeam;

  // في مضمون يسقط موعد الصغير بس إذا الكبير نزل
  if (state.trickNo === GREY_DEADLINE && !state.greyPlayed && !(state.madmoon && state.bluePlayed)) {
    return endRound(state, { type: 'greyPenalty', team: 1 - teamOf(state.greyHolder), points: GREY_PENALTY, offender: state.greyHolder });
  }

  if (state.bawan) {
    if (state.tricksWon[opp] > 0) return endRound(state, { type: 'bawanFail', team: opp, matchWin: true });
    if (state.tricksWon[bidTeam] === TRICKS) return endRound(state, { type: 'bawanWin', team: bidTeam, matchWin: true });
    return;
  }

  const need = state.currentBid;
  if (state.tricksWon[bidTeam] >= need) {
    return endRound(state, { type: 'made', team: bidTeam, points: state.majbur ? MIN_BID : need });
  }
  if (state.tricksWon[opp] > TRICKS - need) {
    return endRound(state, { type: 'failed', team: opp, points: state.majbur ? MIN_BID : need * 2 });
  }
  // خيار الباون: الفريق أخذ كل اللمّات وباقي له لمّة وحدة (المجبور ما له باون)
  if (!state.majbur && state.tricksWon[opp] === 0 && state.tricksWon[bidTeam] === need - 1) {
    state.phase = 'bawanOffer';
  }
}

function answerBawan(state, seat, accept) {
  if (state.phase !== 'bawanOffer' || seat !== state.buyer) fail('مو وقت الباون');
  state.bawan = !!accept;
  state.phase = 'playing';
  return state;
}

function endRound(state, result) {
  if (result.matchWin) {
    state.winner = result.team;
    state.winReason = result.type;
  } else {
    state.scores[result.team] += result.points;
    if (state.scores[result.team] >= WIN_SCORE) {
      state.winner = result.team;
      state.winReason = 'score';
    }
  }
  state.lastRound = { ...result, buyer: state.buyer, bid: state.currentBid, majbur: state.majbur, tricksWon: state.tricksWon.slice() };
  // الخابص يبقى حتى يتقدم فريقه في النتيجة، بعدها ينتقل لللاعب التالي
  const kTeam = teamOf(state.khabis);
  if (state.scores[kTeam] > state.scores[1 - kTeam]) state.khabis = nextSeat(state.khabis, state.players);
  state.phase = state.winner === null ? 'roundEnd' : 'matchEnd';
}

function nextRound(state, rng = Math.random) {
  if (state.phase !== 'roundEnd') fail('الجولة ما خلصت');
  return startRound(state, rng);
}

// إشارة الجوكر: لازم يكون عندك جوكر، وحامل الكبير ما يستخدمها لين ينزل الصغير
function canSignalJoker(state, seat) {
  const hand = state.hands[seat] || [];
  if (!hand.some(isJoker)) return false;
  return !(hand.includes(BLUE) && !state.greyPlayed);
}

function canSignal(state, seat) {
  return state.phase === 'playing' && state.turn === seat && state.signalsThisTurn < MAX_SIGNALS_PER_TURN;
}

// إشارة وحدة أو أكثر قبل لعب الورقة، وتظهر كلها مع بعض
function signal(state, seat, suits) {
  if (!canSignal(state, seat)) fail('الإشارة قبل لعب ورقتك بس');
  const list = [...new Set(Array.isArray(suits) ? suits : [suits])];
  if (!list.length || list.some((s) => !SUITS.includes(s) && s !== JOKER_SIGNAL)) fail('إشارة غير معروفة');
  if (list.includes(JOKER_SIGNAL) && !canSignalJoker(state, seat)) fail('ما تقدر تستخدم إشارة الجوكر');
  state.signalsThisTurn += 1;
  // big: إشارة الجوكر من صاحب الكبير (التطبيق يعرضها كف يضرب ورقته بدل الفقاعة)
  return { seat, suits: list, big: list.includes(JOKER_SIGNAL) && state.hands[seat].includes(BLUE) };
}

// ما يشوفه كل لاعب: أوراقه فقط، وعدد أوراق البقية
function viewFor(state, seat) {
  return {
    seat,
    players: state.players,
    team: teamOf(seat),
    phase: state.phase,
    round: state.round,
    scores: state.scores,
    khabis: state.khabis,
    turn: state.turn,
    hand: state.hands[seat] ? sortHand(state.hands[seat]) : [],
    handCounts: state.hands.map((h) => h.length),
    bids: state.bids,
    currentBid: state.currentBid,
    buyer: state.buyer,
    majbur: state.majbur,
    trump: state.trump,
    // مضمون ينكشف للكل بس بعد ما ينزل الكبير
    madmoon: state.madmoon && state.bluePlayed,
    bluePlayed: state.bluePlayed,
    bawan: state.bawan,
    trick: state.trick,
    trickNo: state.trickNo,
    tricksWon: state.tricksWon,
    greyPlayed: state.greyPlayed,
    lastTrick: state.lastTrick,
    lastRound: state.lastRound,
    winner: state.winner,
    winReason: state.winReason,
    legalBids: legalBids(state, seat),
    legalCards: legalCards(state, seat),
    // هل رمي الكبير الحين يخسّر المباراة (عشان التطبيق ينبّه اللاعب)
    blueLoses: state.phase === 'playing' && blueLosesMatch(state, seat),
    canSignal: canSignal(state, seat),
    canSignalJoker: canSignalJoker(state, seat),
    hasJoker: (state.hands[seat] || []).some(isJoker),
    bawanOffer: state.phase === 'bawanOffer' && seat === state.buyer,
  };
}

// الترتيب من اليسار: هاس، كلفس، ديمن، سبيت (الأعلى أول)، وبعدها الجوكرين.
// إذا نوع ناقص نعيد الترتيب عشان يبقى أحمر ثم أسود ثم أحمر (لين ما يصير ممكن)
const HAND_ORDER = ['H', 'C', 'D', 'S'];
const RED = ['H', 'D'];
const BLACK = ['C', 'S'];
function suitSequence(hand) {
  const has = (s) => hand.some((c) => !isJoker(c) && c[0] === s);
  const reds = RED.filter(has);
  const blacks = BLACK.filter(has);
  const [first, second] = reds.length >= blacks.length ? [reds, blacks] : [blacks, reds];
  const seq = [];
  for (let i = 0; i < first.length; i++) {
    seq.push(first[i]);
    if (i < second.length) seq.push(second[i]);
  }
  return seq;
}
function sortHand(hand) {
  const seq = suitSequence(hand);
  const order = (c) => {
    if (isJoker(c)) return 1000 + (c === BLUE ? 0 : 1);
    return seq.indexOf(c[0]) * 100 - rankOf(c);
  };
  return hand.slice().sort((a, b) => order(a) - order(b));
}

module.exports = {
  SUITS, BLUE, GREY, JOKER_SIGNAL, PLAYERS, MODES, TRICKS, WIN_SCORE, GREY_PENALTY, GREY_DEADLINE, MIN_BID, BAWAN, MAJBUR,
  nextSeat, teamOf, isJoker, suitOf, power, rankOf, newDeck, shuffle, deal, sortHand,
  createMatch, startRound, legalBids, bid, chooseTrump, legalCards, trickWinner, blueLosesMatch,
  playCard, answerBawan, nextRound, signal, viewFor,
};
