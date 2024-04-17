import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastMessageShower {
  static void showToast(String message, BuildContext context) {
    print("Showing toast with message: $message");

    // TODO: Get rid of white border color
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.simple,
      title: Text(message),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 500),
      borderRadius: BorderRadius.circular(100.0),
      closeButtonShowType: CloseButtonShowType.none,
      backgroundColor: Theme.of(context).colorScheme.background,
      // background
      foregroundColor: Theme.of(context).colorScheme.primary, // text
    );
  }
}
