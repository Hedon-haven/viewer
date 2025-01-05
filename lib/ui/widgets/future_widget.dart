import 'package:flutter/material.dart';

class FutureWidget<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T?) finalWidgetBuilder;

  const FutureWidget({
    super.key,
    required this.future,
    required this.finalWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // If data is not available yet, return nothing
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        return finalWidgetBuilder(context, snapshot.data);
      },
    );
  }
}
