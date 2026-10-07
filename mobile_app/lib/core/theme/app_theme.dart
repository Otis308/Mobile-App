import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _inputTheme = InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
  );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3E6FF2),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        inputDecorationTheme: _inputTheme,
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7EA0FF),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        inputDecorationTheme: _inputTheme,
      );
}
