import 'package:flutter/material.dart';

class OverlayWidget extends StatelessWidget {
  final Widget child;
  bool showControls;

  OverlayWidget({
    Key? key,
    required this.child,
    required this.showControls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !showControls,
      child: AnimatedOpacity(
        opacity: showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: child,
      ),
    );
  }
}
