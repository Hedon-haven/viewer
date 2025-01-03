import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '/main.dart';

class ToastMessageShower {
  static void showToast(String message, BuildContext context,
      [int showDuration = 2]) {
    logger.i("Showing toast with message: $message");

    // TODO: Get rid of white border color
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.simple,
      title: Text(message),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: Duration(seconds: showDuration),
      animationDuration: const Duration(milliseconds: 500),
      borderRadius: BorderRadius.circular(100.0),
      closeButtonShowType: CloseButtonShowType.none,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // background
      foregroundColor: Theme.of(context).colorScheme.primary, // text
    );
  }
}
