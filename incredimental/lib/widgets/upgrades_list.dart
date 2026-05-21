import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/upgrade.dart';
import '../services/upgrade_service.dart';
import '../utils/format_utils.dart';
import '../engine/game_engine.dart';

/// Example widget demonstrating how to display upgrades from JSON.
/// Uses FutureBuilder to handle async loading.
class UpgradesListWidget extends StatelessWidget {
  final String? filterTarget;

  const UpgradesListWidget({Key? key, this.filterTarget}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Upgrade>>(
      future: filterTarget != null
          ? UpgradeService.getUpgradesForTarget(filterTarget!)
          : UpgradeService.loadUpgrades(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading upgrades: ${snapshot.error}'),
          );
        }

        // Handle empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No upgrades available'));
        }

        final upgrades = snapshot.data!;

        // Display list of upgrades
        return ListView.builder(
          itemCount: upgrades.length,
          itemBuilder: (context, index) {
            final upgrade = upgrades[index];
            return UpgradeCard(upgrade: upgrade);
          },
        );
      },
    );
  }
}

/// Individual upgrade card widget.
class UpgradeCard extends StatelessWidget {
  final Upgrade upgrade;

  const UpgradeCard({Key? key, required this.upgrade}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upgrade name and multiplier
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    upgrade.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text('x${upgrade.multiplier.toStringAsFixed(2)}'),
                  backgroundColor: Colors.amber.shade200,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Target business
            Text(
              'Target: ${upgrade.target}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            // Cost displayed with scientific notation
            Text(
              'Cost: ${formatCompactBigInt(upgrade.cost)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 12),
            // Purchase button
            Consumer<GameEngine>(
              builder: (context, gameEngine, _) {
                final canAfford = gameEngine.currentMoney >= upgrade.cost;
                final alreadyPurchased = gameEngine.purchasedUpgradeIds.contains(upgrade.id);
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAfford && !alreadyPurchased
                        ? () {
                            gameEngine.purchaseUpgrade(upgrade.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${upgrade.name} purchased!'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadyPurchased ? Colors.grey : Colors.green,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      alreadyPurchased ? 'Owned' : 'Buy',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
