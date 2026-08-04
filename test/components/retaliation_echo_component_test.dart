import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/retaliation_echo_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';

void main() {
  test('echo is harmless while warning and damages each target once', () {
    final echo = RetaliationEchoComponent(position: Vector2.zero());
    final crawler = CrawlerComponent(
      entityId: 'echo-target',
      position: Vector2.zero(),
    );

    echo.onCollisionStart(<Vector2>{}, crawler);
    expect(crawler.health, CrawlerComponent.maxHealth);

    echo.update(RetaliationEchoComponent.warningSeconds + 0.01);
    expect(echo.blastStarted, isTrue);
    echo.onCollisionStart(<Vector2>{}, crawler);
    echo.onCollisionStart(<Vector2>{}, crawler);

    expect(crawler.health, CrawlerComponent.maxHealth - 1);
  });

  test('tier three echo deals two damage', () {
    final echo = RetaliationEchoComponent(
      position: Vector2.zero(),
      damage: 2,
      damagesPlayer: false,
    );
    final crawler = CrawlerComponent(
      entityId: 'tier-three-target',
      position: Vector2.zero(),
    );

    echo.update(RetaliationEchoComponent.warningSeconds + 0.01);
    echo.onCollisionStart(<Vector2>{}, crawler);
    expect(crawler.health, CrawlerComponent.maxHealth - 2);
  });
}
