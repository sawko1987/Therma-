import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF0F766E);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    surface: const Color(0xFFF7F4ED),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF3EFE5),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF3EFE5),
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE4F1EE),
      selectedColor: colorScheme.primaryContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
