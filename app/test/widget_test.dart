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
      {'name': 'صديق', 'bot': true, 'connected': true, 'char': 'sadiq'},
    ],
  };
  c.view = view;
  return c;
}

void main() {
  setUp(() => Sfx.muted = true);

  testWidgets('home screen shows create and join', (tester) async {
    await tester.pumpWidget(KoutApp(client: GameClient()));
    expect(find.byType(AppLogo), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 2)); // يخلص التوزيع وتطلع نافذة المزايدة
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
