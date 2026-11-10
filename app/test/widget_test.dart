import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/avatars.dart';
import 'package:kout/cards.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/sounds.dart';

/// عميل وهمي: ما يتصل بسيرفر، بس يسجّل الأوامر.
class FakeClient extends GameClient {
  final sent = <List<String>>[];
  final played = <String>[];
  @override
  void signal(List<String> suits) => sent.add(suits);
  @override
  void play(String card) => played.add(card);
}

Map<String, dynamic> playingView({List<String>? hand, List<String>? legal, bool hasJoker = false}) => {
      'seat': 0,
      'players': 4,
      'team': 0,
      'phase': 'playing',
      'round': 1,
      'scores': [12, 7],
      'khabis': 3,
      'turn': 0,
      'hand': hand ?? ['H-14', 'C-9', 'S-2'],
      'handCounts': [3, 3, 3, 3],
      'bids': [],
      'currentBid': 7,
      'buyer': 1,
      'majbur': false,
      'trump': 'S',
      'madmoon': false,
      'bluePlayed': false,
      'bawan': false,
      'trick': [],
      'trickNo': 0,
      'tricksWon': [0, 0],
      'greyPlayed': false,
      'lastTrick': null,
      'lastRound': null,
      'winner': null,
      'winReason': null,
      'legalBids': [],
      'legalCards': legal ?? ['H-14', 'C-9', 'S-2'],
      'blueLoses': false,
      'canSignal': true,
      'canSignalJoker': hasJoker,
      'hasJoker': hasJoker,
      'bawanOffer': false,
      'turnMsLeft': null,
    };

FakeClient tableClient(Map<String, dynamic> view) {
  final c = FakeClient();
  c.connected = true;
  c.room = {
    't': 'room',
    'code': '1234',
    'mode': 4,
    'started': true,
    'you': 0,
    'isHost': true,
    'seats': [
      {'name': 'أنا', 'bot': false, 'connected': true, 'char': 'musabbah'},
      {'name': 'خصيب', 'bot': true, 'connected': true, 'char': 'khusaib'},
      {'name': 'مرهون', 'bot': true, 'connected': true, 'char': 'marhoon'},
      {'name': 'المنضغط', 'bot': true, 'connected': true, 'char': 'mundaghit'}, // بدون أصوات
    ],
  };
  c.view = view;
  return c;
}

void main() {
  setUp(() => Sfx.muted = true);

  testWidgets('second match after a rematch still plays the match-end voices', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Sfx.voiceLog.clear();
    final c = tableClient(playingView());
    (c.room!['seats'] as List)[2] = {'name': 'ود عمتيه', 'bot': true, 'connected': true, 'char': 'wadamtih'};
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    Future<void> show(Map<String, dynamic> v) async {
      c.view = v;
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Map<String, dynamic> ended(int round, {int team = 0, String type = 'made', bool match = false}) => playingView()
      ..['round'] = round
      ..['phase'] = match ? 'matchEnd' : 'roundEnd'
      ..['winner'] = match ? team : null
      ..['winReason'] = match ? (type.startsWith('bawan') ? type : 'score') : null
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['lastRound'] = {'type': type, 'team': team, 'points': 7, 'buyer': team == 0 ? 0 : 1, 'bid': 7, 'majbur': false, 'tricksWon': [7, 2]};
    Map<String, dynamic> dealing(int round) => playingView()
      ..['round'] = round
      ..['phase'] = 'bidding'
      ..['currentBid'] = 0
      ..['buyer'] = null
      ..['trump'] = null
      ..['legalCards'] = []
      ..['canSignal'] = false;

    for (final (label, lastRound) in const [('ends in round 2', 2), ('ends in round 1', 1), ('ends in round 1 again', 1)]) {
      // المباراة: جولات لين الأخيرة، وبعدها «مباراة جديدة»
      for (var r = 1; r < lastRound; r++) {
        await show(dealing(r));
        await show(playingView()..['round'] = r);
        await show(ended(r));
        await tester.pump(const Duration(seconds: 3));
      }
      if (lastRound > 1) await show(dealing(lastRound));
      await show(playingView()..['round'] = lastRound);
      Sfx.voiceLog.clear();
      await show(ended(lastRound, match: true));
      expect(Sfx.voiceLog, ['musabbah_5', 'wadamtih_5'], reason: label);
      await tester.pump(const Duration(seconds: 3));
      await show(dealing(1)); // مباراة جديدة
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('character voices: bids, gold table, reaching the bid, big joker over small', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Sfx.voiceLog.clear();
    final bidding = playingView()
      ..['phase'] = 'bidding'
      ..['currentBid'] = 0
      ..['buyer'] = null
      ..['trump'] = null
      ..['legalCards'] = []
      ..['canSignal'] = false;
    final c = tableClient(bidding);
    (c.room!['seats'] as List)[2] = {'name': 'ود عمتيه', 'bot': true, 'connected': true, 'char': 'wadamtih'};
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    // مقعد 2 (ود عمتيه) يزايد 7 وبعدين واحد ثاني يطوف (ما له صوت)
    c.view = Map.of(bidding)..['bids'] = [{'seat': 2, 'bid': 7}, {'seat': 3, 'bid': 'pass'}];
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(Sfx.voiceLog, ['wadamtih_2']);
    // يطوف بجولة ثانية
    c.view = Map.of(bidding)..['bids'] = [{'seat': 2, 'bid': 7}, {'seat': 3, 'bid': 'pass'}, {'seat': 2, 'bid': 'pass'}];
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(Sfx.voiceLog.last, 'wadamtih_7');
    // اللعب: الكبير فوق الصغير من ود عمتيه
    c.view = playingView()
      ..['buyer'] = 2
      ..['trick'] = [{'seat': 1, 'card': 'JG'}, {'seat': 2, 'card': 'JB'}];
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(Sfx.voiceLog.last, 'wadamtih_9');
    // الشاري ود عمتيه يوصل
    c.view = playingView()
      ..['phase'] = 'roundEnd'
      ..['buyer'] = 2
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['lastRound'] = {'type': 'made', 'team': 0, 'points': 7, 'buyer': 2, 'bid': 7, 'majbur': false, 'tricksWon': [7, 2]};
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(Sfx.voiceLog.last, 'wadamtih_5');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('bawan win or bawan fail: the winning team says 6; match win: the winning team says 5', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final char in ['musabbah', 'khusaib', 'marhoon']) {
      Sfx.voices[char] = {5, 6};
      addTearDown(() => Sfx.voices.remove(char));
    }
    Sfx.voiceLog.clear();
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    Future<void> result(int round, String type, {int team = 1, int? winner}) async {
      c.view = playingView()..['round'] = round;
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
      c.view = playingView()
        ..['round'] = round
        ..['phase'] = 'roundEnd'
        ..['trick'] = []
        ..['legalCards'] = []
        ..['canSignal'] = false
        ..['winner'] = winner
        ..['lastRound'] = {'type': type, 'team': team, 'points': 54, 'buyer': 1, 'bid': 9, 'majbur': false, 'tricksWon': [0, 9]};
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await result(2, 'bawanWin', winner: 1); // فريق الشاري: مقعد 1 و3 (مقعد 3 بدون أصوات)
    expect(Sfx.voiceLog, ['khusaib_6']);
    Sfx.voiceLog.clear();
    await result(3, 'bawanFail', team: 0, winner: 0); // الشاري مقعد 1، والمنافس مقعد 0 و2
    expect(Sfx.voiceLog, ['musabbah_6', 'marhoon_6']);
    Sfx.voiceLog.clear();
    await result(4, 'made', team: 0, winner: 0); // فوز بالمباراة: كل الفريق الفايز 5
    expect(Sfx.voiceLog, ['musabbah_5', 'marhoon_5']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('character voice when the buyer chooses trump (10-13)', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final old = Sfx.voices['wadamtih']!;
    Sfx.voices['wadamtih'] = {...old, 10, 11, 12, 13};
    addTearDown(() => Sfx.voices['wadamtih'] = old);
    Sfx.voiceLog.clear();
    final choosing = playingView()
      ..['phase'] = 'trump'
      ..['buyer'] = 2
      ..['trump'] = null
      ..['trick'] = []
      ..['legalCards'] = []
      ..['canSignal'] = false;
    final c = tableClient(choosing);
    (c.room!['seats'] as List)[2] = {'name': 'ود عمتيه', 'bot': true, 'connected': true, 'char': 'wadamtih'};
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    for (final (suit, ev) in [('S', 10), ('D', 11), ('C', 12), ('H', 13)]) {
      // جولة جديدة لكل نوع: الشاري يختار، والصوت مرة وحدة بس
      final round = ev;
      c.view = Map.of(choosing)..['round'] = round;
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
      c.view = Map.of(choosing)
        ..['round'] = round
        ..['phase'] = 'playing'
        ..['trump'] = suit;
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
      c.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));
      expect(Sfx.voiceLog.where((e) => e == 'wadamtih_$ev').length, 1, reason: suit);
    }
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('home screen shows create and join', (tester) async {
    await tester.pumpWidget(KoutApp(client: GameClient()));
    expect(find.byType(AppLogo), findsOneWidget);
    for (final t in ['6 لاعبين', '4 لاعبين', 'غرفة مخصصة', 'تدريب']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('من 34 نقطة'), findsNothing);
    await tester.tap(find.text('6 لاعبين'));
    await tester.pump();
    expect(find.text('من 54 نقطة'), findsOneWidget);
    expect(find.text('من 34 نقطة'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // انتقال الصفحة
    await tester.tap(find.text('غرفة مخصصة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('سوّ غرفة جديدة'), findsOneWidget);
    expect(find.text('ادخل'), findsOneWidget);
  });

  testWidgets('table: faces, team scores, bot markers, round info', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CharacterAvatar), findsNWidgets(4));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // النتيجة + عدد المزايدة بالوسط
    expect(find.byIcon(Icons.smart_toy), findsNWidgets(3));
    expect(find.text('بوت'), findsNothing);
    expect(find.text('خصيب'), findsWidgets);
  });

  testWidgets('tap once selects a card, tap again throws it', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 500));
    final ace = find.byKey(const ValueKey('hand-H-14'));
    await tester.tapAt(tester.getTopLeft(ace) + const Offset(12, 30)); // الجزء الظاهر من الورقة
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, isEmpty);
    await tester.tapAt(tester.getTopLeft(ace) + const Offset(12, 30)); // الجزء الظاهر من الورقة
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, ['H-14']);
  });

  testWidgets('drag: past the line throws, short drag raises, illegal card does not throw', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView(legal: ['H-14', 'C-9']));
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 500));
    // سحب قصير: ترجع لليد مرفوعة وما تنرمى
    await tester.dragFrom(tester.getTopLeft(find.byKey(const ValueKey('hand-C-9'))) + const Offset(12, 30), const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, isEmpty);
    // الممنوعة ما تنرمى حتى لو انسحبت لفوق
    await tester.dragFrom(tester.getTopLeft(find.byKey(const ValueKey('hand-S-2'))) + const Offset(30, 30), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.played, isEmpty);
    // فوق الحد: تنرمى
    await tester.dragFrom(tester.getTopLeft(find.byKey(const ValueKey('hand-H-14'))) + const Offset(12, 30), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, ['H-14']);
  });

  testWidgets('bid window: «كم تروح؟» with 9 8 7 6 طاف, illegal numbers stay but do nothing', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView()
      ..['phase'] = 'bidding'
      ..['currentBid'] = 7
      ..['trump'] = null
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['bids'] = [{'seat': 1, 'bid': 7}]
      ..['legalBids'] = ['pass', 8, 9]);
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('كم تروح؟'), findsOneWidget);
    for (final t in ['9', '8', '6', 'طاف']) {
      expect(find.text(t), findsWidgets);
    }
    final x = [for (final t in ['9', '8', '6', 'طاف']) tester.getCenter(find.text(t).last).dx];
    expect(x, orderedEquals([...x]..sort())); // من اليسار: 9، 8، 7، 6، طاف
  });

  testWidgets('big joker signal: no J bubble, the next card gets the palm', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView()..['turn'] = 2);
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    c.slapPending.add(2);
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GoldJ), findsNothing);
    c.view = playingView()
      ..['turn'] = 3
      ..['trick'] = [{'seat': 2, 'card': 'D-5'}];
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PalmPainter'), findsOneWidget);
    expect(c.slapPending, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PalmPainter'), findsNothing);
  });

  testWidgets('round end: red effect when buyer fails, green when made', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v = playingView()
      ..['phase'] = 'roundEnd'
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['lastRound'] = {'type': 'failed', 'team': 0, 'points': 14, 'buyer': 1, 'bid': 7, 'majbur': false, 'tricksWon': [3, 3]};
    // نبدأ والجولة شغّالة، بعدين تخلص (مثل اللعب الحقيقي)
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    c.view = v;
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('خسارة'), findsWidgets); // مرتين: الكلمة وحدها الأسود
    expect(find.text('خصيب ما جاب 7'), findsOneWidget);
    expect(find.text('+14 للفريق الأزرق'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('خسارة'), findsNothing);

    // جولة جديدة تتوزع، وبعدين تخلص والشاري جابها
    c.view = playingView()
      ..['round'] = 2
      ..['phase'] = 'bidding'
      ..['trump'] = null;
    c.notifyListeners();
    await tester.pump(const Duration(seconds: 2));
    c.view = Map.of(v)
      ..['round'] = 2
      ..['lastRound'] = {'type': 'made', 'team': 1, 'points': 7, 'buyer': 1, 'bid': 7, 'majbur': false, 'tricksWon': [2, 7]};
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('وصول'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the leftmost tilted card can be tapped on the part you can see (landscape)', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hand = ['H-14', 'H-7', 'C-13', 'C-3', 'D-11', 'D-10', 'D-8', 'S-9', 'S-2'];
    final c = tableClient(playingView(hand: hand, legal: hand));
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 600));
    // الزاوية اليسار فوق من الورقة المايلة، وهي الجزء الظاهر منها
    final box = tester.renderObject<RenderBox>(find.byWidgetPredicate((w) => w is PlayingCard && w.card == 'H-14'));
    await tester.tapAt(box.localToGlobal(const Offset(8, 14)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<PlayingCard>(find.byWidgetPredicate((w) => w is PlayingCard && w.card == 'H-14')).highlight, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('hand stays face down until my bid turn, and again after it until play', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic> stage(String phase, {List<Object> bids = const [], int? buyer}) => playingView()
      ..['phase'] = phase
      ..['trick'] = []
      ..['trump'] = null
      ..['buyer'] = buyer
      ..['currentBid'] = 6
      ..['legalCards'] = []
      ..['legalBids'] = bids;
    int faceUp() => tester.widgetList<PlayingCard>(find.byType(PlayingCard)).where((p) => p.card != 'back').length;
    final c = tableClient(stage('bidding'));
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 100)); // يبدأ التوزيع
    await tester.pump(const Duration(seconds: 3));
    expect(faceUp(), 0);

    Future<void> go(Map<String, dynamic> v) async {
      c.view = v;
      c.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await go(stage('bidding', bids: ['pass', 7, 8, 9])); // دوري
    expect(faceUp(), 3);
    await go(stage('bidding')); // خلص دوري
    expect(faceUp(), 0);
    await go(stage('trump', buyer: 2)); // غيري يختار الحكم
    expect(faceUp(), 0);
    await go(stage('trump', buyer: 0)); // أنا أختار الحكم
    expect(faceUp(), 3);
    await go(playingView()); // بدأ اللعب
    expect(faceUp(), greaterThanOrEqualTo(3));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('khabis sees «6 مجبور» instead of pass, and the forced buyer is labelled «مجبور» for everyone', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView()
      ..['phase'] = 'bidding'
      ..['khabis'] = 0
      ..['currentBid'] = 0
      ..['buyer'] = null
      ..['trump'] = null
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['legalBids'] = ['majbur', 6, 7, 8, 9]);
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 100)); // يبدأ التوزيع
    await tester.pump(const Duration(seconds: 3)); // يخلص التوزيع وتطلع نافذة المزايدة
    expect(find.text('6 مجبور'), findsOneWidget);
    expect(find.text('طاف'), findsNothing);

    c.view = playingView()
      ..['buyer'] = 1
      ..['majbur'] = true;
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('مجبور'), findsNWidgets(2)); // مرتين: الكلمة وحدها الأسود
  });

  testWidgets('grey penalty names the player who held the small joker', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    c.view = playingView()
      ..['phase'] = 'roundEnd'
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['lastRound'] = {'type': 'greyPenalty', 'team': 0, 'points': 15, 'buyer': 1, 'bid': 6, 'majbur': false, 'offender': 2, 'tricksWon': [2, 1]};
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('مرهون خيّس الجوكر الصغير'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('match end shows winner, score and reason; bawan shows big gold word', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v = playingView()
      ..['phase'] = 'matchEnd'
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['scores'] = [20, 31]
      ..['winner'] = 1
      ..['winReason'] = 'bawanWin'
      ..['lastRound'] = {'type': 'bawanWin', 'team': 1, 'buyer': 1, 'bid': 9, 'majbur': false, 'tricksWon': [0, 9]};
    final c = tableClient(playingView());
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 400));
    c.view = v;
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('باون'), findsWidgets);
    expect(find.text('فاز الفريق الأصفر'), findsOneWidget);
    expect(find.text('سبب الفوز'), findsOneWidget);
    expect(find.text('باون: خصيب جاب كل اللمّات'), findsOneWidget);
    expect(find.text('مباراة جديدة'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('signals: pick several (and joker), send once, shown together', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = tableClient(playingView(hasJoker: true, hand: ['JG', 'H-14', 'C-9'], legal: ['JG', 'H-14', 'C-9']));
    await tester.pumpWidget(KoutApp(client: c));
    await tester.pump(const Duration(milliseconds: 500));

    final bar = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SignalBar');
    expect(find.descendant(of: bar, matching: find.byType(GoldJ)), findsOneWidget);
    // كل ضغطة ترسل على طول بدون تأكيد
    await tester.tap(find.descendant(of: bar, matching: find.byWidgetPredicate((w) => w is SuitIcon && w.suit == 'H')));
    await tester.pump();
    expect(c.sent, [['H']]);
    await tester.tap(find.descendant(of: bar, matching: find.byWidgetPredicate((w) => w is SuitIcon && w.suit == 'C')));
    await tester.tap(find.descendant(of: bar, matching: find.byType(GoldJ)));
    await tester.pump();
    expect(c.sent, [['H'], ['C'], ['J']]);

    // السيرفر يرد بالإشارة لكل اللاعبين: تظهر الثلاث مع بعض فوق اللاعب
    c.signals[0] = SuitSignal(0, ['H', 'C', 'J']);
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    final jokers = find.byType(GoldJ);
    expect(jokers, findsNWidgets(2)); // واحد بالنافذة وواحد فوق اللاعب
  });
}
