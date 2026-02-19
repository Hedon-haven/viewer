import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool handleEscape(KeyEvent event, GlobalKey<NavigatorState> navigatorKey) {
  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
    navigatorKey.currentState?.maybePop();
    return true;
  }
  return false;
}
