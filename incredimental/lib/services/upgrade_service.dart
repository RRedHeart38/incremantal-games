import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/upgrade.dart';

class UpgradeService {
  static const String _upgradesPath = 'assets/data/upgrades.json';
  
  static List<Upgrade>? _cachedUpgrades;

  /// Loads upgrades from JSON file. Caches result after first load.
  static Future<List<Upgrade>> loadUpgrades() async {
    if (_cachedUpgrades != null) {
      return _cachedUpgrades!;
    }

    try {
      final jsonString = await rootBundle.loadString(_upgradesPath);
      final jsonData = jsonDecode(jsonString) as List<dynamic>;
      
      _cachedUpgrades = jsonData
          .map((item) => Upgrade.fromJson(item as Map<String, dynamic>))
          .toList();
      
      return _cachedUpgrades!;
    } catch (e) {
      throw Exception('Failed to load upgrades: $e');
    }
  }

  /// Clears the cache. Useful for testing or reloading.
  static void clearCache() {
    _cachedUpgrades = null;
  }

  /// Get upgrades for a specific target (business).
  static Future<List<Upgrade>> getUpgradesForTarget(String target) async {
    final allUpgrades = await loadUpgrades();
    return allUpgrades.where((u) => u.target == target).toList();
  }
}
