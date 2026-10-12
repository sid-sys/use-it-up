import 'package:flutter/material.dart';
import '../theme.dart';

/// App icon plus the app name. Used on the camera screen.
class AppLogo extends StatelessWidget {
  final Color textColor;
  final double size;
  const AppLogo({super.key, this.textColor = Colors.white, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/brand/splash_icon.png', width: size, height: size),
      SizedBox(width: size * 0.3),
      Text('Use It Up', style: display(size * 0.8, textColor).copyWith(letterSpacing: 1)),
    ]);
  }
}
