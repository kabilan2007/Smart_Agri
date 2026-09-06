import 'package:flutter/material.dart';

class AgriColors {
  // Primary Palette - Lush Agricultural Green & Emerald
  static const Color primaryGreen = Color(0xFF1B5E20);      // Deep Forest Green
  static const Color primaryMedium = Color(0xFF2E7D32);     // Vibrant Plant Green
  static const Color primaryLight = Color(0xFF4CAF50);      // Leaf Green
  static const Color accentLime = Color(0xFF8BC34A);        // Young Sprout Lime
  static const Color lightMint = Color(0xFFE8F5E9);         // Soft Mint Background

  // Warm Sun & Soil Accents
  static const Color harvestGold = Color(0xFFFFB300);       // Ripe Harvest Gold
  static const Color amberWarm = Color(0xFFFF9800);         // Warm Sunset Amber
  static const Color soilBrown = Color(0xFF5D4037);         // Rich Organic Soil Brown

  // Status & Dynamic Alert Colors
  static const Color alertCritical = Color(0xFFD32F2F);     // High Risk Rain/Storm Red
  static const Color alertWarning = Color(0xFFF57C00);      // Pest/Weather Warning Orange
  static const Color alertAdvisory = Color(0xFF1976D2);     // Info Advisory Blue
  static const Color alertSafe = Color(0xFF388E3C);         // Safe Window Green

  // Neutral & Glassmorphic Shades
  static const Color bgLight = Color(0xFFF4F7F4);           // Crisp Refreshing Light Grey/Green
  static const Color bgDark = Color(0xFF121B13);            // Deep Forest Dark Mode
  static const Color cardDark = Color(0xFF1C271E);          // Dark Surface Card
  static const Color cardLight = Colors.white;              // Light Surface Card
  
  static const Color textDark = Color(0xFF1A2E1C);
  static const Color textLight = Color(0xFFF1F8F2);
  static const Color textMuted = Color(0xFF758A78);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFFF7043)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunnyGradient = LinearGradient(
    colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlassGradient = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
