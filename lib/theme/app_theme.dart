import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF151820);
  static const surface = Color(0xFF202530);
  static const raised = Color(0xFF2B3140);
  static const accent = Color(0xFFB8AEFF);
  static const text = Color(0xFFF2F3F7);
  static const muted = Color(0xFFAAB2C3);
  static const error = Color(0xFFFF8E91);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent, onPrimary: Color(0xFF211B43),
      secondary: Color(0xFF96D6CF), surface: surface,
      onSurface: text, error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background, foregroundColor: text,
      elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: surface, indicatorColor: raised, height: 72,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent, foregroundColor: const Color(0xFF211B43),
        minimumSize: const Size(48, 48), elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: raised, selectedColor: accent,
      labelStyle: const TextStyle(color: text, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: raised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}
