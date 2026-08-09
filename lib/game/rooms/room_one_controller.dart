import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class RoomOneController extends Component
    with HasGameReference<PatchWorldGame> {
  int _overflowCount = 0;
  bool _completed = false;
  late final Vector2 playerSpawn;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];

  late final SealNodeComponent sealOne;
  late final SealNodeComponent sealTwo;

  int get overflowCount => _overflowCount;
  bool get isCompleted => _completed;
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.damage));
    playerSpawn = Vector2(72, 448);
    _surfaces.addAll(<PlatformSurfaceComponent>[
      PlatformSurfaceComponent(
        position: Vector2(0, 0),
        size: Vector2(24, 540),
        isBoundary: true,
      ),
      PlatformSurfaceComponent(
        position: Vector2(936, 0),
        size: Vector2(24, 540),
        isBoundary: true,
      ),
      PlatformSurfaceComponent(
        position: Vector2(0, 484),
        size: Vector2(278, 56),
      ),
      PlatformSurfaceComponent(
        position: Vector2(392, 484),
        size: Vector2(568, 56),
      ),
      PlatformSurfaceComponent(
        position: Vector2(168, 404),
        size: Vector2(142, 22),
      ),
      PlatformSurfaceComponent(
        position: Vector2(330, 338),
        size: Vector2(128, 22),
      ),
      PlatformSurfaceComponent(
        position: Vector2(506, 405),
        size: Vector2(142, 22),
      ),
      PlatformSurfaceComponent(
        position: Vector2(666, 326),
        size: Vector2(130, 22),
      ),
      PlatformSurfaceComponent(
        position: Vector2(804, 410),
        size: Vector2(132, 22),
      ),
    ]);
    await addAll(_surfaces);
    await add(
      DamagePitComponent(position: Vector2(278, 484), size: Vector2(114, 56)),
    );
    sealOne = SealNodeComponent(position: Vector2(744, 292));
    sealTwo = SealNodeComponent(position: Vector2(874, 376));
    await addAll(<SealNodeComponent>[sealOne, sealTwo]);
    await _spawnCrawler('damage-crawler-01', Vector2(730, 290));
  }

  Future<void> _spawnCrawler(String entityId, Vector2 position) async {
    await add(
      CrawlerComponent(
        entityId: entityId,
        position: position,
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
      unawaited(_spawnCrawler('damage-crawler-02', Vector2(862, 374)));
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
