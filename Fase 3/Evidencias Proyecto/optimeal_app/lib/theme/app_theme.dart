// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Colores institucionales
  static const Color _primaryGreen = Color(0xFF16A34A); // Verde principal
  static const Color _backgroundYellow = Color(0xFFFFF9C4); // Amarillo claro
  static const Color _textBlack = Colors.black;

  static ThemeData get lightTheme {
    // Esquema base de colores
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      brightness: Brightness.light,
      background: _backgroundYellow,
    ).copyWith(
      primary: _primaryGreen,
      onPrimary: Colors.white,
      background: _backgroundYellow,
      onBackground: _textBlack,
      surface: Colors.white,
      onSurface: _textBlack,
      secondary: _primaryGreen,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      // Fondo general amarillo
      scaffoldBackgroundColor: _backgroundYellow,

      // AppBar: verde con texto blanco
      appBarTheme: const AppBarTheme(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
      ),

      // Texto negro en toda la app
      textTheme: base.textTheme.apply(
        bodyColor: _textBlack,
        displayColor: _textBlack,
      ),

      // Botones principales: verde con texto blanco
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),

      // Tarjetas: blanco con borde verdoso, sobre fondo amarillo
      cardTheme: CardTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: _primaryGreen.withOpacity(0.3),
          ),
        ),
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Inputs: "casillas verdes" (verde muy suave de fondo)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE8F5E9), // verde muy claro
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _primaryGreen.withOpacity(0.5),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(
            color: _primaryGreen,
            width: 1.6,
          ),
        ),
        labelStyle: const TextStyle(color: _textBlack),
        hintStyle: TextStyle(color: Colors.grey.shade700),
      ),

      // Bottom nav / NavigationBar: íconos verdes, texto negro
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _primaryGreen, // ⬅️ FONDO VERDE
        indicatorColor:
            Colors.white.withOpacity(0.20), // “pastilla” de selección
        iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
          (states) {
            final selected = states.contains(MaterialState.selected);
            return IconThemeData(
              color: selected ? Colors.white : Colors.white.withOpacity(0.8),
            );
          },
        ),
        labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
          (states) {
            final selected = states.contains(MaterialState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: Colors.white, // texto blanco sobre barra verde
            );
          },
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _backgroundYellow,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: _textBlack.withOpacity(0.7),
        showUnselectedLabels: true,
      ),
    );
  }
}
