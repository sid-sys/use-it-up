import 'package:flutter/material.dart';

/// Brand splash shown right after the native splash. Same background colour as the
/// artwork, so there is no visible edge.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const background = Color(0xFFF2F0E3);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: background,
      child: SizedBox.expand(
        child: Image(image: AssetImage('assets/brand/splash_source.webp'), fit: BoxFit.contain),
      ),
    );
  }
}
