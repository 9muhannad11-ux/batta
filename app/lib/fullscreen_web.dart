import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// ملء الشاشة بالمتصفح (Fullscreen API). آيفون Safari ما يدعمه، فالزر ما يطلع هناك.
class Fullscreen {
  static bool _listening = false;

  static bool get supported => web.document.fullscreenEnabled;

  /// يتغير لما يدخل أو يطلع من ملء الشاشة (حتى لو طلع بزر Esc)
  static final ValueNotifier<bool> on = () {
    final n = ValueNotifier(web.document.fullscreenElement != null);
    if (!_listening) {
      _listening = true;
      web.document.addEventListener(
          'fullscreenchange',
          ((web.Event _) {
            n.value = web.document.fullscreenElement != null;
          }).toJS);
    }
    return n;
  }();

  static void toggle() {
    if (web.document.fullscreenElement != null) {
      web.document.exitFullscreen();
    } else {
      web.document.documentElement?.requestFullscreen();
    }
  }
}
