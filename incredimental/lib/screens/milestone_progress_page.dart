import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/milestone_config.dart';
import '../engine/game_engine.dart';
import '../utils/format_utils.dart';

class MilestoneProgressPage extends StatelessWidget {
  const MilestoneProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<GameEngine>();
    final groups = MilestoneConfig.milestones.entries.toList()
      ..sort((left, right) {
        if (left.key == 'all') return 1;
        if (right.key == 'all') return -1;

        final leftNumber = int.tryParse(left.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final rightNumber = int.tryParse(right.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return leftNumber.compareTo(rightNumber);
      });

    final totalMilestones = groups.fold<int>(0, (sum, entry) => sum + entry.value.length);
    final reachedMilestones = groups.fold<int>(0, (sum, entry) {
      final currentLevel = _currentLevelForGroup(engine, entry.key);
      return sum + entry.value.where((milestone) => currentLevel >= BigInt.from(milestone.targetLevel)).length;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milestone Listesi'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101010), Color(0xFF181818), Color(0xFF111111)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _SummaryCard(
                  reached: reachedMilestones,
                  total: totalMilestones,
                  money: engine.currentMoney,
                  gardenCount: engine.gardens.length,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = groups[index];
                    final currentLevel = _currentLevelForGroup(engine, entry.key);
                    final reachedCount = entry.value.where((milestone) => currentLevel >= BigInt.from(milestone.targetLevel)).length;

                    return _GroupCard(
                      title: entry.key,
                      subtitle: _groupSubtitle(engine, entry.key, currentLevel),
                      currentValue: currentLevel,
                      reachedCount: reachedCount,
                      totalCount: entry.value.length,
                      milestones: entry.value,
                      currentLevel: currentLevel,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BigInt _currentLevelForGroup(GameEngine engine, String key) {
    if (key == 'all') {
      return _minimumGardenLevel(engine);
    }

    final garden = engine.gardens.firstWhere(
      (garden) => garden.milestoneKey == key,
      orElse: () => engine.gardens.first,
    );
    return garden.level;
  }

  String _groupSubtitle(GameEngine engine, String key, BigInt currentLevel) {
    if (key == 'all') {
      return 'Tüm bahçelerin en düşük seviyesi baz alınır. Şu an: $currentLevel';
    }

    final garden = engine.gardens.firstWhere(
      (item) => item.milestoneKey == key,
      orElse: () => engine.gardens.first,
    );
    return '${garden.name} seviyesine göre takip ediliyor. Şu an: $currentLevel';
  }

  BigInt _minimumGardenLevel(GameEngine engine) {
    if (engine.gardens.isEmpty) {
      return BigInt.zero;
    }

    return engine.gardens
        .map((garden) => garden.level)
        .reduce((left, right) => left < right ? left : right);
  }
}

class _SummaryCard extends StatelessWidget {
  final int reached;
  final int total;
  final BigInt money;
  final int gardenCount;

  const _SummaryCard({
    required this.reached,
    required this.total,
    required this.money,
    required this.gardenCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : reached / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF232323), Color(0xFF151515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Milestone Durumu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$reached / $total ulaşıldı',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(label: 'Kasa', value: formatCompactBigInt(money)),
              _StatPill(label: 'Bahçe', value: '$gardenCount'),
              _StatPill(label: 'Tamamlanan', value: '$reached'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final BigInt currentValue;
  final int reachedCount;
  final int totalCount;
  final List<MilestoneDefinition> milestones;
  final BigInt currentLevel;

  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.reachedCount,
    required this.totalCount,
    required this.milestones,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : reachedCount / totalCount;
    final isGlobal = title == 'all';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.amberAccent,
        title: Text(
          isGlobal ? 'Genel / all' : title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$reachedCount / $totalCount ulaşıldı  •  aktif değer: $currentValue',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        children: [
          ...milestones.map((milestone) {
            final reached = currentLevel >= BigInt.from(milestone.targetLevel);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: reached
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: reached
                        ? Colors.greenAccent.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached ? Colors.greenAccent : Colors.grey.shade700,
                      ),
                      child: Icon(
                        reached ? Icons.check : Icons.lock_outline,
                        size: 16,
                        color: reached ? Colors.black : Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seviye ${milestone.targetLevel}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tip: ${milestone.type}  •  Çarpan: x${milestone.multiplier.toStringAsFixed(milestone.multiplier == milestone.multiplier.truncateToDouble() ? 0 : 2)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reached ? 'Ulaşıldı' : 'Kilitli',
                      style: TextStyle(
                        color: reached ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}