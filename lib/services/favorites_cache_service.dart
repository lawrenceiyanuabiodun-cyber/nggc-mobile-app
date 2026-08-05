import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

/// ─────────────────────────────────────────────────────
/// FavoritesCacheService
/// Caches user favorites locally for offline VIEWING.
/// Write operations (add/remove) require internet.
/// ─────────────────────────────────────────────────────
class FavoritesCacheService {
  FavoritesCacheService._();

  static Box get _box => Hive.box(AppConfig.favoritesBoxName);

  static const String _dataKey = '__all_favorites__';
  static const String _timestampKey = '__favorites_timestamp__';

  /// Save the full favorites list to cache
  static Future<void> saveAll(List<dynamic> favorites) async {
    try {
      await _box.put(_dataKey, json.encode(favorites));
      await _box.put(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Get cached favorites list
  static List<dynamic> getAll() {
    try {
      final raw = _box.get(_dataKey);
      if (raw == null) return [];
      final decoded = json.decode(raw as String);
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }

  /// When was the cache last updated?
  static DateTime? lastUpdated() {
    final ts = _box.get(_timestampKey);
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    return null;
  }

  /// Has any cache data at all?
  static bool hasCache() {
    return _box.get(_dataKey) != null;
  }

  /// Clear the cache (on logout)
  static Future<void> clear() async {
    await _box.delete(_dataKey);
    await _box.delete(_timestampKey);
  }
}