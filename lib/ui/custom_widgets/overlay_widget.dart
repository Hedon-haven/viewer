import 'package:flutter/material.dart';

class OverlayWidget extends StatelessWidget {
  final Widget child;
  bool showControls;

  OverlayWidget({
    super.key,
    required this.child,
    required this.showControls,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // TODO: Wait for animation to finish before ignoring touch input
      ignoring: !showControls,
      child: AnimatedOpacity(
        opacity: showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: child,
      ),
    );
  }
}
