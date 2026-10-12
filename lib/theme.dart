import 'package:flutter/material.dart';

const lime = Color(0xFFD7FF5A);
const ivory = Color(0xFFF4F3E9);
const charcoal = Color(0xFF22241F);
const cardWhite = Color(0xFFFFFFFF);
const amber = Color(0xFFB26A00);
const redDark = Color(0xFFB3261E);

TextStyle display([double size = 36, Color color = charcoal]) =>
    TextStyle(fontFamily: 'Anton', fontSize: size, color: color, height: 1.05, letterSpacing: 0.5);

TextStyle body([double size = 16, FontWeight w = FontWeight.w400, Color color = charcoal]) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: color);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: lime, brightness: Brightness.light).copyWith(
      primary: charcoal,
      onPrimary: Colors.white,
      secondary: lime,
      onSecondary: charcoal,
      surface: ivory,
    ),
    scaffoldBackgroundColor: ivory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter', bodyColor: charcoal, displayColor: charcoal),
    appBarTheme: AppBarTheme(
      backgroundColor: ivory,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: charcoal,
      titleTextStyle: display(26),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardWhite,
      indicatorColor: lime,
      labelTextStyle: WidgetStatePropertyAll(body(13, FontWeight.w600)),
    ),
  );
}

ButtonStyle limeButton() => FilledButton.styleFrom(
      backgroundColor: lime,
      foregroundColor: charcoal,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: body(16, FontWeight.w600),
    );

ButtonStyle darkButton() => FilledButton.styleFrom(
      backgroundColor: charcoal,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: body(16, FontWeight.w600),
    );
