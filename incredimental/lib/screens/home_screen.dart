import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/game_engine.dart';
import 'milestone_progress_page.dart';
import '../utils/format_utils.dart';
import '../widgets/stat_chip.dart';
import '../widgets/upgrades_list.dart';

class AnaEkran extends StatelessWidget {
  const AnaEkran({super.key});

  @override
  Widget build(BuildContext context) {
    var engine = context.watch<GameEngine>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Botanical Tycoon: Pure Idle", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            if (engine.pendingAngels > BigInt.zero)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: TextButton(
                  onPressed: () async {
                    await engine.claimAngelsAndRestart();
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Oyun sıfırlandı, melekler kazanıldı!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text('Sıfırla (+${formatCompactBigInt(engine.pendingAngels)} Melek)'),
                ),
              ),
            IconButton(
              tooltip: '10 gün ileri sar',
              icon: const Icon(Icons.fast_forward_rounded),
              onPressed: () async {
                final generated = await engine.fastForwardTenDays();
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('10 gün ileri sarıldı. +$generated üretildi.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: '10 yıl ileri sar',
              icon: const Icon(Icons.schedule_send_rounded),
              onPressed: () async {
                final generated = await engine.fastForwardTenYears();
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('10 yıl ileri sarıldı. +$generated üretildi.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Sıfırla',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () async {
                final shouldReset = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Oyunu sıfırla'),
                    content: const Text('Tüm ilerleme, satın alınan yükseltmeler ve kayıt verisi silinsin mi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('İptal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Sıfırla'),
                      ),
                    ],
                  ),
                );

                if (shouldReset != true || !context.mounted) return;

                await engine.resetGame();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Oyun sıfırlandı.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Milestone Listesi',
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MilestoneProgressPage(),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Bahçeler"),
              Tab(text: "Mağaza"),
            ],
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: Column(
          children: [
            // --- ÜST KISIM: Kasa ve Küresel Sinerji ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const Text("TOPLAM ALTIN", style: TextStyle(color: Colors.grey, fontSize: 16, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text(
                    formatCompactBigInt(engine.currentMoney),
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 16),
                  StatChip(
                    label: "KÜRESEL SİNERJİ",
                    value: "x${engine.globalSpeedMultiplier} HIZ",
                    color: Colors.cyanAccent,
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1, color: Colors.white24),

            // --- ALT KISIM: TabBarView (Bahçeler / Mağaza) ---
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: Bahçeler Listesi
                  _buildGardensTab(context, engine),
                  
                  // TAB 2: Upgrade Mağazası
                  _buildShopTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gardens Tab: Garden upgrades and automation
  Widget _buildGardensTab(BuildContext context, GameEngine engine) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: engine.gardens.length,
      itemBuilder: (context, index) {
        var garden = engine.gardens[index];
        
        // Butonların aktiflik durumları
        bool canAffordUpgrade = engine.currentMoney >= garden.currentCost;
        BigInt automationPrice = BigInt.from(garden.baseCost) * BigInt.from(15);
        bool canAffordAutomation = engine.currentMoney >= automationPrice;
        
        // İlerleme ve hesaplamalar
        double currentSpeed = (garden.individualSpeedMultiplier * engine.globalSpeedMultiplier).toDouble();
        double targetDur = garden.baseDuration / currentSpeed;
        double progressPercent = targetDur > 0 ? (garden.currentProgress / targetDur) : 0.0;
        if (progressPercent > 1.0) progressPercent = 1.0;
        
        // Kalan zaman (saniye cinsinden)
        double remainingTime = max(0.0, targetDur - garden.currentProgress);
        String timerDisplay = remainingTime < 60 
          ? '${remainingTime.toStringAsFixed(1)}s'
          : '${(remainingTime / 60).toStringAsFixed(1)}m';
        
        // Per-second kazanç
        double perSecondProduction = garden.level == BigInt.zero 
          ? 0.0
          : (garden.baseProduction * garden.level.toDouble() * garden.storeMultiplier * currentSpeed);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: garden.isAutomated ? Colors.green.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: garden.isAutomated ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
                blurRadius: 8,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık: İsim + Seviye + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          garden.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Seviye ${garden.level}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏱️ $timerDisplay',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Per-second production
                      Text(
                        '+${perSecondProduction.toStringAsFixed(0)}/s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // İlerleme Çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: garden.level == BigInt.zero ? 0.0 : progressPercent,
                  minHeight: 10,
                  backgroundColor: Colors.black45,
                  color: garden.isAutomated ? Colors.greenAccent : Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 12),

              // Butonlar
              Row(
                children: [
                  // OTOMATİK / ÇALIŞTIR
                  Expanded(
                    flex: 2,
                    child: garden.isAutomated
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.greenAccent, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'OTOMATİK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: garden.isRunning || garden.level == BigInt.zero 
                                ? Colors.grey.shade800 
                                : Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: garden.isRunning || garden.level == BigInt.zero 
                              ? null 
                              : () => garden.startHarvest(),
                            child: const Text(
                              "ÇALIŞTIR",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),

                  // YÜKSELT
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAffordUpgrade 
                          ? const Color(0xFFFF9800)
                          : Colors.grey.shade700,
                        foregroundColor: canAffordUpgrade ? Colors.black : Colors.grey.shade500,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: canAffordUpgrade ? () => engine.gardenUpgrade(index) : null,
                      child: Column(
                        children: [
                          const Text(
                            "YÜKSELT",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            formatCompactBigInt(garden.currentCost),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // MÜDÜR
                  Expanded(
                    flex: 2,
                    child: garden.isAutomated
                        ? const SizedBox.shrink()
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAffordAutomation && garden.level > BigInt.zero 
                                ? Colors.deepPurple
                                : Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: canAffordAutomation && garden.level > BigInt.zero 
                              ? () => engine.buyAutomation(index) 
                              : null,
                            child: Column(
                              children: [
                                const Text(
                                  "MÜDÜR",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  formatCompactBigInt(automationPrice),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shop Tab: Upgrade shop
  Widget _buildShopTab(BuildContext context) {
    return const UpgradesListWidget();
  }
}