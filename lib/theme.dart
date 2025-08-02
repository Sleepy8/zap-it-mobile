import 'package:flutter/material.dart';

class AppTheme {
  // Colori principali
  static const Color primaryDark = Color(0xFF121212);
  static const Color secondaryDark = Color(0xFF181818);
  static const Color limeAccent = Color(0xFFCFFF04);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color errorColor = Color(0xFFCF6679);
  static const Color warningColor = Color(0xFFFF9800);
  
  // Colori aggiuntivi per Vibe Composer
  static const Color background = primaryDark;
  static const Color primary = limeAccent;
  static const Color secondary = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF2196F3);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: limeAccent,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: limeAccent,
        secondary: limeAccent,
        surface: surfaceDark,
        background: primaryDark,
        error: errorColor,
        onPrimary: primaryDark,
        onSecondary: primaryDark,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: limeAccent,
          foregroundColor: primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: limeAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
    );
  }
} 