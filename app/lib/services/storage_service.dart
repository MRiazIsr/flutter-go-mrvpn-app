import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';
import '../models/split_tunnel_config.dart';

/// Local persistence service using shared_preferences.
///
/// Handles saving and loading of server configurations, split tunnel settings,
/// theme preferences, and general app settings.
class StorageService {
  static const String _keyServers = 'servers';
  static const String _keySplitTunnel = 'split_tunnel_config';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyStartMinimized = 'start_minimized';
  static const String _keyKillSwitch = 'kill_switch';
  static const String _keyDns = 'dns';
  static const String _keyMtu = 'mtu';
  static const String _keyLastServerId = 'last_server_id';
  static const String _keyLocale = 'locale';

  SharedPreferences? _prefs;

  /// Initialize the storage service. Must be called before any other method.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure preferences are loaded, initializing if necessary.
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // Server configurations
  // ---------------------------------------------------------------------------

  /// Save the list of server configurations.
  Future<bool> saveServers(List<ServerConfig> servers) async {
    final prefs = await _preferences;
    final jsonList = servers.map((s) => jsonEncode(s.toJson())).toList();
    return prefs.setStringList(_keyServers, jsonList);
  }

  /// Load the list of saved server configurations.
  Future<List<ServerConfig>> loadServers() async {
    final prefs = await _preferences;
    final jsonList = prefs.getStringList(_keyServers);
    if (jsonList == null || jsonList.isEmpty) return [];

    return jsonList.map((jsonStr) {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ServerConfig.fromJson(map);
    }).toList();
  }

  /// Save the ID of the last connected server.
  Future<bool> saveLastServerId(String? serverId) async {
    final prefs = await _preferences;
    if (serverId == null) {
      return prefs.remove(_keyLastServerId);
    }
    return prefs.setString(_keyLastServerId, serverId);
  }

  /// Load the ID of the last connected server.
  Future<String?> loadLastServerId() async {
    final prefs = await _preferences;
    return prefs.getString(_keyLastServerId);
  }

  // ---------------------------------------------------------------------------
  // Split tunnel configuration
  // ---------------------------------------------------------------------------

  /// Save the split tunnel configuration.
  Future<bool> saveSplitTunnelConfig(SplitTunnelConfig config) async {
    final prefs = await _preferences;
    return prefs.setString(_keySplitTunnel, jsonEncode(config.toJson()));
  }

  /// Load the split tunnel configuration.
  Future<SplitTunnelConfig> loadSplitTunnelConfig() async {
    final prefs = await _preferences;
    final jsonStr = prefs.getString(_keySplitTunnel);
    if (jsonStr == null) return SplitTunnelConfig.off();

    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SplitTunnelConfig.fromJson(map);
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  /// Save the theme mode. Values: "system", "light", "dark".
  Future<bool> saveThemeMode(String mode) async {
    final prefs = await _preferences;
    return prefs.setString(_keyThemeMode, mode);
  }

  /// Load the saved theme mode. Returns "system" as the default.
  Future<String> loadThemeMode() async {
    final prefs = await _preferences;
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  // ---------------------------------------------------------------------------
  // General settings
  // ---------------------------------------------------------------------------

  /// Save the auto-connect setting.
  Future<bool> saveAutoConnect(bool enabled) async {
    final prefs = await _preferences;
    return prefs.setBool(_keyAutoConnect, enabled);
  }

  /// Load the auto-connect setting. Defaults to false.
  Future<bool> loadAutoConnect() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyAutoConnect) ?? false;
  }

  /// Save the start-minimized setting.
  Future<bool> saveStartMinimized(bool enabled) async {
    final prefs = await _preferences;
    return prefs.setBool(_keyStartMinimized, enabled);
  }

  /// Load the start-minimized setting. Defaults to false.
  Future<bool> loadStartMinimized() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyStartMinimized) ?? false;
  }

  /// Save the kill switch setting.
  Future<bool> saveKillSwitch(bool enabled) async {
    final prefs = await _preferences;
    return prefs.setBool(_keyKillSwitch, enabled);
  }

  /// Load the kill switch setting. Defaults to false.
  Future<bool> loadKillSwitch() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyKillSwitch) ?? false;
  }

  /// Save the custom DNS address. Pass null to clear.
  Future<bool> saveDns(String? dns) async {
    final prefs = await _preferences;
    if (dns == null || dns.isEmpty) {
      return prefs.remove(_keyDns);
    }
    return prefs.setString(_keyDns, dns);
  }

  /// Load the custom DNS address. Returns null if not set.
  Future<String?> loadDns() async {
    final prefs = await _preferences;
    return prefs.getString(_keyDns);
  }

  /// Save the MTU value. Pass null to reset to default.
  Future<bool> saveMtu(int? mtu) async {
    final prefs = await _preferences;
    if (mtu == null) {
      return prefs.remove(_keyMtu);
    }
    return prefs.setInt(_keyMtu, mtu);
  }

  /// Load the MTU value. Returns null if using the default.
  Future<int?> loadMtu() async {
    final prefs = await _preferences;
    return prefs.getInt(_keyMtu);
  }

  // ---------------------------------------------------------------------------
  // Locale
  // ---------------------------------------------------------------------------

  /// Save the locale preference (`'en'` or `'ru'`).
  Future<bool> saveLocale(String locale) async {
    final prefs = await _preferences;
    return prefs.setString(_keyLocale, locale);
  }

  /// Load the saved locale preference. Defaults to `'en'`.
  Future<String> loadLocale() async {
    final prefs = await _preferences;
    return prefs.getString(_keyLocale) ?? 'en';
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Clear all stored data. Use with caution.
  Future<bool> clearAll() async {
    final prefs = await _preferences;
    return prefs.clear();
  }
}
