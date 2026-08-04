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
}
