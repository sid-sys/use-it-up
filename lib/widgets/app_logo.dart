import 'package:flutter/material.dart';
import '../theme.dart';

/// Small logo mark plus the app name. Used on the camera screen.
class AppLogo extends StatelessWidget {
  final Color textColor;
  final double size;
  const AppLogo({super.key, this.textColor = Colors.white, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(Icons.check_rounded, color: charcoal, size: size * 0.75),
      ),
      SizedBox(width: size * 0.3),
      Text('Use It Up', style: display(size * 0.8, textColor).copyWith(letterSpacing: 1)),
    ]);
  }
}
