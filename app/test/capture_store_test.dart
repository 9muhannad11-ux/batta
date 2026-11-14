// معاينة المتجر والغوازي: flutter test test/capture_store_test.dart -> build/preview_store_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/cards.dart';
import 'package:kout/friends.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/progress.dart';
import 'package:kout/sounds.dart';
import 'package:kout/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends GameClient {
  @override
  Future<void> search(int mode, int score) async {}
}

Future<void> _shot(WidgetTester tester, String out) async {
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    Sfx.muted = true;
    SharedPreferences.setMockInitialValues({});
    final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
    await f.load();
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  });

  test('wallet: stake, win bonus, loss, purchases', () async {
    SharedPreferences.setMockInitialValues({});
    final w = Wallet.instance;
    await w.load();
    expect(w.balance, 1000);
    expect(w.owns('char', 'fares'), true);
    expect(w.owns('char', 'khalfan'), false);
    w.setStake(100);
    w.enterSearch();
    await w.onState(code: '1', phase: 'bidding', winner: null, myTeam: 0);
    expect(w.balance, 900);
    await w.onState(code: '1', phase: 'playing', winner: null, myTeam: 0);
    expect(w.balance, 900); // مرة وحدة بس
    await w.onState(code: '1', phase: 'matchEnd', winner: 0, myTeam: 0);
    expect(w.balance, 1070); // رجع 170
    await w.onState(code: '1', phase: 'bidding', winner: null, myTeam: 0); // مباراة ثانية بنفس الغرفة
    expect(w.balance, 970);
    await w.onLeave(); // طلع بالنص: خسر
    expect(w.balance, 970);
    expect(w.buy(shopItems({}).firstWhere((i) => i.id == 'blue')), true);
    expect(w.balance, 670);
    expect(w.owns('table', 'blue'), true);
    // اليوم الثاني: الهدية تنتظر ضغطة، وما تنستلم مرتين
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await w.load(now: tomorrow);
    expect(w.balance, 670);
    expect(w.giftReady, true);
    expect(await w.claimGift(now: tomorrow), true);
    expect(w.balance, 870);
    expect(await w.claimGift(now: tomorrow), false);
    await w.load(now: tomorrow);
    expect(w.giftReady, false);
  });

  test('progress: stats and challenges', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress.instance;
    await p.load();
    Map<String, dynamic> v(String phase, int round, Map last, {int? winner, List scores = const [0, 0]}) =>
        {'phase': phase, 'round': round, 'lastRound': last, 'winner': winner, 'scores': scores};
    // أنا مقعد 0 (فريق 0): شريت 8 ووصلت
    p.onState(code: '1', view: v('roundEnd', 1, {'type': 'made', 'team': 0, 'points': 8, 'buyer': 0, 'bid': 8}, scores: [8, 0]), mySeat: 0, online: true);
    p.onState(code: '1', view: v('roundEnd', 1, {'type': 'made', 'team': 0, 'points': 8, 'buyer': 0, 'bid': 8}, scores: [8, 0]), mySeat: 0, online: true); // نفس الجولة ما تنحسب مرتين
    expect(p.value('bought'), 1);
    expect(p.value('bigBidMade'), 1);
    expect(p.value('points'), 8);
    // باون وفوز بالمباراة
    p.onState(code: '1', view: v('matchEnd', 2, {'type': 'bawanWin', 'team': 0, 'buyer': 0, 'bid': 9}, winner: 0, scores: [8, 0]), mySeat: 0, online: true);
    expect(p.value('bawanMade'), 1);
    expect(p.value('wins'), 1);
    expect(p.value('matches'), 1);
    final win1 = dailyChallenges.firstWhere((c) => c.id == 'd_win1');
    expect(p.done(win1), true);
    final before = Wallet.instance.balance;
    expect(p.claim(win1), true);
    expect(p.claim(win1), false);
    expect(Wallet.instance.balance, before + 150);
    // التدريب ينحسب بالتاريخ بس، مو بالتحديات
    p.onState(code: '2', view: v('matchEnd', 1, {'type': 'made', 'team': 1, 'points': 6, 'buyer': 1, 'bid': 6}, winner: 1, scores: [0, 6]), mySeat: 0, online: false);
    expect(p.value('losses'), 1);
    expect(p.progress(dailyChallenges.first), 1);
    // يوم جديد: التحديات اليومية من الصفر
    await p.load(now: DateTime.now().add(const Duration(days: 1)));
    expect(p.progress(dailyChallenges.first), 0);
    expect(p.isClaimed(win1), false);
  });

  testWidgets('store screens', (tester) async {
    addTearDown(tester.view.reset);
    for (final (size, name) in const [(Size(390, 844), 'portrait'), (Size(844, 390), 'landscape')]) {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => Wallet.instance.load());
      await tester.runAsync(() => Progress.instance.load());
      // أصدقاء للمعاينة
      Friends.instance.debugSet([
        Friend('K7Q2XM', 'سالم', 'wadamtih'),
        Friend('P3RT8A', 'خالد', 'khusaib'),
        Friend('Z9MN4B', 'عبدالله', 'aslam'),
        Friend('H2WE6C', 'فهد', null),
        Friend('Q8LD5F', 'ناصر', 'marhoon'),
      ], {'K7Q2XM': FriendStatus.online, 'P3RT8A': FriendStatus.playing, 'Z9MN4B': FriendStatus.room}, code: 'B4TT3H');
      Progress.instance.stats.addAll({'matches': 24, 'wins': 15, 'losses': 9, 'rounds': 188, 'bought': 41, 'boughtMade': 30, 'boughtFailed': 11, 'bigBidMade': 6, 'bawanMade': 2, 'bawanFailed': 1, 'bawanBroken': 3, 'points': 612, 'jokerPenalty': 1, 'ghawaziWon': 1340});
      for (var r = 1; r <= 2; r++) {
        Progress.instance.onState(code: 'x', view: {'phase': r == 2 ? 'matchEnd' : 'roundEnd', 'round': r, 'winner': r == 2 ? 0 : null, 'scores': [r, 0], 'lastRound': {'type': 'made', 'team': 0, 'points': 6, 'buyer': 0, 'bid': 6}}, mySeat: 0, online: true);
      }
      Wallet.instance
        ..balance = 1000
        ..owned.clear()
        ..owned.add('table:blue')
        ..table = 'blue'
        ..giftReady = true;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()..name = 'مهند';
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'build/preview_store_${name}_menu.png');
      // الأصدقاء
      await _tap(tester, find.byIcon(Icons.people_alt));
      expect(find.text('3 متصل من 5'), findsOneWidget);
      await _shot(tester, 'build/preview_store_${name}_friends.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      // هدية اليوم: العملات تطير للرصيد
      await _tap(tester, find.text('هدية اليوم'));
      await _shot(tester, 'build/preview_store_${name}_giftfly.png');
      await tester.pump(const Duration(seconds: 1));
      expect(Wallet.instance.balance, 1200);
      await _shot(tester, 'build/preview_store_${name}_gifted.png');
      await _tap(tester, find.text('المتجر'));
      await _shot(tester, 'build/preview_store_${name}_ghawazi.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.text('التفضيلات'));
      await _shot(tester, 'build/preview_store_${name}_prefs.png');
      await _tap(tester, find.text('بو شنب'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'build/preview_store_${name}_focus.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.text('التحديات'));
      await _shot(tester, 'build/preview_store_${name}_challenges.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.text('تاريخك'));
      await _shot(tester, 'build/preview_store_${name}_history.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.text('6 لاعبين'));
      await _tap(tester, find.text('دور كامل'));
      await _shot(tester, 'build/preview_store_${name}_stakes.png');
      // دخول جيم: العملات تطير من الرصيد على الخيار
      await _tap(tester, find.text('تفوز: 272'));
      await _shot(tester, 'build/preview_store_${name}_stakefly.png');
      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      // التدريب: الخيار الثالث «قوانين اللعب»
      await _tap(tester, find.text('تدريب'));
      await _shot(tester, 'build/preview_store_${name}_training.png');
      await _tap(tester, find.text('قوانين اللعب'));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(KoutApp));
        for (final card in ['JB', 'JG', for (var r = 2; r <= 14; r++) 'S-$r']) {
          await precacheImage(cardImage(card), ctx);
        }
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('قوة الأوراق'), findsOneWidget);
      await _shot(tester, 'build/preview_store_${name}_rules.png');
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await _tap(tester, find.byIcon(Icons.arrow_back).first);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      // أول مرة باللعبة: شاشة الاسم
      final fresh = _Client();
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey('fresh$name'), client: fresh)));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'build/preview_store_${name}_account.png');
      await tester.enterText(find.byType(TextField), 'مهند');
      await _tap(tester, find.text('يلا ندخل'));
      expect(fresh.name, 'مهند');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
