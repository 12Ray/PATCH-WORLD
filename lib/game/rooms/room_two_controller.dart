import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
import 'package:patch_world/game/components/environment/terminal_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class RoomTwoController extends Component
    with HasGameReference<PatchWorldGame> {
  final List<TerminalComponent> _terminals = <TerminalComponent>[];
  bool _completed = false;

  int get activatedTerminalCount =>
      _terminals.where((terminal) => terminal.isActivated).length;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll(<WallComponent>[
      WallComponent(position: Vector2(420, 125), size: Vector2(48, 120)),
      WallComponent(position: Vector2(420, 295), size: Vector2(48, 120)),
      WallComponent(position: Vector2(610, 210), size: Vector2(48, 120)),
    ]);
    await addAll(<SentinelComponent>[
      SentinelComponent(
        entityId: 'temporal-sentinel-a',
        position: Vector2(500, 110),
      ),
      SentinelComponent(
        entityId: 'temporal-sentinel-b',
        position: Vector2(500, 430),
      ),
    ]);
    final upper = TerminalComponent(
      terminalId: 'temporal-terminal-a',
      position: Vector2(830, 150),
      onActivated: _onTerminalActivated,
    );
    final lower = TerminalComponent(
      terminalId: 'temporal-terminal-b',
      position: Vector2(830, 390),
      onActivated: _onTerminalActivated,
    );
    _terminals.addAll(<TerminalComponent>[upper, lower]);
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
