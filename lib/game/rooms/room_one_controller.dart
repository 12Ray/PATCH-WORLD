import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/tiled/tiled_room_map.dart';
import 'package:patch_world/game/rooms/tiled/room_object_spec.dart';

final class RoomOneController extends Component
    with HasGameReference<PatchWorldGame> {
  int _overflowCount = 0;
  bool _completed = false;
  late final Vector2 playerSpawn;
  late final RoomObjectSpec _secondCrawlerSpawn;

  late final SealNodeComponent sealOne;
  late final SealNodeComponent sealTwo;

  int get overflowCount => _overflowCount;
  bool get isCompleted => _completed;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final roomMap = TiledRoomMap(fileName: 'damage_lab.tmx');
    await add(roomMap);
    playerSpawn = roomMap.singleByClass('PlayerSpawn').center;
    await addAll(
      roomMap
          .allByClass('Wall')
          .map(
            (spec) => WallComponent(position: spec.position, size: spec.size),
          ),
    );
    final seals = roomMap.allByClass('SealNode')
      ..sort((a, b) => a.position.y.compareTo(b.position.y));
    sealOne = SealNodeComponent(position: seals[0].center);
    sealTwo = SealNodeComponent(position: seals[1].center);
    await addAll(<SealNodeComponent>[sealOne, sealTwo]);
    final enemySpawns = roomMap.allByClass('EnemySpawn')
      ..sort(
        (a, b) =>
            a.requireInt('spawnOrder').compareTo(b.requireInt('spawnOrder')),
      );
    _secondCrawlerSpawn = enemySpawns[1];
    await _spawnCrawler(enemySpawns.first);
  }

  Future<void> _spawnCrawler(RoomObjectSpec spec) async {
    await add(
      CrawlerComponent(
        entityId: spec.id,
        position: spec.center,
        initialHealth: 2,
        onOverflow: _handleOverflow,
      ),
    );
  }

  void _handleOverflow(CrawlerComponent crawler) {
    if (_completed) {
      return;
    }
    _overflowCount += 1;
    game.runMetrics.recordOverflow();
    if (_overflowCount == 1) {
      sealOne.activate();
      unawaited(_spawnCrawler(_secondCrawlerSpawn));
      return;
    }
    sealTwo.activate();
    _completed = true;
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      game.openRoomOnePatchSelection,
    );
  }
}

final class SealNodeComponent extends RectangleComponent {
  SealNodeComponent({required super.position})
    : super(
        size: Vector2.all(40),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF25304A),
      );

  bool _active = false;
  bool get isActive => _active;

  void activate() {
    if (_active) {
      return;
    }
    _active = true;
    paint.color = const Color(0xFF36E1FF);
    scale.setAll(1.18);
  }
}
