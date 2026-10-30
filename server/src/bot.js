'use strict';
// بوت يعبّي المقاعد الفاضية، ويلعب بدل اللاعب إذا خلص وقته.
// البوت ما يشوف إلا أوراقه والأوراق اللي نزلت على الطاولة.
const E = require('./engine');

function bestSuit(hand) {
  let best = E.SUITS[0];
  let bestScore = -1;
  for (const s of E.SUITS) {
    const cards = hand.filter((c) => !E.isJoker(c) && c[0] === s);
    const score = cards.length * 2 + cards.filter((c) => E.rankOf(c) >= 12).length;
    if (score > bestScore) { bestScore = score; best = s; }
  }
  return best;
}

// اللاعب اللي خلص وقته وهو يختار الحكم: النوع اللي عنده منه أكثر، والتعادل للأقوى (أعلى ورقة ثم اللي بعدها)
function mostSuit(hand) {
  const ranks = (s) => hand.filter((c) => !E.isJoker(c) && c[0] === s).map(E.rankOf).sort((a, b) => b - a);
  const stronger = (a, b) => {
    if (a.length !== b.length) return a.length > b.length;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] > b[i];
    return false;
  };
  let best = E.SUITS[0];
  for (const s of E.SUITS) if (stronger(ranks(s), ranks(best))) best = s;
  return best;
}

// قوة الورقة عند البوت: الحكم أقوى من غيره، والجوكرات آخر شي يفكر فيها
function strength(card, trump) {
  if (E.isJoker(card)) return 1000 + E.power(card);
  return (card[0] === trump ? 100 : 0) + E.rankOf(card);
}
const lowest = (cards, trump) => cards.reduce((a, b) => (strength(b, trump) < strength(a, trump) ? b : a));
const highest = (cards, trump) => cards.reduce((a, b) => (strength(b, trump) > strength(a, trump) ? b : a));

function decideBid(state, seat) {
  const hand = state.hands[seat];
  // البوت ما يشري إلا إذا عنده 6 أوراق أو أكثر من نوع واحد، وما يزايد أكثر من 6
  const longest = Math.max(...E.SUITS.map((s) => hand.filter((c) => !E.isJoker(c) && c[0] === s).length));
  const legal = E.legalBids(state, seat);
  // الخابص ومحد زايد: «6 مجبور» أحسن له من 6 العادية (الخسارة ما تتضاعف)
  if (legal.includes(E.MAJBUR)) return { type: 'bid', value: E.MAJBUR };
  return { type: 'bid', value: longest >= 6 && legal.includes(6) ? 6 : 'pass' };
}

function decidePlay(state, seat) {
  const trump = state.trump;
  const hand = state.hands[seat];
  const myTeam = E.teamOf(seat);
  let legal = E.legalCards(state, seat);
  // لا يرمي الكبير إذا بيخسّر فريقه المباراة
  if (E.blueLosesMatch(state, seat) && legal.length > 1) legal = legal.filter((c) => c !== E.BLUE);

  const mateWinning = state.trick.length > 0 && (() => {
    const w = E.trickWinner(state.trick, trump);
    return w !== seat && E.teamOf(w) === myTeam;
  })();

  // الجوكر الصغير لازم ينزل في أول 3 لمّات (في مضمون يكفي ينزل الكبير).
  // ما ياخذ اللمّة من زميله إلا إذا هذي آخر فرصة (اللمّة الثالثة)
  const deadlineOpen = !state.greyPlayed && !(state.madmoon && state.bluePlayed);
  const lastChance = state.trickNo === E.GREY_DEADLINE - 1;
  if (deadlineOpen && state.trickNo >= 1 && state.trick.length > 0 && (!mateWinning || lastChance)) {
    if (state.madmoon && seat === state.buyer && legal.includes(E.BLUE)) return E.BLUE;
    if (legal.includes(E.GREY)) return E.GREY;
  }

  const plain = legal.filter((c) => !E.isJoker(c));
  if (!plain.length) return legal[0];
  const trumps = plain.filter((c) => c[0] === trump);
  const nonTrumps = plain.filter((c) => c[0] !== trump);
  const oppBought = E.teamOf(state.buyer) !== myTeam;

  if (state.trick.length === 0) {
    const thirdBeforeGrey = state.trickNo === 2 && !state.greyPlayed;
    // معه الصغير ويفتتح اللمّة الثانية: أصغر ورقة، عشان ما ياخذها ويفتتح الثالثة (الصغير ما يفتتح)
    if (state.trickNo === 1 && deadlineOpen && hand.includes(E.GREY)) return lowest(plain, trump);
    // اللمّة الثالثة وزميله الشاري: أصغر حكم بس إذا هو من 2 لين 7، وإلا أصغر ورقة من غير الحكم
    if (thirdBeforeGrey && !oppBought && seat !== state.buyer) {
      const low = trumps.length ? lowest(trumps, trump) : null;
      if (low && E.rankOf(low) <= 7) return low;
      return lowest(nonTrumps.length ? nonTrumps : plain, trump);
    }
    // افتتاح أول لمّة لما الخصم مزايد بـ 8: أصغر حكم
    if (state.trickNo === 0 && state.currentBid === 8 && oppBought && trumps.length) return lowest(trumps, trump);
    if (oppBought) {
      // الشاري من الخصم: يتفادى الافتتاح بحكم
      const pool = nonTrumps.length ? nonTrumps : plain;
      return thirdBeforeGrey ? lowest(pool, trump) : highest(pool, trump);
    }
    // زميله الشاري، والبوت افتتح بحكم قبل ومحد رمى حكم غير الشاري: الباقين خلص حكمهم، يوقف الافتتاح بحكم
    const trumpDry = seat !== state.buyer && nonTrumps.length && (state.tricks || []).some((t) =>
      t.cards[0].seat === seat && t.cards[0].card[0] === trump &&
      t.cards.every((x) => x.seat === seat || x.seat === state.buyer || x.card[0] !== trump));
    if (trumpDry) return thirdBeforeGrey ? lowest(nonTrumps, trump) : highest(nonTrumps, trump);
    // الشاري من فريقه: يفتتح بأكبر حكم، إلا اللمّة الثالثة والصغير ما نزل فيفتتح بأصغر حكم
    if (trumps.length) return thirdBeforeGrey ? lowest(trumps, trump) : highest(trumps, trump);
    return thirdBeforeGrey ? lowest(plain, trump) : highest(plain, trump);
  }

  const ledByGrey = state.trick[0].card === E.GREY;
  const led = E.suitOf(state.trick[0].card, trump);
  const same = ledByGrey ? [] : plain.filter((c) => c[0] === led);

  // مضمون والشاري افتتح بالجوكر الصغير: يرمي أصغر ورقة من أي نوع غير الحكم
  if (ledByGrey) return lowest(nonTrumps.length ? nonTrumps : plain.length ? plain : legal, trump);

  // اللمّة الثالثة والصغير ما نزل (وهو مو معه): يرمي أصغر ورقة، حتى لو ما عنده النوع (ما يقطع)
  if (deadlineOpen && lastChance && !hand.includes(E.GREY)) return lowest(same.length ? same : plain, trump);

  const wins = (card) => E.trickWinner([...state.trick, { seat, card }], trump) === seat;

  // الورقة أكبر وحدة باقية من نوعها؟ (كل الأكبر منها نزلت قبل أو نازلة باللمّة الحين)
  const seen = new Set([...state.played, ...state.trick.map((t) => t.card)]);
  const isTop = (card, alsoKnown = []) => {
    for (let r = E.rankOf(card) + 1; r <= 14; r++) {
      const c = `${card[0]}-${r}`;
      if (!seen.has(c) && !alsoKnown.includes(c)) return false;
    }
    return true;
  };

  // زميله الشاري افتتح بحكم صغير (فيه حكم أكبر منه ما نزل): يرمي الجوكر إذا عنده، وإلا أكبر حكم
  const lead = state.trick[0];
  if (lead.seat === state.buyer && E.teamOf(lead.seat) === myTeam && !E.isJoker(lead.card) && lead.card[0] === trump && !isTop(lead.card)) {
    const joker = [E.GREY, E.BLUE].find((j) => legal.includes(j));
    if (joker) return joker;
    if (trumps.length) return highest(trumps, trump);
  }

  // البوت هو الشاري والافتتاح بحكم: يلعب أكبر حكم باقي أو جوكر،
  // إلا إذا زميله نزّل أكبر حكم بعد الأحكام اللي عند الشاري (فيرمي أصغر ورقة تحت زميله)
  if (seat === state.buyer && !E.isJoker(lead.card) && lead.card[0] === trump) {
    const w = E.trickWinner(state.trick, trump);
    const winCard = state.trick.find((t) => t.seat === w).card;
    const mateHasTop = mateWinning && !E.isJoker(winCard) && winCard[0] === trump && isTop(winCard, hand);
    if (!mateHasTop) {
      const top = trumps.length ? highest(trumps, trump) : null;
      if (top && isTop(top) && wins(top)) return top;
      const joker = [E.GREY, E.BLUE].find((j) => legal.includes(j) && wins(j));
      if (joker) return joker;
    }
  }

  // زميله صاحب أكبر ورقة باللمّة: يرمي أصغر ورقة عنده ويخلي اللمّة له
  if (mateWinning) return lowest(same.length ? same : (nonTrumps.length ? nonTrumps : plain), trump);

  // الخصم ماسك اللمّة: إذا ما يقدر يغلبه بورقة عادية، يرمي الجوكر (الأصغر اللي يغلب)
  const plainWinners = plain.filter(wins);
  if (!plainWinners.length) {
    const joker = [E.GREY, E.BLUE].find((j) => legal.includes(j) && wins(j));
    if (joker) return joker;
  }

  if (same.length) {
    // آخر واحد يلعب: يكفيه أصغر ورقة تغلب
    if (state.trick.length === state.players - 1) {
      const winners = same.filter(wins);
      return lowest(winners.length ? winners : same, trump);
    }
    // يرمي أكبر ورقة من النوع إذا هي الأكبر الباقية وتغلب، وإلا أصغر ورقة
    const top = highest(same, trump);
    return wins(top) && isTop(top) ? top : lowest(same, trump);
  }
  // ما عنده النوع: يقطع بأصغر حكم يغلب (حتى لو الخصم قاطع بحكم). الجوكر فوق إذا ما في حكم يغلب
  const winningTrumps = trumps.filter(wins);
  if (winningTrumps.length) return lowest(winningTrumps, trump);
  // ما يقدر يغلب: ما يضيّع حكم، يرمي أصغر ورقة من غير الحكم
  return lowest(nonTrumps.length ? nonTrumps : plain, trump);
}

function decide(state, seat, { timeout = false } = {}) {
  if (state.phase === 'bidding' && state.turn === seat) {
    // لاعب خلص وقته يطوف (والخابص اللي ما زايد أحد قبله يصير 6 مجبور)
    if (timeout) return { type: 'bid', value: E.legalBids(state, seat)[0] };
    return decideBid(state, seat);
  }
  if (state.phase === 'trump' && state.buyer === seat) {
    return { type: 'trump', suit: (timeout ? mostSuit : bestSuit)(state.hands[seat]) };
  }
  if (state.phase === 'bawanOffer' && state.buyer === seat) {
    return { type: 'bawan', accept: false }; // البوت ما يفعّل الباون
  }
  if (state.phase === 'playing' && state.turn === seat) {
    return { type: 'play', card: decidePlay(state, seat) };
  }
  return null;
}

function apply(state, seat, action) {
  switch (action.type) {
    case 'bid': return E.bid(state, seat, action.value);
    case 'trump': return E.chooseTrump(state, seat, action.suit);
    case 'bawan': return E.answerBawan(state, seat, action.accept);
    case 'play': return E.playCard(state, seat, action.card);
    default: throw new Error('unknown action');
  }
}

module.exports = { decide, apply, mostSuit };
