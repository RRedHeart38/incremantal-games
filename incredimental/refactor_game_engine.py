#!/usr/bin/env python3
import re

# Read the current file
with open('lib/engine/game_engine.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _autoSaveTimer field declaration after _timer
timer_pattern = r'(late final Timer _timer;)'
timer_replacement = r'\1\n  late Timer? _autoSaveTimer; // Throttled save timer\n  static const int _autoSaveIntervalMs = 5000; // 5 saniye throttle'
content = re.sub(timer_pattern, timer_replacement, content)

# 2. Initialize _autoSaveTimer in constructor
constructor_init = r'(GameEngine\(\) \{)'
constructor_replacement = r'\1\n    _autoSaveTimer = null;'
# This will be handled more carefully below

# 3. Add _scheduleAutoSave method before _loadUpgrades
schedule_method = '''  /// Throttled auto-save: Belirli aralıklarla kaydet (5 saniye)
  void _scheduleAutoSave() {
    if (_autoSaveTimer != null && _autoSaveTimer!.isActive) {
      return; // Timer zaten çalışıyor
    }
    
    _autoSaveTimer = Timer(const Duration(milliseconds: _autoSaveIntervalMs), () {
      _saveGame();
    });
  }

  /// İmmediate save: Kritik değişiklikler sonrası hemen kaydet
  Future<void> _immediateAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    await _saveGame();
  }

'''

# Find the position to insert _scheduleAutoSave (before _loadUpgrades)
load_upgrades_pos = content.find('  /// Asynchronously loads upgrades from JSON')
if load_upgrades_pos > 0:
    content = content[:load_upgrades_pos] + schedule_method + content[load_upgrades_pos:]

# 4. Update notifyListeners call in game loop - add _scheduleAutoSave
game_loop_update = r'(notifyListeners\(\);\s+// Throttled auto-save)'
if '// Throttled auto-save' not in content:
    game_loop_update = r'(\s+notifyListeners\(\);)\s*(\});'
    game_loop_replacement = r'\1\n      // Throttled auto-save: her tick\'ten sonra save\'i schedule et\n      _scheduleAutoSave();\n    \2'
    content = re.sub(game_loop_update, game_loop_replacement, content, count=1)

# 5. Replace _autoSave() with _immediateAutoSave() calls in purchaseUpgrade
content = re.sub(r'_autoSave\(\); // Otomatik kaydet', 
                  r'_immediateAutoSave(); // Otomatik kaydet', 
                  content)

# 6. Replace _autoSave() with _immediateAutoSave() in buyAutomation
content = content.replace('_autoSave(); // Otomatik kaydet\n      notifyListeners();',
                         '_immediateAutoSave(); // Otomatik kaydet\n      notifyListeners();')

# 7. Replace _autoSave() with _immediateAutoSave() in gardenUpgrade
# (Already done in step 5 if pattern matches)

# 8. Update dispose() to cancel timer
dispose_pattern = r'(@override\s+void dispose\(\) \{\s+_autoSave\(\);)'
dispose_replacement = r'''@override
  void dispose() {
    _autoSaveTimer?.cancel();
    _immediateAutoSave(); // Final save before dispose'''
content = re.sub(dispose_pattern, dispose_replacement, content)

# Write the refactored file
with open('lib/engine/game_engine.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ game_engine.dart refactored successfully!")
