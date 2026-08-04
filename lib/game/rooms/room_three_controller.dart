import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
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
    await add(
      MergeZoneComponent(position: roomMap.singleByClass('MergeZone').center),
    );
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
    );
    final crawlerB = CrawlerComponent(
      entityId: enemySpawns[1].id,
      position: enemySpawns[1].center,
      initialHealth: 3,
      mergeShielded: true,
    );
    _crawlerA = crawlerA;
    _crawlerB = crawlerB;
    await addAll(<CrawlerComponent>[crawlerA, crawlerB]);
  }

  bool tryMerge(CrawlerComponent first, CrawlerComponent second) {
    if (_mergeStarted || _completed || identical(first, second)) return false;
    final validPair =
        (identical(first, _crawlerA) && identical(second, _crawlerB)) ||
        (identical(first, _crawlerB) && identical(second, _crawlerA));
    if (!validPair || !first.canMerge || !second.canMerge) return false;
    _mergeStarted = true;
    first.consumeForMerge();
    second.consumeForMerge();
    final mergedPosition = (first.position + second.position) / 2;
    final combinedHealth = first.health + second.health;
    first.removeFromParent();
    second.removeFromParent();
    unawaited(_spawnComposite(mergedPosition, combinedHealth));
    return true;
  }

  Future<void> _spawnComposite(Vector2 position, int combinedHealth) async {
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
}
