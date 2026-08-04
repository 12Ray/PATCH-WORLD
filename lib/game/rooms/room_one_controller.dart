import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class RoomOneController extends Component
    with HasGameReference<PatchWorldGame> {
  int _overflowCount = 0;
  bool _completed = false;

  late final SealNodeComponent sealOne;
  late final SealNodeComponent sealTwo;

  int get overflowCount => _overflowCount;
  bool get isCompleted => _completed;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sealOne = SealNodeComponent(position: Vector2(790, 215));
    sealTwo = SealNodeComponent(position: Vector2(790, 325));
    await addAll(<SealNodeComponent>[sealOne, sealTwo]);
    await _spawnCrawler(
      id: 'damage-lab-crawler-01',
      position: Vector2(610, 215),
    );
  }

  Future<void> _spawnCrawler({
    required String id,
    required Vector2 position,
  }) async {
    await add(
      CrawlerComponent(
        entityId: id,
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
    if (_overflowCount == 1) {
      sealOne.activate();
      unawaited(
        _spawnCrawler(id: 'damage-lab-crawler-02', position: Vector2(610, 325)),
      );
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
