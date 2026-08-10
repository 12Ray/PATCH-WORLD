import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combat v2 package owns 15 enemies, 3 weapons, and 3 tiers', () {
    final manifest =
        jsonDecode(
              File(
                'assets/images/sprites/combat_v2/manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final enemies = manifest['enemies'] as Map<String, dynamic>;
    final hero = manifest['hero'] as Map<String, dynamic>;
    final projectiles = manifest['projectiles'] as Map<String, dynamic>;

    expect(enemies, hasLength(15));
    expect(hero.keys.toSet(), <String>{'sword', 'gauntlet', 'gun'});
    expect(projectiles, hasLength(15));
    expect((manifest['attackTiers'] as List<dynamic>).cast<String>(), <String>[
      'normal',
      'enhanced',
      'parryable',
    ]);

    for (final entry in enemies.values.cast<Map<String, dynamic>>()) {
      expect(entry['motions'], hasLength(10));
      expect(
        File('assets/images/sprites/combat_v2/${entry['asset']}').existsSync(),
        isTrue,
      );
    }
    for (final entry in hero.values.cast<Map<String, dynamic>>()) {
      expect(entry['motions'], hasLength(10));
      expect(
        File('assets/images/sprites/combat_v2/${entry['asset']}').existsSync(),
        isTrue,
      );
    }
    for (final entry in projectiles.values.cast<Map<String, dynamic>>()) {
      expect(entry['tiers'], hasLength(3));
      expect(
        File('assets/images/sprites/combat_v2/${entry['asset']}').existsSync(),
        isTrue,
      );
    }
  });
}
