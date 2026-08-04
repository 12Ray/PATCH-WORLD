import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class TouchControlsOverlay extends StatelessWidget {
  const TouchControlsOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).shortestSide >= 600) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Positioned(left: 18, bottom: 18, child: _DirectionPad(game: game)),
          Positioned(
            right: 18,
            bottom: 24,
            child: Row(
              children: <Widget>[
                _ActionButton(label: 'E', onPressed: game.queueTouchInteract),
                const SizedBox(width: 12),
                _ActionButton(label: 'PULSE', onPressed: game.queueTouchAttack),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: 66,
            child: IconButton.filledTonal(
              tooltip: 'Pause',
              onPressed: game.openPauseMenu,
              icon: const Icon(Icons.pause),
            ),
          ),
        ],
      ),
    );
  }
}

final class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.game});
  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 138,
    height: 138,
    child: Stack(
      children: <Widget>[
        _direction(Icons.keyboard_arrow_up, 46, 0, 0, -1),
        _direction(Icons.keyboard_arrow_left, 0, 46, -1, 0),
        _direction(Icons.keyboard_arrow_right, 92, 46, 1, 0),
        _direction(Icons.keyboard_arrow_down, 46, 92, 0, 1),
      ],
    ),
  );

  Widget _direction(
    IconData icon,
    double left,
    double top,
    double x,
    double y,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: Listener(
        onPointerDown: (_) => game.setTouchMovement(x, y),
        onPointerUp: (_) => game.clearTouchMovement(),
        onPointerCancel: (_) => game.clearTouchMovement(),
        child: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xB31B2437),
            shape: BoxShape.circle,
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

final class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 68,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    ),
  );
}
