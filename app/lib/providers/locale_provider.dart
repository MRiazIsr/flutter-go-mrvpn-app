import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'theme_provider.dart';

/// Manages the application locale (`'en'` or `'ru'`).
///
/// Persists the selected locale to [StorageService].
class LocaleNotifier extends StateNotifier<String> {
  final StorageService _storage;

  LocaleNotifier(this._storage) : super('en') {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.loadLocale();
    if (mounted) {
      state = saved;
    }
  }

  Future<void> setLocale(String locale) async {
    state = locale;
    await _storage.saveLocale(locale);
  }
}

/// Global provider for the current locale string.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LocaleNotifier(storage);
});
