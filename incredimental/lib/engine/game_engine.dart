import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garden.dart';
import '../models/upgrade.dart';
import '../services/upgrade_service.dart';

class GameEngine extends ChangeNotifier {
  static const int _tickIntervalMs = 100; // 100ms per tick
  static final BigInt _tickIntervalMicros = BigInt.from(_tickIntervalMs * 1000);
  static final BigInt _thirtyMinutesMicros = BigInt.from(30 * 60 * 1000000);
  static final BigInt _initialMoney = BigInt.from(15);
  static const String _saveKey = 'gameEngine_save';
  static const int _autoSaveIntervalMs = 5000; // 5 saniye throttle

  BigInt currentMoney = _initialMoney;
  late final Timer _gameTimer;
  Timer? _autoSaveTimer; // Throttled save timer
  List<Upgrade> upgrades = [];
  Set<int> purchasedUpgradeIds = {};

  List<Garden> gardens = _createDefaultGardens();

  static List<Garden> _createDefaultGardens() {
    return [
    Garden(
      name: 'Rose Garden',
      milestoneKey: 'Garden 1',
      level: BigInt.one,
      growthFactor: 1.07,
      baseProduction: 1,
      baseCost: 4,
      baseDuration: 0.6,
    ),
    Garden(
      name: 'Tulip Garden',
      milestoneKey: 'Garden 2',
      level: BigInt.zero,
      growthFactor: 1.15,
      baseProduction: 3,
      baseCost: 60,
      baseDuration: 2.5,
    ),
    Garden(
      name: 'Orchid Garden',
      milestoneKey: 'Garden 3',
      level: BigInt.zero,
      growthFactor: 1.14,
      baseProduction: 20,
      baseCost: 720,
      baseDuration: 6.0,
    ),
    Garden(
      name: 'Bonsai Garden',
      milestoneKey: 'Garden 4',
      level: BigInt.zero,
      growthFactor: 1.13,
      baseProduction: 90,
      baseCost: 8640,
      baseDuration: 12.0,
    ),
    Garden(
      name: 'Golden Tree',
      milestoneKey: 'Garden 5',
      level: BigInt.zero,
      growthFactor: 1.12,
      baseProduction: 360,
      baseCost: 103680,
      baseDuration: 24.0,
    ),
    Garden(
      name: 'Garden 6',
      milestoneKey: 'Garden 6',
      level: BigInt.zero,
      growthFactor: 1.11,
      baseProduction: 2160,
      baseCost: 1244160,
      baseDuration: 96.0,
    ),
    Garden(
      name: 'Garden 7',
      milestoneKey: 'Garden 7',
      level: BigInt.zero,
      growthFactor: 1.10,
      baseProduction: 6480,
      baseCost: 14929920,
      baseDuration: 384.0,
    ),
    Garden(
      name: 'Garden 8',
      milestoneKey: 'Garden 8',
      level: BigInt.zero,
      growthFactor: 1.09,
      baseProduction: 19440,
      baseCost: 179159040,
      baseDuration: 1536.0,
    ),
    Garden(
      name: 'Garden 9',
      milestoneKey: 'Garden 9',
      level: BigInt.zero,
      growthFactor: 1.08,
      baseProduction: 87480,
      baseCost: 2149908480,
      baseDuration: 6144.0,
    ),
    Garden(
      name: 'Garden 10',
      milestoneKey: 'Garden 10',
      level: BigInt.zero,
      growthFactor: 1.07,
      baseProduction: 1049760,
      baseCost: 25798901760,
      baseDuration: 36864.0,
    ),
    ];
  }

  GameEngine() {
    _autoSaveTimer = null;

    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final int globalMultiplier = globalSpeedMultiplier;
      final BigInt generated = calculateRevenue(
        _tickIntervalMicros,
        globalMultiplier,
      );

      if (generated > BigInt.zero) {
        currentMoney += generated;
      }

      notifyListeners();

      // Throttled auto-save: her tick'ten sonra save'i schedule et
      _scheduleAutoSave();
    });

    _loadUpgrades();
    _loadGame(); // Oyun verilerini yükle
  }

  BigInt calculateRevenue(BigInt elapsedMicros, int globalMultiplier) {
    BigInt generated = BigInt.zero;

    for (final garden in gardens) {
      generated += garden.calculateRevenue(elapsedMicros, globalMultiplier);
    }

    return generated;
  }

  Future<BigInt> fastForwardThirtyMinutes() async {
    final temporarilyActivatedGardens = <Garden>[];
    for (final garden in gardens) {
      if (garden.level > BigInt.zero && !garden.isRunning && !garden.isAutomated) {
        garden.isRunning = true;
        temporarilyActivatedGardens.add(garden);
      }
    }

    final generated = calculateRevenue(_thirtyMinutesMicros, globalSpeedMultiplier);

    for (final garden in temporarilyActivatedGardens) {
      garden.isRunning = false;
    }

    if (generated > BigInt.zero) {
      currentMoney += generated;
    }

    notifyListeners();
    await _immediateAutoSave();
    return generated;
  }

  Future<void> resetGame() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    currentMoney = _initialMoney;
    purchasedUpgradeIds.clear();
    gardens = _createDefaultGardens();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);

    notifyListeners();
    await _immediateAutoSave();
  }

  /// Throttled auto-save: Belirli aralıklarla kaydet (5 saniye)
  void _scheduleAutoSave() {
    if (_autoSaveTimer != null && _autoSaveTimer!.isActive) {
      return; // Timer zaten çalışıyor, tekrar schedule etme
    }

    _autoSaveTimer = Timer(
      const Duration(milliseconds: _autoSaveIntervalMs),
      () {
        _saveGameNow();
      },
    );
  }

  /// İmmediate save: Kritik değişiklikler sonrası hemen kaydet (async)
  Future<void> _immediateAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    await _saveGame();
  }

  /// Senkron save (internal): Throttled timer tarafından çağrılır
  void _saveGameNow() {
    _saveGame(); // Fire-and-forget (async çalışır arka planda)
  }

  /// Asynchronously loads upgrades from JSON
  Future<void> _loadUpgrades() async {
    try {
      upgrades = await UpgradeService.loadUpgrades();
      notifyListeners();
    } catch (e) {
      print('Failed to load upgrades: $e');
    }
  }

  /// Oyun verilerini SharedPreferences'tan yükle
  Future<void> _loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        // currentMoney yükle
        currentMoney = BigInt.parse(json['currentMoney'] as String? ?? '15');

        // purchasedUpgradeIds yükle
        final upgradeIds =
            (json['purchasedUpgradeIds'] as List?)?.cast<int>() ?? [];
        purchasedUpgradeIds = Set.from(upgradeIds);

        // Gardens verilerini yükle
        final gardensData = (json['gardens'] as List?) ?? [];
        if (gardensData.isNotEmpty) {
          for (int i = 0; i < gardens.length && i < gardensData.length; i++) {
            gardens[i].loadFromJson(gardensData[i] as Map<String, dynamic>);
          }
        }

        notifyListeners();
        print('Oyun verisi yüklendi');
      }
    } catch (e) {
      print('Oyun verisi yükleme hatası: $e');
    }
  }

  /// Oyun verilerini SharedPreferences'a kaydet (async)
  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'currentMoney': currentMoney.toString(),
        'purchasedUpgradeIds': purchasedUpgradeIds.toList(),
        'gardens': gardens.map((g) => g.toJson()).toList(),
      };

      await prefs.setString(_saveKey, jsonEncode(json));
      print('Oyun verisi kaydedildi');
    } catch (e) {
      print('Oyun verisi kaydetme hatası: $e');
    }
  }

  /// Purchase an upgrade by ID and apply its multiplier to target
  void purchaseUpgrade(int upgradeId) {
    final upgrade = upgrades.firstWhere(
      (u) => u.id == upgradeId,
      orElse: () => throw Exception('Upgrade not found'),
    );

    if (purchasedUpgradeIds.contains(upgradeId)) {
      print('Upgrade already purchased');
      return;
    }

    if (currentMoney < upgrade.cost) {
      print('Insufficient funds');
      return;
    }

    currentMoney -= upgrade.cost;
    purchasedUpgradeIds.add(upgradeId);

    // Apply multiplier to gardens matching the target
    for (final garden in gardens) {
      if (garden.name == upgrade.target || upgrade.target == 'All Businesses') {
        garden.storeMultiplier *= upgrade.multiplier;
      }
    }

    _immediateAutoSave(); // Hemen kaydet
    notifyListeners();
  }

  // Backwards-compatible total production (includes global multiplier)
  BigInt get totalProduction {
    final int globalMultiplier = globalSpeedMultiplier;
    BigInt sum = BigInt.zero;

    for (final g in gardens) {
      sum += g.estimateRevenuePerSecond(globalMultiplier);
    }

    return sum;
  }

  // Manual click API removed semantically; keep compat: return 0 and no-op click
  int get manualClickPower => 0;

  void manuelTiklama() {
    // No-op: manual clicks are retired in Pure Idle mode
  }

  // Küresel sinerji: en düşük seviyeli bahçenin geçtiği milestone'lara göre 2^n
  int get globalSpeedMultiplier {
    if (gardens.isEmpty) return 1;
    // Find minimum level among gardens
    BigInt minLevel = gardens
        .map((g) => g.level)
        .reduce((a, b) => a < b ? a : b);
    if (minLevel == BigInt.zero) return 1;
    List<int> milestones = [10, 25, 50, 100, 250, 500, 1000];
    int passed = 0;
    for (final m in milestones) {
      if (minLevel >= BigInt.from(m)) {
        passed++;
      } else {
        break;
      }
    }
    return pow(2, passed).toInt();
  }

  void buyAutomation(int index) {
    if (index < 0 || index >= gardens.length) return;
    final cost = BigInt.from(gardens[index].baseCost) * BigInt.from(15);
    if (currentMoney >= cost) {
      currentMoney -= cost;
      gardens[index].automate();
      _immediateAutoSave(); // Hemen kaydet
      notifyListeners();
    }
  }

  void gardenUpgrade(int index) {
    if (index < 0 || index >= gardens.length) return;
    final cost = gardens[index].currentCost;
    if (currentMoney >= cost) {
      currentMoney -= cost;
      gardens[index].upgrade();
      _immediateAutoSave(); // Hemen kaydet
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _gameTimer.cancel();
    _immediateAutoSave(); // Son kaydı yap
    super.dispose();
  }
}
