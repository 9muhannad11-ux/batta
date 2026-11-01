// معاينة اختيار الشخصية باللوبي: flutter test test/capture_picker_test.dart -> build/preview_picker.png
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

void main() {
  testWidgets('character picker', (tester) async {
    Sfx.muted = true;
    await tester.runAsync(() async {
      final f = FontLoader('ElMessiri')..addFont(rootBundle.load('assets/fonts/ElMessiri-Bold.ttf'));
      await f.load();
      final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = _Client()
      ..connected = true
      ..room = {
        't': 'room', 'code': '4821', 'mode': 6, 'started': false, 'you': 0, 'isHost': true,
        'seats': [
          {'name': 'مهند', 'bot': false, 'connected': true, 'char': 'aslam'},
          {'name': 'سالم', 'bot': false, 'connected': true, 'char': 'marhoon'},
          {'name': 'خصيب', 'bot': true, 'connected': true, 'char': 'khusaib'},
          null, null, null,
        ],
      };
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(client: c)));
    await tester.pump();
    await tester.tap(find.textContaining('(أنت)'));
    for (var i = 0; i < 20; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    expect(find.text('اختر شخصيتك'), findsOneWidget);
    await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final img = await ro.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview_picker.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
