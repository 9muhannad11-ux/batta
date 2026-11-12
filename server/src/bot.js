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
  // البوت ما يشري إلا إذا عنده 6 أوراق أو أكثر من نوع واحد، وما يزايد أكثر من 6 (إلا 7 أوراق من نوع والخصم زايد 6: 7)
  const longest = Math.max(...E.SUITS.map((s) => hand.filter((c) => !E.isJoker(c) && c[0] === s).length));
  const legal = E.legalBids(state, seat);
  // عنده 7 أوراق أو أكثر من نوع واحد: محد زايد قبله → 6 (تحت)، الخصم زايد 6 → يزايد 7،
  // وإذا آخر مزايدة لزميله يطوف
  if (longest >= 7 && state.buyer != null && state.buyer !== seat) {
    if (E.teamOf(state.buyer) === E.teamOf(seat)) return { type: 'bid', value: legal.includes('pass') ? 'pass' : legal[0] };
    if (state.currentBid === 6 && legal.includes(7)) return { type: 'bid', value: 7 };
  }
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

  // اللمّة الثانية ومعه الصغير: إذا كل ورقه العادية تاخذ اللمّة (ما يقدر يخليها)، بيفتتح الثالثة
  // والصغير ما يفتتح فيخيسه، فهو مجبور يرمي الصغير الحين
  if (deadlineOpen && state.trickNo === 1 && state.trick.length > 0 && hand.includes(E.GREY) && legal.includes(E.GREY)) {
    const plainNow = legal.filter((c) => !E.isJoker(c));
    const taking = (c) => E.trickWinner([...state.trick, { seat, card: c }], trump) === seat;
    if (plainNow.length && plainNow.every(taking)) return E.GREY;
    // وما ياخذ اللمّة الثانية بورقة عادية أبداً: يبقى له بس الورق اللي ما يفوز (والصغير)
    legal = legal.filter((c) => E.isJoker(c) || !taking(c));
  }
  // اللمّة الأولى ومعه الصغير وباقي ورقه كله قوي (حكم، أو أكبر ورقة باقية من نوعها، أو ولد وفوق):
  // ممكن ياخذ كل اللمّات ويبقى الافتتاح عنده، فيرمي الصغير الحين بدل ما يقطع
  if (deadlineOpen && !state.madmoon && state.trickNo === 0 && state.trick.length > 0 && hand.includes(E.GREY) && legal.includes(E.GREY)) {
    const known = new Set([...(state.played || []), ...state.trick.map((t) => t.card)]);
    const topOf = (c) => {
      for (let r = E.rankOf(c) + 1; r <= 14; r++) if (!known.has(`${c[0]}-${r}`) && !hand.includes(`${c[0]}-${r}`)) return false;
      return true;
    };
    const rest = hand.filter((c) => !E.isJoker(c));
    if (rest.length && rest.every((c) => c[0] === trump || topOf(c) || E.rankOf(c) >= 11)) return E.GREY;
  }

  // زميله شاري 8 والخصم افتتح بحكم: يمسك الجوكر الصغير لين ينزل آص الحكم
  // (إلا إذا هذي آخر فرصة ينزل فيها الصغير)
  const first = state.trick[0];
  if (first && seat !== state.buyer && E.teamOf(state.buyer) === myTeam && state.currentBid === 8 &&
      E.teamOf(first.seat) !== myTeam && !E.isJoker(first.card) && first.card[0] === trump &&
      !(deadlineOpen && lastChance) && legal.length > 1) {
    const aceOut = [...state.played, ...state.trick.map((t) => t.card)].includes(`${trump}-14`);
    if (!aceOut) legal = legal.filter((c) => c !== E.GREY);
  }

  const ledTrump = !!first && !E.isJoker(first.card) && first.card[0] === trump;
  const seenNow = new Set([...(state.played || []), ...state.trick.map((t) => t.card)]);
  const isTopLeft = (card) => {
    for (let r = E.rankOf(card) + 1; r <= 14; r++) if (!seenNow.has(`${card[0]}-${r}`) && !hand.includes(`${card[0]}-${r}`)) return false;
    return true;
  };
  // خطر يخيس الجوكر إذا مسكه الحين؟
  // الكبير: باقي ورقه كلها أكبر أوراق موجودة، أو كله حكم (ولو معه ورقة أو ورقتين كبار من نوع ثاني):
  // بياخذ كل لمّة ويبقى الافتتاح عنده لين يبقى معه الكبير بس،
  // أو باقي ورقتين والثانية تاخذ هاللمّة (قبل الأخيرة).
  // الصغير: لازم ينزل بأول 3 لمّات، وإذا أخذ هاللمّة بيفتتح اللي بعدها (والصغير ما يفتتح)
  const others = hand.filter((c) => !E.isJoker(c));
  // ورقة «كبيرة» من غير الحكم (ممكن تفوز بلمّتها): أكبر ورقة باقية من نوعها، أو ولد وفوق
  const side = others.filter((c) => c[0] !== trump);
  const bigSide = side.every((c) => isTopLeft(c) || E.rankOf(c) >= 11);
  const blueRisk = hand.includes(E.BLUE) && (
    (others.length > 0 && others.every(isTopLeft)) ||
    // أي شك إن باقي ورقه يفوز بكل اللمّات (كله حكم أو ورق كبير): ممكن كل الافتتاحيات تصير عنده
    (others.length > 0 && bigSide) ||
    (hand.length === 2 && state.trick.length > 0 && others.length === 1 && E.trickWinner([...state.trick, { seat, card: others[0] }], trump) === seat));
  const greyRisk = hand.includes(E.GREY) && deadlineOpen && state.trickNo >= 1;
  // ما يرمي الكبير فوق صغير زميله
  if (state.trick.some((t) => t.card === E.GREY && t.seat !== seat && E.teamOf(t.seat) === myTeam) && legal.some((c) => c !== E.BLUE)) {
    legal = legal.filter((c) => c !== E.BLUE);
  }
  if (ledTrump && !blueRisk && !greyRisk) {
    // الافتتاح بحكم وعنده أكبر حكم باقي (ومعه جوكر): يرمي الحكم ويخلي الجوكر
    const myTop = legal.filter((c) => !E.isJoker(c) && c[0] === trump).sort((a, b) => E.rankOf(b) - E.rankOf(a))[0];
    if (myTop && hand.some(E.isJoker) && isTopLeft(myTop) && E.trickWinner([...state.trick, { seat, card: myTop }], trump) === seat) return myTop;
  }
  if (ledTrump && mateWinning) {
    // الافتتاح بحكم وزميله رمى أكبر حكم باقي: ما يرمي جوكر (إلا إذا بيخيسه)
    const w = E.trickWinner(state.trick, trump);
    const winCard = state.trick.find((t) => t.seat === w).card;
    if (!E.isJoker(winCard) && winCard[0] === trump && isTopLeft(winCard)) {
      const keep = legal.filter((c) => (c !== E.BLUE || blueRisk) && (c !== E.GREY || (deadlineOpen && lastChance)));
      if (keep.length) legal = keep;
    }
  }

  // الكبير ما يفتتح: إذا خلاه لآخر ورقة والافتتاح عنده يخيسه ويخسر المباراة.
  // ينلعب طبيعي، وما يضطر يرميه إلا إذا فيه خطر يخيسه (blueRisk فوق)
  if (blueRisk && legal.includes(E.BLUE) && state.trick.length > 0 && !E.blueLosesMatch(state, seat)) return E.BLUE;
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
    // زميله أشّر على نوع باللمّة اللي قبل (والافتتاح الحين عنده): يفتتح بأول نوع أشّر عليه (وعنده منه ورق).
    // إذا معه أكبر ورقة باقية من النوع يرميها، وإلا أصغر ورقة منه
    // معه الكبير وقربت النهاية والافتتاح عنده: أضعف ورقة، عشان يطلع الافتتاح من عنده ويقدر يرمي الكبير
    if (hand.includes(E.BLUE) && hand.length <= 5) return lowest(nonTrumps.length ? nonTrumps : plain, trump);
    // معه الصغير ويفتتح اللمّة الثانية: ورقة ما تاخذ اللمّة، عشان ما يبقى الافتتاح عنده ويخيس الصغير (الصغير ما يفتتح).
    // أصغر ورقة من غير الحكم إذا هي صغيرة (لين 10)، وإلا أصغر حكم (مثلاً كل ورقه حكم وعنده ورقة كبيرة من نوع ثاني)
    if (state.trickNo === 1 && deadlineOpen && hand.includes(E.GREY)) {
      const smallSide = nonTrumps.filter((c) => E.rankOf(c) <= 10);
      if (smallSide.length) return lowest(smallSide, trump);
      if (trumps.length) return lowest(trumps, trump);
      return lowest(plain, trump);
    }
    const mateSignals = (state.suitSignals || []).filter((x) => x.seat !== seat && E.teamOf(x.seat) === myTeam && x.trick === state.trickNo - 1);
    for (const sig of mateSignals) {
      const ofSuit = plain.filter((c) => c[0] === sig.suit);
      if (!ofSuit.length) continue;
      const top = highest(ofSuit, trump);
      const gone = new Set(state.played || []);
      let isTopLeft = true;
      for (let r = E.rankOf(top) + 1; r <= 14; r++) if (!gone.has(`${sig.suit}-${r}`)) isTopLeft = false;
      return isTopLeft ? top : lowest(ofSuit, trump);
    }
    const thirdBeforeGrey = state.trickNo === 2 && !state.greyPlayed;
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

  // عنده أكبر ورقة باقية من النوع المنزول وتغلب: يرميها، إلا إذا زميله رمى قبله الورقة الملاصقة لها
  // (أقرب ورقة تحتها، وكل اللي بينهم نزل أو عنده): نفس القوة، فيخليها لزميله
  if (same.length) {
    const top = highest(same, trump);
    const adjacent = (a, b) => {
      const [lo, hi] = [E.rankOf(a), E.rankOf(b)].sort((x, y) => x - y);
      for (let r = lo + 1; r < hi; r++) if (!seenNow.has(`${a[0]}-${r}`) && !hand.includes(`${a[0]}-${r}`)) return false;
      return true;
    };
    const mateNext = state.trick.some((t) => t.seat !== seat && E.teamOf(t.seat) === myTeam && !E.isJoker(t.card) && t.card[0] === top[0] && adjacent(t.card, top));
    // (ومعه الصغير قبل ما ينزل باللمّة الثانية وفوق: ما ياخذ، لو أخذ بيفتتح ويخيس الصغير)
    if (isTopLeft(top) && wins(top) && !mateNext && !greyRisk) return top;
  }

  // آخر واحد من فريقه باللمّة وورق فريقه ما يفوز: يرمي أصغر ورقة تغلب، وإلا الجوكر
  const later =Array.from({ length: state.players - 1 - state.trick.length }, (_, i) => (seat + 1 + i) % state.players);
  // يبي ياخذ اللمّة بورقة مو أكبر ورقة باقية من نوعها (ما يعرف الأكبر مع من) وباقي خصم يلعب بعده:
  // إذا معه الكبير ورميه آمن يرميه بدالها، عشان اللمّة تنضمن
  const laterOpp = later.some((s) => E.teamOf(s) !== myTeam);
  const sure = (card) => (!isTopLeft(card) && laterOpp && legal.includes(E.BLUE) && !E.blueLosesMatch(state, seat) && wins(E.BLUE)) ? E.BLUE : card;
  if (!mateWinning && !later.some((s) => E.teamOf(s) === myTeam)) {
    const canWin = plain.filter(wins);
    if (canWin.length) return sure(lowest(canWin, trump));
    const joker = [E.GREY, E.BLUE].find((j) => legal.includes(j) && wins(j));
    if (joker) return joker;
  }

  // زميله صاحب أكبر ورقة باللمّة: يخليها له بس إذا كل الأوراق الأكبر من ورقة زميله عنده هو (أو نزلت)،
  // أو ما بقى أحد يلعب بعده. وإلا ياخذها هو: أكبر ورقة من النوع إذا تغلب، أو أصغر حكم يغلب إذا ما عنده النوع
  if (mateWinning) {
    const w = E.trickWinner(state.trick, trump);
    const mateCard = state.trick.find((t) => t.seat === w).card;
    // ومعه الصغير قبل ما ينزل: ما ياخذ اللمّة (لو أخذها بيفتتح والصغير ما يفتتح فيخيسه)
    // زميله قطع بحكم على نوع مو حكم، والبوت ما عنده النوع: يخليها له وما يقطع فوقه
    const mateRuffed = !E.isJoker(mateCard) && mateCard[0] === trump && led !== trump && !same.length;
    const safe = later.length === 0 || E.isJoker(mateCard) || isTopLeft(mateCard) || mateRuffed || (hand.includes(E.GREY) && deadlineOpen);
    // ورقته «ملاصقة» لورقة زميله (أقرب أكبر أو أصغر، وكل اللي بينهم نزل أو عنده): نفس القوة، فما تفرق
    const nextTo = (c) => {
      if (E.isJoker(c) || E.isJoker(mateCard) || c[0] !== mateCard[0]) return false;
      const [lo, hi] = [E.rankOf(c), E.rankOf(mateCard)].sort((a, b) => a - b);
      for (let r = lo + 1; r < hi; r++) if (!seenNow.has(`${c[0]}-${r}`) && !hand.includes(`${c[0]}-${r}`)) return false;
      return true;
    };
    if (!safe) {
      // ياخذها بورقة أكبر فيها فرق (بينها وبين ورقة زميله ورقة برا)؛ الملاصقة ما تفيد فيخليها لزميله
      const sameWin = same.filter((c) => wins(c) && !nextTo(c));
      if (sameWin.length) return sure(highest(sameWin, trump));
      if (!same.length) {
        const trumpWin = trumps.filter(wins);
        if (trumpWin.length) return lowest(trumpWin, trump);
      }
    }
    // يخليها لزميله بأصغر ورقة، وما يرمي الملاصقة لورقة زميله إذا عنده غيرها
    const pool = same.length ? same : (nonTrumps.length ? nonTrumps : plain);
    const notNext = pool.filter((c) => !nextTo(c));
    return lowest(notNext.length ? notNext : pool, trump);
  }

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
