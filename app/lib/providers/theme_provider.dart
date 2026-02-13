import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides a singleton [StorageService] instance to the provider graph.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// ---------------------------------------------------------------------------
// Theme notifier
// ---------------------------------------------------------------------------

/// Manages the application theme mode (dark, light, or system).
///
/// Persists the selected theme to [StorageService] so it survives app restarts.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage;

  ThemeNotifier(this._storage) : super(ThemeMode.dark) {
    _load();
  }

  /// Load the persisted theme mode from storage.
  Future<void> _load() async {
    final saved = await _storage.loadThemeMode();
    state = _themeModeFromString(saved);
  }

  /// Set the theme to an explicit [ThemeMode] and persist the choice.
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _storage.saveThemeMode(_themeModeToString(mode));
  }

  /// Toggle between dark and light themes.
  ///
  /// If the current mode is [ThemeMode.system], it resolves to dark first.
  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(next);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global provider for the current [ThemeMode].
///
/// Usage in widgets:
/// ```dart
/// final themeMode = ref.watch(themeProvider);
/// ref.read(themeProvider.notifier).toggle();
/// ```
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeNotifier(storage);
});
