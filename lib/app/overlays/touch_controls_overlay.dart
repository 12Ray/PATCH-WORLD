import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';

final class TouchControlsOverlay extends StatelessWidget {
  const TouchControlsOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).shortestSide >= 600) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<GameSettings>(
      valueListenable: game.settings,
      builder: (context, _, child) => SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(left: 18, bottom: 18, child: _DirectionPad(game: game)),
            Positioned(
              right: 18,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _ActionButton(label: 'E', onPressed: game.queueTouchInteract),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      _HoldActionButton(
                        label: 'K',
                        onPressed: game.beginTouchSpecialAbility,
                        onReleased: game.endTouchSpecialAbility,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: game.localization.text('touch.parry'),
                        onPressed: game.queueTouchParry,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: game.localization.text('touch.attack'),
                        onPressed: game.queueTouchAttack,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 66,
              child: IconButton.filledTonal(
                tooltip: game.localization.text('touch.pause'),
                onPressed: game.openPauseMenu,
                icon: const Icon(Icons.pause),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _HoldActionButton extends StatelessWidget {
  const _HoldActionButton({
    required this.label,
    required this.onPressed,
    required this.onReleased,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onPressed(),
    onPointerUp: (_) => onReleased(),
    onPointerCancel: (_) => onReleased(),
    child: Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF334769),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
  );
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
    width: 56,
    height: 56,
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
