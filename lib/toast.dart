import 'package:flutter/material.dart';

/// One place for the little message at the bottom ("Milk added to Eat me first").
/// It lives above all screens, so it keeps showing when the screen changes.
final rootMessenger = GlobalKey<ScaffoldMessengerState>();

void toast(String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = rootMessenger.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      persist: false, // a snackbar with an action otherwise stays until dismissed
      duration: Duration(seconds: actionLabel == null ? 3 : 5),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
