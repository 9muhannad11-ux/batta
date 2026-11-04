// معاينة القائمة الرئيسية واختيار الشخصية والإعدادات: flutter test test/capture_menu_test.dart -> build/preview_menu_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/main.dart';
import 'package:kout/net.dart';
import 'package:kout/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends GameClient {}

Future<void> _shot(WidgetTester tester, String out) async {
  await tester.runAsync(() async {
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await ro.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
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

  testWidgets('menu, character picker and settings', (tester) async {
    addTearDown(tester.view.reset);
    for (final (size, name) in const [(Size(390, 844), 'portrait'), (Size(844, 390), 'landscape')]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final c = _Client()..name = 'مهند';
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: KoutApp(key: ValueKey(name), client: c)));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'build/preview_menu_$name.png');
      await tester.tap(find.text('شخصيتك'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 'build/preview_menu_${name}_picker.png');
      await tester.ensureVisible(find.text('فارس')); // بالعرضي تحتاج تمرير
      await tester.pump();
      await tester.tap(find.text('فارس'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.char, 'fares');
      await _shot(tester, 'build/preview_menu_${name}_chosen.png');
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 'build/preview_menu_${name}_settings.png');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
