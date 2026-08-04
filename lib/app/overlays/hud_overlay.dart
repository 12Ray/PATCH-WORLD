import 'package:flutter/material.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

final class HudOverlay extends StatelessWidget {
  const HudOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<UiSnapshot>(
          valueListenable: game.uiSnapshot,
          builder: (context, snapshot, child) => Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xE6111827),
              border: Border(bottom: BorderSide(color: Color(0xFF25304A))),
            ),
            child: Row(
              children: <Widget>[
                _IntegrityView(game: game, snapshot: snapshot),
                const SizedBox(width: 18),
                Expanded(
                  child: _RuleView(game: game, snapshot: snapshot),
                ),
                _PatchStack(game: game, snapshot: snapshot),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _IntegrityView extends StatelessWidget {
  const _IntegrityView({required this.game, required this.snapshot});
  final PatchWorldGame game;
  final UiSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        game.localization.text('hud.integrity'),
        style: const TextStyle(
          color: Color(0xFFA9B4C8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: List<Widget>.generate(snapshot.maxIntegrity, (index) {
          final active = index < snapshot.integrity;
          return Container(
            width: 16,
            height: 10,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF36E1FF) : const Color(0xFF25304A),
              border: Border.all(
                color: active
                    ? const Color(0xFF8AEEFF)
                    : const Color(0xFF43506A),
              ),
            ),
          );
        }),
      ),
    ],
  );
}

final class _RuleView extends StatelessWidget {
  const _RuleView({required this.game, required this.snapshot});
  final PatchWorldGame game;
  final UiSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              snapshot.roomLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF4F7FF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              snapshot.anomalyLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFF4FD8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      Text(
        snapshot.objectiveLabel,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFFFC857),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(
        height: 14,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (snapshot.normalizedHeat case final double heat) ...<Widget>[
                SizedBox(
                  width: 120,
                  height: 4,
                  child: LinearProgressIndicator(
                    value: heat,
                    backgroundColor: const Color(0xFF25304A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      heat >= 0.75
                          ? const Color(0xFFFF6464)
                          : const Color(0xFFFFC857),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (snapshot.frameBurstPhase case final FrameBurstPhase phase)
                Text(
                  switch (phase) {
                    FrameBurstPhase.normal => game.localization.text(
                      'hud.frameStable',
                    ),
                    FrameBurstPhase.warning => game.localization.text(
                      'hud.frameWarning',
                    ),
                    FrameBurstPhase.active => game.localization.text(
                      'hud.frameActive',
                    ),
                  },
                  style: TextStyle(
                    color: phase == FrameBurstPhase.active
                        ? const Color(0xFFFF6464)
                        : const Color(0xFFFFC857),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (snapshot.frameBurstPhase != null &&
                  snapshot.bossPhase != null)
                const SizedBox(width: 12),
              if (snapshot.bossPhase case final String phase)
                Text(
                  snapshot.bossStability == null
                      ? '${game.localization.text('hud.boss')} ${phase.toUpperCase()}  HP ${snapshot.bossHealth}/${snapshot.bossMaxHealth}'
                      : '${game.localization.text('hud.perfect')}  ${game.localization.text('hud.stability')} ${snapshot.bossStability}/150',
                  style: const TextStyle(
                    color: Color(0xFFFFC857),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (snapshot.survivalLevel case final int level) ...<Widget>[
                Text(
                  'LV $level',
                  style: const TextStyle(
                    color: Color(0xFF36E1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  height: 5,
                  child: LinearProgressIndicator(
                    value:
                        (snapshot.survivalExperience ?? 0) /
                        (snapshot.survivalExperienceToNext ?? 1),
                    backgroundColor: const Color(0xFF25304A),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF4FD8),
                    ),
                  ),
                ),
                if ((snapshot.survivalCombo ?? 0) >= 2) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    'COMBO x${snapshot.survivalCombo}',
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

final class _PatchStack extends StatelessWidget {
  const _PatchStack({required this.game, required this.snapshot});
  final PatchWorldGame game;
  final UiSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final patchId in snapshot.selectedPatchIds)
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2437),
            border: Border.all(color: const Color(0xFFFF4FD8)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            patchId.split('.').last.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFF4F7FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      if (snapshot.echoPulseCount case final int count)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            '${game.localization.text('hud.echo')} $count/4',
            style: const TextStyle(
              color: Color(0xFFFF4FD8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}
