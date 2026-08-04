import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/tiled/tiled_room_map.dart';

final class RoomThreeController extends Component
    with HasGameReference<PatchWorldGame> {
  CrawlerComponent? _crawlerA;
  CrawlerComponent? _crawlerB;
  bool _mergeStarted = false;
  bool _completed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(TiledRoomMap(fileName: 'collision_archive.tmx'));
    await add(MergeZoneComponent(position: Vector2(520, 270)));
    final crawlerA = CrawlerComponent(
      entityId: 'collision-crawler-a',
      position: Vector2(350, 160),
      initialHealth: 3,
      mergeShielded: true,
    );
    final crawlerB = CrawlerComponent(
      entityId: 'collision-crawler-b',
      position: Vector2(350, 380),
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
