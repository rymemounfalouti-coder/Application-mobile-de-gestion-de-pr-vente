import 'package:flutter/material.dart';

/// The single source of truth for colour in the app.
///
/// Brand is green. There is deliberately no blue token: blue used to be the
/// primary colour and every saturated blue has been migrated onto this ramp.
/// Slate neutrals below are greys, not blues — they stay.
class AppPalette {
  const AppPalette._();

  // --- Brand -------------------------------------------------------------
  /// Headers, hero-card gradient start. The "darker green".
  static const brandDeep = Color(0xFF0B3B2A);

  /// Hero-card gradient end, pressed states.
  static const brandDark = Color(0xFF12543A);

  /// Primary action colour: buttons, selected nav, links, active borders.
  static const brand = Color(0xFF1B7F4B);

  /// Hover / lighter accents on a dark surface.
  static const brandBright = Color(0xFF25A263);

  /// Tinted fill behind icons, chips, selected rows.
  static const brandSoft = Color(0xFFE6F4EC);

  /// Faintest brand wash, used for whole-page backgrounds.
  static const brandSofter = Color(0xFFF1F8F4);

  /// Lime accent carried over from the login screen.
  static const accent = Color(0xFF8CCB2F);

  /// Hero-card gradient, as seen on the admin dashboard.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandDeep, brandDark],
  );

  // --- Neutrals (slate greys, intentionally kept) -------------------------
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const surface = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);

  /// Shadows were tinted blue; they are tinted brand-green now. Callers apply
  /// their own alpha.
  static const shadow = brandDeep;

  // --- Semantic -----------------------------------------------------------
  /// Brighter than [brand] so "success" stays legible next to a green button.
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  /// Replaces the old blue "info"; teal reads as informational without
  /// reintroducing blue.
  static const info = Color(0xFF0E7490);

  /// Reserved for the one non-status accent in reporting ("CA potentiel").
  static const violet = Color(0xFF7C3AED);
}
