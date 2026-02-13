import 'package:flutter/material.dart';

/// Color constants for the MRVPN app.
///
/// Provides a consistent purple/violet color palette for both
/// dark and light themes throughout the application.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand / Shared
  // ---------------------------------------------------------------------------

  /// Primary brand purple used in both themes.
  static const Color primary = Color(0xFF7C3AED);

  /// Secondary pink used as the gradient end for accent elements.
  static const Color primaryGradientEnd = Color(0xFFEC4899);

  /// Gradient used for primary accent surfaces (buttons, banners, etc.).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Indicates an active / connected VPN state.
  static const Color connected = Color(0xFF22C55E);

  /// Indicates a disconnected VPN state.
  static const Color disconnected = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // Dark Mode
  // ---------------------------------------------------------------------------

  /// Deep navy background for dark mode.
  static const Color darkBackground = Color(0xFF0D0D1A);

  /// Dark blue-gray surface for dark mode.
  static const Color darkSurface = Color(0xFF1A1A2E);

  /// Slightly lighter card color for dark mode.
  static const Color darkCard = Color(0xFF252540);

  /// Primary text color in dark mode.
  static const Color darkTextPrimary = Color(0xFFFFFFFF);

  /// Muted secondary text color in dark mode.
  static const Color darkTextSecondary = Color(0xFFA0A0B8);

  // ---------------------------------------------------------------------------
  // Light Mode
  // ---------------------------------------------------------------------------

  /// Soft lavender background for light mode.
  static const Color lightBackground = Color(0xFFF5F5FF);

  /// White surface for light mode.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light purple-tinted card color for light mode.
  static const Color lightCard = Color(0xFFF0EEFF);

  /// Primary text color in light mode.
  static const Color lightTextPrimary = Color(0xFF1A1A2E);

  /// Slate secondary text color in light mode.
  static const Color lightTextSecondary = Color(0xFF64748B);
}
