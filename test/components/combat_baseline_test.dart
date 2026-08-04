import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';

void main() {
  test('crawler is removed after three pulse damage', () {
    final crawler = CrawlerComponent(
      entityId: 'test-crawler',
      position: Vector2.zero(),
    );

    crawler.takePulseDamage(1);
    crawler.takePulseDamage(1);
    expect(crawler.health, 1);
    crawler.takePulseDamage(1);

    expect(crawler.health, 0);
    expect(crawler.isDefeated, isTrue);
  });

  test('one pulse damages a target only once', () {
    final crawler = CrawlerComponent(
      entityId: 'test-crawler',
      position: Vector2.zero(),
    );
    final pulse = PatchPulseComponent(position: Vector2.zero());

    pulse.onCollisionStart(<Vector2>{}, crawler);
    pulse.onCollisionStart(<Vector2>{}, crawler);

    expect(crawler.health, CrawlerComponent.maxHealth - 1);
  });

  test('player ignores damage during invulnerability window', () {
    final player = PlayerComponent(
      position: Vector2.zero(),
      spawnPosition: Vector2.zero(),
    );

    player.takeDamage(1);
    player.takeDamage(1);
    expect(player.integrity, 4);

    player.update(PlayerComponent.hitInvulnerabilitySeconds + 0.01);
    player.takeDamage(1);
    expect(player.integrity, 3);
  });
}
