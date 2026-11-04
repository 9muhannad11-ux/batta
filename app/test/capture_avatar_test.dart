// معاينة الشخصيات: كل الشخصيات كبيرة بأسمائها، وتحتها بحجم اللعبة على لون الفريقين.
// flutter test test/capture_avatar_test.dart  -> build/preview_avatar.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/avatars.dart';
import 'package:kout/cards.dart';

const _chars = [
  ('buhamdan', 'بو حمدان'),
  ('wadamtih', 'ود عمتيه'),
  ('khalfan', 'خلفان التفق'),
  ('khusaib', 'خصيب'),
  ('marhoon', 'مرهون'),
  ('musabbah', 'مصبّح'),
  ('bodhirs', 'محمد بو ضرس'),
  ('abdo', 'عبدو اليابس'),
  ('aslam', 'أسلم'),
  ('mundaghit', 'المنضغط'),
  ('fares', 'فارس'),
];

void main() {
  // معاينة حركة الفم: 11 صورة لفتحة الفم (0..1) لكل شخصية لها صوت، تستخدمها tools/voices/lipsync.html
  testWidgets('mouth frames', (tester) async {
    tester.view.physicalSize = const Size(300, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final id in ['wadamtih', 'aslam']) {
      for (var i = 0; i <= 10; i++) {
        await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('m'),
          child: Container(
            color: const Color(0xFFBDAE8D),
            alignment: const Alignment(0, 0.5),
            child: CharacterAvatar(charId: id, size: 220, ring: KoutColors.teamBlue, background: KoutColors.teamBlue, mouth: i / 10),
          ),
        ));
        await tester.runAsync(() async {
          final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('m')));
          final img = await ro.toImage(pixelRatio: 1);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('../tools/voices/mouth_${id}_$i.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });

  testWidgets('single character, big', (tester) async {
    tester.view.physicalSize = const Size(460, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('one'),
      child: Container(
        color: const Color(0xFFBDAE8D),
        alignment: const Alignment(0, 0.7),
        child: const CharacterAvatar(charId: 'fares', size: 340, ring: KoutColors.teamBlue, background: KoutColors.teamBlue),
      ),
    ));
    await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
      final img = await ro.toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview_one.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });

  testWidgets('avatar preview', (tester) async {
    final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
    await tester.runAsync(f.load);
    tester.view.physicalSize = const Size(1290, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget big(String id, String name, int i) => SizedBox(
          width: 196,
          child: Column(children: [
            CharacterAvatar(
                charId: id,
                size: 170,
                ring: i.isEven ? KoutColors.teamBlue : KoutColors.teamYellow,
                background: i.isEven ? KoutColors.teamBlue : KoutColors.teamYellow),
            Text(name, style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 18, color: Color(0xFF2A2420))),
          ]),
        );
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('shot'),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: const Color(0xFFBDAE8D),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 50),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (var i = 0; i < 6; i++) big(_chars[i].$1, _chars[i].$2, i)]),
            const SizedBox(height: 58),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (var i = 6; i < 11; i++) big(_chars[i].$1, _chars[i].$2, i)]),
            const SizedBox(height: 34),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 11; i++)
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CharacterAvatar(
                      charId: _chars[i].$1,
                      size: 60,
                      ring: i.isEven ? KoutColors.teamBlue : KoutColors.teamYellow,
                      background: i.isEven ? KoutColors.teamBlue : KoutColors.teamYellow),
                ),
            ]),
          ]),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final img = await ro.toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview_avatar.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
