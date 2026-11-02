// معاينة ظهر الورقة (التوزيع): flutter test test/capture_back_test.dart -> build/preview_back.png
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kout/cards.dart';

void main() {
  testWidgets('card back', (tester) async {
    tester.view.physicalSize = const Size(620, 300) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('b'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFFBFC2C6),
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const CardBack(width: 160),
            const SizedBox(width: 30),
            const CardBack(width: 70),
            const SizedBox(width: 30),
            // مثل لحظة التوزيع: أوراق طايرة بزوايا مختلفة
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(children: [
                for (var i = 0; i < 6; i++)
                  Positioned(
                    left: 20.0 + i * 28,
                    top: 40.0 + (i % 2) * 30,
                    child: Transform.rotate(angle: (i - 2.5) * pi / 9, child: const CardBack(width: 56)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('b')));
      final img = await ro.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview_back.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
