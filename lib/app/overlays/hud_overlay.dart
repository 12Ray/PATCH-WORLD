import 'package:flutter/material.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
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
          builder: (context, snapshot, child) {
            final showCampaignBossBar =
                game.mode == PatchWorldMode.campaign &&
                snapshot.bossPhase != null &&
                snapshot.bossHealth != null &&
                snapshot.bossMaxHealth != null;
            return SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xE6111827),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF25304A)),
                      ),
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
                  if (showCampaignBossBar)
                    _CampaignBossBar(game: game, snapshot: snapshot),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _CampaignBossBar extends StatelessWidget {
  const _CampaignBossBar({required this.game, required this.snapshot});

  final PatchWorldGame game;
  final UiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.bossPhase!;
    final presentation = _campaignBossPresentation(game, phase);
    final health = snapshot.bossHealth ?? 0;
    final maxHealth = snapshot.bossMaxHealth ?? 1;
    final stability = snapshot.bossStability;
    final progress =
        (stability == null
                ? (health / maxHealth.clamp(1, 1 << 30)).clamp(0.0, 1.0)
                : (stability / 150).clamp(0.0, 1.0))
            .toDouble();
    final valueLabel = stability == null
        ? '$health / $maxHealth'
        : '${game.localization.text('hud.stability')} $stability / 150';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        key: const ValueKey<String>('campaign-boss-bar'),
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
        decoration: BoxDecoration(
          color: const Color(0xEE070B15),
          border: Border.all(color: presentation.accent.withValues(alpha: .72)),
          borderRadius: BorderRadius.circular(7),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: presentation.accent.withValues(alpha: .18),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: presentation.accent,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: presentation.accent, blurRadius: 7),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    presentation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF7FAFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  _localizedBossPhase(game, phase),
                  style: TextStyle(
                    color: presentation.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    color: Color(0xFFDCE5F5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey<String>('campaign-boss-progress'),
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFF202A40),
                valueColor: AlwaysStoppedAnimation<Color>(
                  stability == null
                      ? presentation.accent
                      : const Color(0xFFFF4FD8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({String name, Color accent}) _campaignBossPresentation(
  PatchWorldGame game,
  String phase,
) {
  if (phase.startsWith('warden_')) {
    return (
      name: game.localization.text('enemy.overflowWarden.name'),
      accent: const Color(0xFFFFC857),
    );
  }
  if (phase.startsWith('chrono_jailer_')) {
    return (
      name: game.localization.text('enemy.chronoJailer.name'),
      accent: const Color(0xFF9D8CFF),
    );
  }
  if (phase.startsWith('kernel_chimera_')) {
    return (
      name: game.localization.text('enemy.kernelChimera.name'),
      accent: const Color(0xFF36E1FF),
    );
  }
  return (
    name: game.localization.text('boss.optimizer.name'),
    accent: const Color(0xFFFF4FD8),
  );
}

final class _IntegrityView extends StatelessWidget {
  const _IntegrityView({required this.game, required this.snapshot});
  final PatchWorldGame game;
  final UiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final weapon = snapshot.selectedWeapon;
    final abilityStatus = game.mode == PatchWorldMode.survival
        ? snapshot.dashCooldownRemaining <= 0
              ? game.localization.text('hud.survivalSpecialReady')
              : game.localization.text(
                  'hud.survivalSpecialCooldown',
                  parameters: <String, Object>{
                    'seconds': snapshot.dashCooldownRemaining.toStringAsFixed(
                      1,
                    ),
                  },
                )
        : switch (weapon) {
            PlayerWeapon.sword when snapshot.dashCooldownRemaining <= 0 =>
              game.localization.text('hud.dashReady'),
            PlayerWeapon.sword => game.localization.text(
              'hud.dashCooldown',
              parameters: <String, Object>{
                'seconds': snapshot.dashCooldownRemaining.toStringAsFixed(1),
              },
            ),
            PlayerWeapon.gauntlet
                when !snapshot.specialAbilityReady &&
                    snapshot.specialAbilityCooldownRemaining <= 0 =>
              game.localization.text(
                'hud.gauntletCharging',
                parameters: <String, Object>{
                  'seconds': snapshot.gauntletChargeSeconds.toStringAsFixed(1),
                },
              ),
            PlayerWeapon.gauntlet
                when snapshot.specialAbilityCooldownRemaining > 0 =>
              game.localization.text(
                'hud.specialCooldown',
                parameters: <String, Object>{
                  'seconds': snapshot.specialAbilityCooldownRemaining
                      .toStringAsFixed(1),
                },
              ),
            PlayerWeapon.gauntlet => game.localization.text(
              'hud.gauntletChargeReady',
            ),
            PlayerWeapon.gun when snapshot.gunLaserRemaining > 0 =>
              game.localization.text(
                'hud.gunLaserActive',
                parameters: <String, Object>{
                  'seconds': snapshot.gunLaserRemaining.toStringAsFixed(1),
                },
              ),
            PlayerWeapon.gun
                when snapshot.specialAbilityCooldownRemaining > 0 =>
              game.localization.text(
                'hud.specialCooldown',
                parameters: <String, Object>{
                  'seconds': snapshot.specialAbilityCooldownRemaining
                      .toStringAsFixed(1),
                },
              ),
            PlayerWeapon.gun => game.localization.text('hud.gunLaserReady'),
            null => '',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              game.localization.text('hud.integrity'),
              style: const TextStyle(
                color: Color(0xFFA9B4C8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (weapon != null) ...<Widget>[
              const SizedBox(width: 7),
              Text(
                game.localization.text('${weapon.localizationKey}.name'),
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: List<Widget>.generate(snapshot.maxIntegrity, (index) {
            final active = index < snapshot.integrity;
            return Container(
              width: 16,
              height: 10,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF36E1FF)
                    : const Color(0xFF25304A),
                border: Border.all(
                  color: active
                      ? const Color(0xFF8AEEFF)
                      : const Color(0xFF43506A),
                ),
              ),
            );
          }),
        ),
        if (abilityStatus.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            abilityStatus,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8AEEFF), fontSize: 8),
          ),
        ],
      ],
    );
  }
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
        maxLines: 1,
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
              if (game.mode == PatchWorldMode.survival &&
                  snapshot.frameBurstPhase != null &&
                  snapshot.bossPhase != null)
                const SizedBox(width: 12),
              if (game.mode == PatchWorldMode.survival)
                if (snapshot.bossPhase case final String phase)
                  Text(
                    snapshot.bossStability == null
                        ? game.localization.text(
                            'hud.bossHealth',
                            parameters: <String, Object>{
                              'boss': game.localization.text('hud.boss'),
                              'phase': _localizedBossPhase(game, phase),
                              'current': snapshot.bossHealth ?? 0,
                              'max': snapshot.bossMaxHealth ?? 0,
                            },
                          )
                        : game.localization.text(
                            'hud.bossStability',
                            parameters: <String, Object>{
                              'perfect': game.localization.text('hud.perfect'),
                              'stability': game.localization.text(
                                'hud.stability',
                              ),
                              'value': snapshot.bossStability ?? 0,
                            },
                          ),
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              if (snapshot.survivalLevel case final int level) ...<Widget>[
                Text(
                  game.localization.text(
                    'hud.level',
                    parameters: <String, Object>{'level': level},
                  ),
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
                    game.localization.text(
                      'hud.combo',
                      parameters: <String, Object>{
                        'count': snapshot.survivalCombo ?? 0,
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 44,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: snapshot.survivalComboProgress,
                      backgroundColor: const Color(0xFF3B2F1A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        snapshot.survivalComboProgress < 0.25
                            ? const Color(0xFFFF6464)
                            : const Color(0xFFFFC857),
                      ),
                    ),
                  ),
                ],
                if ((snapshot.survivalCombo ?? 0) >= 5) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    game.localization.text(
                      'hud.flow',
                      parameters: <String, Object>{
                        'multiplier': SurvivalRunState.flowMultiplierForCombo(
                          snapshot.survivalCombo ?? 0,
                        ),
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFF45F3A6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (snapshot.survivalCriticalFlowRemaining > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    game.localization.text(
                      'hud.critical',
                      parameters: <String, Object>{
                        'seconds': snapshot.survivalCriticalFlowRemaining
                            .toStringAsFixed(1),
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  game.localization.text(
                    'hud.risk',
                    parameters: <String, Object>{
                      'multiplier': game.survivalRun.riskMultiplier
                          .toStringAsFixed(2),
                    },
                  ),
                  style: const TextStyle(
                    color: Color(0xFFFF4FD8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (snapshot.survivalDataCharge
                    case final int charge) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    snapshot.survivalDataSurge
                        ? game.localization.text('hud.dataSurge')
                        : '${game.localization.text('hud.data')} $charge/6',
                    style: const TextStyle(
                      color: Color(0xFF45F3A6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (snapshot.survivalFusionCount > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    game.localization.text(
                      'hud.fusion',
                      parameters: <String, Object>{
                        'count': snapshot.survivalFusionCount,
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (snapshot.motionVentReady) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    game.localization.text('hud.ventReady'),
                    style: const TextStyle(
                      color: Color(0xFF36E1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (snapshot.survivalOverclock) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    game.localization.text('hud.overclock'),
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

String _localizedBossPhase(PatchWorldGame game, String phase) {
  final key = phase.toLowerCase().replaceAll(' ', '_');
  final localized = game.localization.text('bossPhase.$key');
  return localized.startsWith('[') ? phase.toUpperCase() : localized;
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  patchId.split('.').last.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFF4F7FF),
                    height: 0.9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (game.survivalRun.patchTier(patchId) > 0)
                  Text(
                    game.localization.text(
                      'hud.tier',
                      parameters: <String, Object>{
                        'tier': game.survivalRun.patchTier(patchId),
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
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
