import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
import 'package:patch_world/game/components/effects/collision_merge_effect_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/tiled/tiled_room_map.dart';

final class RoomThreeController extends Component
    with HasGameReference<PatchWorldGame> {
  CrawlerComponent? _crawlerA;
  CrawlerComponent? _crawlerB;
  bool _mergeStarted = false;
  bool _completed = false;
  late final MergeZoneComponent _mergeZone;
  late final Vector2 playerSpawn;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.collision));
    final roomMap = TiledRoomMap(fileName: 'collision_archive.tmx');
    await add(roomMap);
    playerSpawn = roomMap.singleByClass('PlayerSpawn').center;
    await addAll(
      roomMap
          .allByClass('Wall')
          .map(
            (spec) => WallComponent(position: spec.position, size: spec.size),
          ),
    );
    _mergeZone = MergeZoneComponent(
      position: roomMap.singleByClass('MergeZone').center,
    );
    await add(_mergeZone);
    final enemySpawns = roomMap.allByClass('EnemySpawn')
      ..sort(
        (a, b) =>
            a.requireInt('spawnOrder').compareTo(b.requireInt('spawnOrder')),
      );
    final crawlerA = CrawlerComponent(
      entityId: enemySpawns[0].id,
      position: enemySpawns[0].center,
      initialHealth: 3,
      mergeShielded: true,
      speedMultiplier: 0.58,
    );
    final crawlerB = CrawlerComponent(
      entityId: enemySpawns[1].id,
      position: enemySpawns[1].center,
      initialHealth: 3,
      mergeShielded: true,
      speedMultiplier: 0.58,
    );
    _crawlerA = crawlerA;
    _crawlerB = crawlerB;
    _mergeZone.targets = <CrawlerComponent>[crawlerA, crawlerB];
    await addAll(<CrawlerComponent>[crawlerA, crawlerB]);
  }

  @override
  void update(double dt) {
    if (game.world.isReady && !_mergeStarted) {
      final enemyDt = game.clock.enemyDt;
      _crawlerA?.applyMagneticPull(_mergeZone.position, enemyDt);
      _crawlerB?.applyMagneticPull(_mergeZone.position, enemyDt);
    }
    super.update(dt);
  }

  bool tryMerge(CrawlerComponent first, CrawlerComponent second) {
    if (_mergeStarted || _completed || identical(first, second)) return false;
    final validPair =
        (identical(first, _crawlerA) && identical(second, _crawlerB)) ||
        (identical(first, _crawlerB) && identical(second, _crawlerA));
    if (!validPair ||
        !first.canMerge ||
        !second.canMerge ||
        !_mergeZone.containsTarget(first.position) ||
        !_mergeZone.containsTarget(second.position)) {
      return false;
    }
    _mergeStarted = true;
    first.consumeForMerge();
    second.consumeForMerge();
    final mergedPosition = (first.position + second.position) / 2;
    final combinedHealth = first.health + second.health;
    first.removeFromParent();
    second.removeFromParent();
    _mergeZone.triggerMerge();
    add(CollisionMergeEffectComponent(position: mergedPosition));
    Future<void>.delayed(
      const Duration(milliseconds: 420),
      () => _spawnComposite(mergedPosition, combinedHealth),
    );
    return true;
  }

  Future<void> _spawnComposite(Vector2 position, int combinedHealth) async {
    if (!isMounted) return;
    await add(
      CompositeComponent(
        entityId: 'collision-composite-01',
        position: position,
        combinedHealth: combinedHealth,
        onDefeated: _onCompositeDefeated,
      ),
    );
  }

  void _onCompositeDefeated() {
    if (_completed) return;
    _completed = true;
    Future<void>.delayed(
      const Duration(milliseconds: 550),
      game.openRoomThreePatchSelection,
    );
  }

  bool tryInteract(PlayerComponent player) => false;
}

final class MergeZoneComponent extends CircleComponent {
  MergeZoneComponent({required super.position})
    : super(
        radius: 82,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x2236E1FF),
        priority: -1,
      );

  List<CrawlerComponent> targets = const <CrawlerComponent>[];
  double _time = 0;
  bool _merging = false;

  bool containsTarget(Vector2 target) =>
      position.distanceToSquared(target) <= 70 * 70;

  void triggerMerge() => _merging = true;

  @override
  void update(double dt) {
    _time += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(radius, radius);
    for (final target in targets) {
      if (target.isRemoving) continue;
      final localTarget = Offset(
        target.position.x - position.x + radius,
        target.position.y - position.y + radius,
      );
      canvas.drawLine(
        center,
        localTarget,
        Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0x6636E1FF),
      );
      final direction = localTarget - center;
      if (direction.distance > 1) {
        final unit = direction / direction.distance;
        for (var index = 1; index <= 3; index += 1) {
          final marker = center + unit * (direction.distance * index / 4);
          canvas.drawCircle(
            marker,
            2.2,
            Paint()..color = const Color(0xAA36E1FF),
          );
        }
      }
    }
    final pulse = 58 + math.sin(_time * 4.2).abs() * 17;
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _merging ? 5 : 2.5
        ..color = _merging ? const Color(0xFFFF4FD8) : const Color(0xAA36E1FF),
    );
    canvas.drawCircle(
      center,
      34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x88FF4FD8),
    );
  }
}
