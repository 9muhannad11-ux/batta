// صور معاينة لشاشة اللعب (طولي وعرضي) بالخط والأوراق الحقيقية. تشغيل يدوي:
// flutter test test/capture_preview_test.dart  -> build/preview_portrait.png و build/preview_landscape.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/sounds.dart';

class _Client extends GameClient {}

Map<String, dynamic> _view() => {
      'seat': 0, 'players': 6, 'team': 0, 'phase': 'playing', 'round': 2, 'scores': [12, 26], 'khabis': 3, 'turn': 0,
      'hand': ['H-14', 'H-7', 'C-13', 'C-3', 'D-11', 'D-10', 'D-8', 'S-9', 'JB'],
      'handCounts': [9, 8, 8, 8, 9, 9], 'bids': [], 'currentBid': 6, 'buyer': 3, 'majbur': false, 'trump': 'D',
      'madmoon': false, 'bluePlayed': false, 'bawan': false,
      'trick': [{'seat': 1, 'card': 'C-14'}, {'seat': 2, 'card': 'C-9'}, {'seat': 3, 'card': 'D-13'}, {'seat': 4, 'card': 'C-10'}, {'seat': 5, 'card': 'C-2'}],
      'trickNo': 3, 'tricksWon': [1, 2], 'greyPlayed': true, 'lastTrick': null, 'lastRound': null, 'winner': null, 'winReason': null,
      'legalBids': [], 'legalCards': ['C-13', 'C-3'], 'blueLoses': false, 'canSignal': true, 'canSignalJoker': true, 'hasJoker': true,
      'bawanOffer': false, 'turnMsLeft': 8000,
    };

/// result: 'made' أو 'failed' يصوّر لحظة نهاية الجولة (الطاولة خضراء/حمراء)
Future<void> _capture(WidgetTester tester, Size size, String out, {String? result}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  final c = _Client()
    ..connected = true
    ..room = {
      't': 'room', 'code': '1234', 'mode': 6, 'started': true, 'you': 0, 'isHost': true,
      'seats': [
        for (final (n, ch) in [('مهند', 'musabbah'), ('خصيب', 'khusaib'), ('مرهون', 'marhoon'), ('بو حمدان', 'buhamdan'), ('خلفان التفق', 'khalfan'), ('ود عمتيه', 'wadamtih')])
          {'name': n, 'bot': n != 'مهند', 'connected': true, 'char': ch},
      ],
    }
    ..view = _view();
  await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(client: c)));
  await tester.pump(const Duration(milliseconds: 600));
  // الصور تنقرى من الملفات خارج الوقت الوهمي
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(KoutApp));
    for (final card in [..._view()['hand'] as List, 'C-14', 'C-9', 'D-13', 'C-10', 'C-2']) {
      await precacheImage(AssetImage('assets/cards/$card.png'), ctx);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
  if (result != null) {
    c.view = _view()
      ..['phase'] = 'roundEnd'
      ..['trick'] = []
      ..['legalCards'] = []
      ..['canSignal'] = false
      ..['lastRound'] = {'type': result, 'team': 1, 'points': 6, 'buyer': 3, 'bid': 6, 'majbur': false, 'tricksWon': [3, 6]};
    c.notifyListeners();
    // الأنميشن يبدأ بأول فريم، وبعدها نروح لوسط التأثير
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 700));
  }
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    Sfx.muted = true;
    final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
    await f.load();
  });

  testWidgets('portrait preview', (tester) async {
    addTearDown(tester.view.reset);
    await _capture(tester, const Size(390, 844), 'build/preview_portrait.png');
  });

  testWidgets('landscape preview', (tester) async {
    addTearDown(tester.view.reset);
    await _capture(tester, const Size(844, 390), 'build/preview_landscape.png');
  });

  testWidgets('win / lose table flash', (tester) async {
    addTearDown(tester.view.reset);
    await _capture(tester, const Size(390, 844), 'build/preview_win.png', result: 'made');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox()); // شاشة جديدة للصورة الثانية
    await _capture(tester, const Size(390, 844), 'build/preview_lose.png', result: 'failed');
    await tester.pump(const Duration(seconds: 3));
  });
}
