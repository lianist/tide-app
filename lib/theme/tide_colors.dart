import 'package:flutter/material.dart';

/// A light-theme subset of the Tide v3.0 design tokens (dochi repo:
/// `tide-kit-v3.0/web/tide-tokens.css`, same values `app/globals.css` uses)
/// — just what `LoginScreen`/`HotkeyBadge` need.
///
/// The kit's own Flutter port (`tide-kit-v3.0/flutter/`, per
/// `flutter-porting-guide.md`) was never delivered into this checkout — it's
/// gitignored there and isn't on disk — so these are hand-ported from the
/// web tokens rather than copied from `tide_colors.dart`/`tide_roles.dart`.
/// Custom fonts (Pretendard/Wanted Sans) are in the same undelivered
/// `flutter/fonts/` folder, so this still falls back to the system font.
class TideColors {
  TideColors._();

  static const Color bgPage = Color(0xFFF5F5F5); // primary-100, Mist
  static const Color bgSurface = Color(0xFFFFFFFF); // primary-0
  static const Color bgSubtle = Color(0xFFE9E9E9); // primary-200
  static const Color border = Color(0xFFDCDCDC); // primary-300
  static const Color text = Color(0xFF1E1E1E); // primary-900
  static const Color textSecondary = Color(0xFF6D6D6D); // primary-600

  static const Color brand = Color(0xFF444892); // secondary-600, Tide Indigo
  static const Color brandHover = Color(0xFF353878); // secondary-700
  static const Color onBrand = Color(0xFFFFFFFF);

  static const Color errorBg = Color(0xFFFFF2F1); // error-50
  static const Color errorText = Color(0xFFAA1D2D); // error-700
}
