import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
import 'package:patch_world/game/components/environment/terminal_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/tiled/tiled_room_map.dart';

final class RoomTwoController extends Component
    with HasGameReference<PatchWorldGame> {
  final List<TerminalComponent> _terminals = <TerminalComponent>[];
  bool _completed = false;
  late final Vector2 playerSpawn;

  int get activatedTerminalCount =>
      _terminals.where((terminal) => terminal.isActivated).length;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.temporal));
    final roomMap = TiledRoomMap(fileName: 'temporal_hall.tmx');
    await add(roomMap);
    playerSpawn = roomMap.singleByClass('PlayerSpawn').center;
    await addAll(
      roomMap
          .allByClass('Wall')
          .map(
            (spec) => WallComponent(position: spec.position, size: spec.size),
          ),
    );
    await addAll(
      roomMap
          .allByClass('EnemySpawn')
          .map(
            (spec) =>
                SentinelComponent(entityId: spec.id, position: spec.center),
          ),
    );
    _terminals.addAll(
      roomMap
          .allByClass('Terminal')
          .map(
            (spec) => TerminalComponent(
              terminalId: spec.id,
              position: spec.center,
              onActivated: _onTerminalActivated,
            ),
          ),
    );
    await addAll(_terminals);
  }

  bool tryInteract(PlayerComponent player) {
    for (final terminal in _terminals) {
      if (terminal.tryActivate(player.position)) return true;
    }
    return false;
  }

  void _onTerminalActivated(TerminalComponent terminal) {
    if (_completed || !_terminals.every((item) => item.isActivated)) return;
    _completed = true;
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      game.openRoomTwoPatchSelection,
    );
  }
}
