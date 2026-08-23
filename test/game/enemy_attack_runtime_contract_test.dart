import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_pattern.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'all twelve regular enemies emit their authored runtime effects',
    (tester) async {
      final game = PatchWorldGame();
      await tester.pumpWidget(
        MaterialApp(home: GameWidget<PatchWorldGame>(game: game)),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      game.pauseEngine();
      game.world.player.position.setValues(620, 900);

      for (final archetype in PlatformerEnemyArchetype.values.where(
        (archetype) => !archetype.isMidBoss,
      )) {
        final host = PositionComponent();
        final enemy = PlatformerEnemyComponent(
          archetype: archetype,
          position: Vector2(500, 900),
          startsDormant: true,
          onDefeated: (_) {},
        );
        await tester.runAsync(() async {
          await game.world.activeRoom!.add(host);
          await host.add(enemy);
        });
        game.update(0);
        await tester.runAsync(() => enemy.mounted);

        final slot = _representativeSlot(archetype);
        enemy.debugExecutePatternSlot(slot);
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        });
        game.update(0);

        final descendants = _descendants(host).toList(growable: false);
        final projectiles = descendants
            .whereType<EnemyProjectileComponent>()
            .toList(growable: false);
        final damageVolumes = descendants
            .whereType<EnemyDamageVolumeComponent>()
            .toList(growable: false);
        _expectRepresentativeRuntime(
          archetype,
          enemy: enemy,
          projectiles: projectiles,
          damageVolumes: damageVolumes,
        );
        expect(
          <Component>[...projectiles, ...damageVolumes].every(
            (component) => switch (component) {
              EnemyProjectileComponent() => component.sourceId.startsWith(
                'enemy.${archetype.name}.',
              ),
              EnemyDamageVolumeComponent() => component.sourceId.startsWith(
                'enemy.${archetype.name}.',
              ),
              _ => false,
            },
          ),
          isTrue,
          reason: archetype.name,
        );

        host.removeFromParent();
        game.update(0);
      }
      await _verifySupportRuntime(tester, game);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _verifySupportRuntime(
  WidgetTester tester,
  PatchWorldGame game,
) async {
  final room = game.world.activeRoom!;
  final ally = PlatformerEnemyComponent(
    archetype: PlatformerEnemyArchetype.patchMite,
    position: Vector2(10000, 900),
    startsDormant: true,
    onDefeated: (_) {},
  );
  final leech = PlatformerEnemyComponent(
    archetype: PlatformerEnemyArchetype.repairLeech,
    position: Vector2(10024, 900),
    startsDormant: true,
    onDefeated: (_) {},
  );
  await tester.runAsync(() async {
    await room.addAll(<Component>[ally, leech]);
  });
  game.update(0);
  await tester.runAsync(() async {
    await ally.mounted;
    await leech.mounted;
  });

  expect(ally.health, 2);
  leech.debugExecutePatternSlot(EnemyActionSlot.enhanced);
  expect(ally.health, 4, reason: 'repair capsule restores the nearest ally');

  final selfRepairingMite = PlatformerEnemyComponent(
    archetype: PlatformerEnemyArchetype.patchMite,
    position: Vector2(11000, 900),
    startsDormant: true,
    onDefeated: (_) {},
  );
  await tester.runAsync(() async {
    await room.add(selfRepairingMite);
  });
  game.update(0);
  await tester.runAsync(() => selfRepairingMite.mounted);
  expect(selfRepairingMite.health, 2);
  selfRepairingMite.debugExecutePatternSlot(EnemyActionSlot.parryable);
  expect(selfRepairingMite.health, 3);
}

EnemyActionSlot _representativeSlot(PlatformerEnemyArchetype archetype) =>
    switch (archetype) {
      PlatformerEnemyArchetype.patchMite => EnemyActionSlot.enhanced,
      PlatformerEnemyArchetype.checksumHopper => EnemyActionSlot.enhanced,
      PlatformerEnemyArchetype.pulseTurret => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.repairLeech => EnemyActionSlot.parryable,
      PlatformerEnemyArchetype.tickRunner => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.echoBat => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.delaySniper => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.rewindSkater => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.vectorRam => EnemyActionSlot.enhanced,
      PlatformerEnemyArchetype.polarityDrone => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.phaseMimic => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.shardLobber => EnemyActionSlot.normal,
      PlatformerEnemyArchetype.overflowWarden ||
      PlatformerEnemyArchetype.chronoJailer ||
      PlatformerEnemyArchetype.kernelChimera => throw StateError(
        'Dedicated bosses are not regular enemy runtime cases.',
      ),
    };

void _expectRepresentativeRuntime(
  PlatformerEnemyArchetype archetype, {
  required PlatformerEnemyComponent enemy,
  required List<EnemyProjectileComponent> projectiles,
  required List<EnemyDamageVolumeComponent> damageVolumes,
}) {
  switch (archetype) {
    case PlatformerEnemyArchetype.patchMite:
      expect(damageVolumes, hasLength(1));
      expect(damageVolumes.single.size, Vector2(78, 24));
      expect(damageVolumes.single.damage, 2);
      expect(enemy.debugPatternHorizontalVelocity, 285);
    case PlatformerEnemyArchetype.checksumHopper:
      expect(projectiles, hasLength(1));
      expect(projectiles.single.gravity, 690);
      expect(projectiles.single.attackTier, AttackTier.enhanced);
    case PlatformerEnemyArchetype.pulseTurret:
      expect(projectiles, hasLength(3));
      expect(projectiles.map((shot) => shot.velocity.y).toSet(), hasLength(3));
    case PlatformerEnemyArchetype.repairLeech:
      expect(projectiles, hasLength(1));
      expect(projectiles.single.attackTier, AttackTier.parryable);
      expect(projectiles.single.impactImpulse, -230);
    case PlatformerEnemyArchetype.tickRunner:
      expect(damageVolumes, hasLength(1));
      expect(damageVolumes.single.size, Vector2(72, 24));
      expect(enemy.debugPatternHorizontalVelocity, 335);
    case PlatformerEnemyArchetype.echoBat:
      expect(projectiles, hasLength(6));
      expect(
        projectiles.map((shot) => shot.velocity.x.sign).toSet(),
        containsAll(<double>[-1, 1]),
      );
    case PlatformerEnemyArchetype.delaySniper:
      expect(projectiles, hasLength(1));
      expect(projectiles.single.velocity.length, closeTo(286, .01));
    case PlatformerEnemyArchetype.rewindSkater:
      expect(projectiles, hasLength(2));
      expect(projectiles.every((shot) => shot.remainingBounces == 1), isTrue);
    case PlatformerEnemyArchetype.vectorRam:
      expect(projectiles, hasLength(3));
      expect(
        projectiles.every((shot) => shot.attackTier == AttackTier.enhanced),
        isTrue,
      );
    case PlatformerEnemyArchetype.polarityDrone:
      expect(projectiles, hasLength(6));
      expect(
        projectiles.map((shot) => shot.velocity.y.sign).toSet(),
        containsAll(<double>[-1, 1]),
      );
    case PlatformerEnemyArchetype.phaseMimic:
      expect(damageVolumes, hasLength(1));
      expect(damageVolumes.single.size, Vector2(66, 94));
    case PlatformerEnemyArchetype.shardLobber:
      expect(projectiles, hasLength(3));
      expect(projectiles.every((shot) => shot.gravity == 620), isTrue);
      expect(projectiles.every((shot) => shot.remainingBounces == 1), isTrue);
    case PlatformerEnemyArchetype.overflowWarden ||
        PlatformerEnemyArchetype.chronoJailer ||
        PlatformerEnemyArchetype.kernelChimera:
      fail('Dedicated bosses must use their authored boss components.');
  }
}

Iterable<Component> _descendants(Component root) sync* {
  for (final child in root.children) {
    yield child;
    yield* _descendants(child);
  }
}
