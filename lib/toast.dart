import 'package:flutter/material.dart';
import 'theme.dart';

/// One place for the little message at the bottom ("Milk added to Eat me first").
/// It lives above all screens, so it keeps showing when the screen changes.
/// Brand look: a lime pill with dark text.
final rootMessenger = GlobalKey<ScaffoldMessengerState>();

void toast(String message, {String? actionLabel, VoidCallback? onAction}) {
  final m = rootMessenger.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, textAlign: TextAlign.center, style: body(14.5, FontWeight.w700)),
      backgroundColor: lime,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(side: BorderSide(color: charcoal, width: 1.5)),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 104), // sits above the Add food button
      padding: EdgeInsets.fromLTRB(24, 12, actionLabel == null ? 24 : 12, 12),
      elevation: 4,
      persist: false, // a snackbar with an action otherwise stays until dismissed
      duration: Duration(seconds: actionLabel == null ? 3 : 5),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: charcoal,
              backgroundColor: Colors.white.withValues(alpha: .55),
              onPressed: onAction ?? () {},
            ),
    ));
}
