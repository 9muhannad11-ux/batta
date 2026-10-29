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
    expect(find.text('بتّه'), findsOneWidget);
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
    final ace = find.widgetWithText(PlayingCard, 'خال');
    await tester.tap(ace);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, isEmpty);
    await tester.tap(ace);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.played, ['H-14']);
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
    expect(find.text('خسارة'), findsOneWidget);
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
    expect(find.text('وصول'), findsOneWidget);
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
    expect(find.text('مجبور'), findsOneWidget);
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
    expect(find.descendant(of: bar, matching: find.byType(JokerSignalIcon)), findsOneWidget);
    // كل ضغطة ترسل على طول بدون تأكيد
    await tester.tap(find.descendant(of: bar, matching: find.byWidgetPredicate((w) => w is SuitIcon && w.suit == 'H')));
    await tester.pump();
    expect(c.sent, [['H']]);
    await tester.tap(find.descendant(of: bar, matching: find.byWidgetPredicate((w) => w is SuitIcon && w.suit == 'C')));
    await tester.tap(find.descendant(of: bar, matching: find.byType(JokerSignalIcon)));
    await tester.pump();
    expect(c.sent, [['H'], ['C'], ['J']]);

    // السيرفر يرد بالإشارة لكل اللاعبين: تظهر الثلاث مع بعض فوق اللاعب
    c.signals[0] = SuitSignal(0, ['H', 'C', 'J']);
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    final jokers = find.byType(JokerSignalIcon);
    expect(jokers, findsNWidgets(2)); // واحد بالنافذة وواحد فوق اللاعب
  });
}
