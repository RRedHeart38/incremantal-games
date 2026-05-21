import 'dart:math';

import '../config/milestone_config.dart';

const int _microsPerSecond = 1000000;
const int _revenueScale = 1000000;

class Garden {
  String name;
  String milestoneKey;
  BigInt level;
  double growthFactor;
  double baseProduction;

  int baseCost;

  // Time-gated & automation fields
  double baseDuration;
  BigInt _currentProgressMicros = BigInt.zero;
  bool isRunning = false;
  bool isAutomated = false;
  double storeMultiplier = 1.0;

  Garden({
    required this.name,
    required this.milestoneKey,
    required this.level,
    required this.growthFactor,
    required this.baseProduction,
    required this.baseCost,
    required this.baseDuration,
  });

  // Üstel maliyet: baseCost * growthFactor^level
  BigInt get currentCost {
    final costDouble = baseCost * pow(growthFactor, level.toInt());
    return BigInt.from(costDouble.round());
  }

  // Bireysel hız çarpanı: geçirilen milestone başına 2^n
  int get individualSpeedMultiplier {
    return MilestoneConfig.cumulativeMultiplier(
      milestoneKey,
      _levelForMilestones,
      includeGlobal: false,
      types: {'Speed'},
    ).round();
  }

  // Backwards-compatible milestone multiplier used by UI
  int get milestoneMultiplier => individualSpeedMultiplier;

  int get _levelForMilestones {
    final maxInt = BigInt.from(2147483647);
    return level > maxInt ? 2147483647 : level.toInt();
  }

  double get totalMilestoneMultiplier {
    return MilestoneConfig.totalMilestoneMultiplier(
      milestoneKey,
      _levelForMilestones,
    );
  }

  double get profitMilestoneMultiplier {
    return MilestoneConfig.cumulativeMultiplier(
      milestoneKey,
      _levelForMilestones,
      includeGlobal: false,
      types: {'Profit'},
    );
  }

  BigInt get currentProgressMicros => _currentProgressMicros;

  double get currentProgress =>
      _currentProgressMicros.toDouble() / _microsPerSecond;

  BigInt get _baseDurationMicros {
    final durationMicros = (baseDuration * _microsPerSecond).round();
    return BigInt.from(max(1, durationMicros));
  }

  BigInt _scaledRevenuePerCompletion(double globalProfitMultiplier) {
    if (level == BigInt.zero) return BigInt.zero;
    final scaledValue =
        baseProduction *
        level.toDouble() *
        storeMultiplier *
        profitMilestoneMultiplier *
        globalProfitMultiplier *
        _revenueScale;
    return BigInt.from(scaledValue.round());
  }

  BigInt _calculateRevenueForElapsed(
    BigInt elapsedMicros,
    int globalSpeedMultiplier, {
    required double globalProfitMultiplier,
    required bool mutateProgress,
  }) {
    if (level == BigInt.zero) return BigInt.zero;
    if (!isRunning) return BigInt.zero;

    final safeGlobalMultiplier = max(1, globalSpeedMultiplier);
    final effectiveElapsedMicros =
        elapsedMicros *
        BigInt.from(individualSpeedMultiplier * safeGlobalMultiplier);
    final totalProgress = _currentProgressMicros + effectiveElapsedMicros;
    final completions = totalProgress ~/ _baseDurationMicros;

    if (mutateProgress) {
      _currentProgressMicros = totalProgress.remainder(_baseDurationMicros);
      if (completions > BigInt.zero && !isAutomated) {
        isRunning = false;
      }
    }

    if (completions == BigInt.zero) {
      return BigInt.zero;
    }

    return (_scaledRevenuePerCompletion(globalProfitMultiplier) * completions) ~/
        BigInt.from(_revenueScale);
  }

  // Backwards-compatible per-second production estimate.
  BigInt get currentProduction {
    return estimateRevenuePerSecond(1, 1.0);
  }

  BigInt estimateRevenuePerSecond(
    int globalSpeedMultiplier,
    double globalProfitMultiplier,
  ) {
    if (level == BigInt.zero) return BigInt.zero;

    final safeGlobalMultiplier = max(1, globalSpeedMultiplier);
    final completionsPerSecondScaled = BigInt.from(
      individualSpeedMultiplier * safeGlobalMultiplier * _microsPerSecond,
    );
    return (_scaledRevenuePerCompletion(globalProfitMultiplier) * completionsPerSecondScaled) ~/
        _baseDurationMicros ~/
        BigInt.from(_revenueScale);
  }

  void startHarvest() {
    if (level == BigInt.zero) return;
    isRunning = true;
  }

  void automate() {
    if (level == BigInt.zero) return;
    isAutomated = true;
    isRunning = true;
  }

  void upgrade() {
    level = level + BigInt.one;
  }

  // Tick: returns generated gold amount for this elapsed time slice
  BigInt calculateRevenue(
    BigInt elapsedMicros,
    int globalSpeedMultiplier,
    double globalProfitMultiplier,
  ) {
    return _calculateRevenueForElapsed(
      elapsedMicros,
      globalSpeedMultiplier,
      globalProfitMultiplier: globalProfitMultiplier,
      mutateProgress: true,
    );
  }

  /// JSON'a dönüştür (kaydetme için)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level.toString(),
      'growthFactor': growthFactor,
      'baseProduction': baseProduction,
      'baseCost': baseCost,
      'baseDuration': baseDuration,
      'currentProgressMicros': _currentProgressMicros.toString(),
      'isRunning': isRunning,
      'isAutomated': isAutomated,
      'storeMultiplier': storeMultiplier,
    };
  }

  /// JSON'dan yükle (yükleme için)
  void loadFromJson(Map<String, dynamic> json) {
    level = BigInt.parse(json['level'] as String? ?? '0');
    growthFactor = json['growthFactor'] as double? ?? 1.07;
    baseProduction = json['baseProduction'] as double? ?? 0.0;
    baseCost = json['baseCost'] as int? ?? 0;
    baseDuration = json['baseDuration'] as double? ?? 1.0;
    final currentProgressMicros = json['currentProgressMicros'];
    if (currentProgressMicros is String) {
      _currentProgressMicros =
          BigInt.tryParse(currentProgressMicros) ?? BigInt.zero;
    } else if (currentProgressMicros is int) {
      _currentProgressMicros = BigInt.from(currentProgressMicros);
    } else {
      final legacyProgress = json['currentProgress'];
      if (legacyProgress is num) {
        _currentProgressMicros = BigInt.from(
          (legacyProgress * _microsPerSecond).round(),
        );
      } else {
        _currentProgressMicros = BigInt.zero;
      }
    }
    isRunning = json['isRunning'] as bool? ?? false;
    isAutomated = json['isAutomated'] as bool? ?? false;
    storeMultiplier = json['storeMultiplier'] as double? ?? 1.0;
  }
}
