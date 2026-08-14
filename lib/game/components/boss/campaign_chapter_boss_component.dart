import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum CampaignChapterBossKind { chronoJailer, kernelChimera }

extension CampaignChapterBossKindSpec on CampaignChapterBossKind {
  String get assetSlug => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'chrono-jailer',
    CampaignChapterBossKind.kernelChimera => 'kernel-chimera',
  };

  String get enemyLocalizationKey => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'enemy.chronoJailer.name',
    CampaignChapterBossKind.kernelChimera => 'enemy.kernelChimera.name',
  };

  String get phasePrefix => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'chrono_jailer',
    CampaignChapterBossKind.kernelChimera => 'kernel_chimera',
  };

  Color get accentColor => switch (this) {
    CampaignChapterBossKind.chronoJailer => const Color(0xFF9D8CFF),
    CampaignChapterBossKind.kernelChimera => const Color(0xFF36E1FF),
  };
}

enum CampaignChapterBossPhase {
  dormant,
  intro,
  phaseOne,
  phaseTwo,
  phaseThree,
  defeated,
}

/// Dedicated phased boss used by Temporal Hall and Collision Archive.
final class CampaignChapterBossComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  CampaignChapterBossComponent({
    required super.position,
    required this.kind,
    required this.onDefeated,
    this.onPhaseChanged,
  }) : healthState = HealthState(max: 20, current: 20, overflowMargin: 0),
       super(size: Vector2(78, 90), anchor: Anchor.center, priority: 17);

  final CampaignChapterBossKind kind;
  final HealthState healthState;
  final VoidCallback onDefeated;
  final void Function(CampaignChapterBossPhase phase)? onPhaseChanged;
  CampaignChapterBossPhase phase = CampaignChapterBossPhase.dormant;

  SpriteComponent? _visual;
  List<Sprite>? _frames;
  double _clock = 0;
  double _attackCooldown = .9;
  double _telegraphRemaining = 0;
  double _defeatRemaining = 0;
  String? _pendingAttack;
  final List<String> _recentAttacks = <String>[];
  int _decisionCursor = 0;
  bool _resolved = false;

  @override
  String get entityId => 'boss.${kind.name}';
  int get health => healthState.current;
  int get maxHealth => healthState.max;
  bool get hasArtV3Visual => _frames?.length == 8;
  bool get isActive => switch (phase) {
    CampaignChapterBossPhase.phaseOne ||
    CampaignChapterBossPhase.phaseTwo ||
    CampaignChapterBossPhase.phaseThree => true,
    _ => false,
  };

  String get phaseId => switch (phase) {
    CampaignChapterBossPhase.dormant => '${kind.phasePrefix}_dormant',
    CampaignChapterBossPhase.intro => '${kind.phasePrefix}_intro',
    CampaignChapterBossPhase.phaseOne => '${kind.phasePrefix}_phase1',
    CampaignChapterBossPhase.phaseTwo => '${kind.phasePrefix}_phase2',
    CampaignChapterBossPhase.phaseThree => '${kind.phasePrefix}_phase3',
    CampaignChapterBossPhase.defeated => '${kind.phasePrefix}_defeated',
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2(.72, .84),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
    await add(
      TextComponent(
        text: game.localization.text(kind.enemyLocalizationKey),
        position: Vector2(size.x / 2, -18),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: kind.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    );
    unawaited(_loadVisual());
  }

  Future<void> _loadVisual() async {
    try {
      final image = await game.images.load(
        'sprites/art_v3/enemies/${kind.assetSlug}.png',
      );
      _frames = List<Sprite>.generate(
        8,
        (index) => Sprite(
          image,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
      );
      final visual = SpriteComponent(
        sprite: _frames!.first,
        size: Vector2.all(144),
        position: size / 2,
        anchor: Anchor.center,
        priority: 2,
      )..paint.filterQuality = FilterQuality.none;
      _visual = visual;
      await add(visual);
    } catch (_) {
      // Procedural rendering remains available if an optional strip fails.
    }
  }

  void beginIntro() {
    if (phase != CampaignChapterBossPhase.dormant) return;
    phase = CampaignChapterBossPhase.intro;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  void activate() {
    if (phase != CampaignChapterBossPhase.intro) return;
    phase = CampaignChapterBossPhase.phaseOne;
    _attackCooldown = .6;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  @override
  void receiveDamage(int amount) {
    if (!isActive || amount <= 0) return;
    final previousPhase = phase;
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      _beginDefeat();
      return;
    }
    phase = switch (healthState.current) {
      <= 6 => CampaignChapterBossPhase.phaseThree,
      <= 13 => CampaignChapterBossPhase.phaseTwo,
      _ => CampaignChapterBossPhase.phaseOne,
    };
    if (phase != previousPhase) {
      _attackCooldown = .25;
      scale.setAll(1.12);
      onPhaseChanged?.call(phase);
      game.triggerImpactFeedback();
      game.publishUiSnapshot(force: true);
    }
  }

  @override
  void receiveHealing(int amount) {
    if (!isActive || amount <= 0) return;
    healthState.applyHealing(amount);
  }

  void _beginDefeat() {
    if (_resolved) return;
    _resolved = true;
    phase = CampaignChapterBossPhase.defeated;
    onPhaseChanged?.call(phase);
    _pendingAttack = null;
    _defeatRemaining = 1.1;
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  @override
  void update(double dt) {
    final enemyDt = isMounted ? game.clock.enemyDt : dt;
    _clock += enemyDt;
    if (phase == CampaignChapterBossPhase.defeated) {
      final presentationDt = isMounted ? game.clock.realDt : dt;
      _defeatRemaining = math.max(0, _defeatRemaining - presentationDt);
      final progress = 1 - _defeatRemaining / 1.1;
      scale.setAll(1 + math.sin(progress * math.pi * 7).abs() * .13);
      angle = math.sin(progress * math.pi * 9) * .04;
      if (_defeatRemaining <= 0) _finishDefeat();
      _syncVisual();
      super.update(dt);
      return;
    }
    if (!isActive) {
      _syncVisual();
      super.update(dt);
      return;
    }
    _attackCooldown = math.max(0, _attackCooldown - enemyDt);
    _telegraphRemaining = math.max(0, _telegraphRemaining - enemyDt);
    if (_pendingAttack != null && _telegraphRemaining <= 0) {
      final attack = _pendingAttack!;
      _pendingAttack = null;
      _executeAttack(attack);
      _attackCooldown = switch (phase) {
        CampaignChapterBossPhase.phaseThree => .68,
        CampaignChapterBossPhase.phaseTwo => .88,
        _ => 1.08,
      };
    } else if (_pendingAttack == null && _attackCooldown <= 0) {
      _telegraph(_chooseAttack());
    }
    _syncVisual();
    super.update(dt);
  }

  String _chooseAttack() {
    final distance = game.world.player.position.distanceTo(position);
    final candidates = switch (kind) {
      CampaignChapterBossKind.chronoJailer => <String>[
        if (distance < 210) 'rewindCharge',
        if (distance >= 130) 'clockFan',
        if (phase != CampaignChapterBossPhase.phaseOne) 'timeCage',
        if (phase == CampaignChapterBossPhase.phaseThree) 'hourglassMine',
        'clockSweep',
      ],
      CampaignChapterBossKind.kernelChimera => <String>[
        if (distance < 220) 'mergeSlam',
        if (distance >= 120) 'splitKernel',
        if (phase != CampaignChapterBossPhase.phaseOne) 'polarityCross',
        if (phase == CampaignChapterBossPhase.phaseThree) 'vectorCage',
        'gravityShard',
      ],
    };
    final filtered = candidates
        .where((id) => !_recentAttacks.take(2).contains(id))
        .toList(growable: false);
    final pool = filtered.isEmpty ? candidates : filtered;
    final chosen = pool[_decisionCursor % pool.length];
    _decisionCursor += 1;
    _recentAttacks.insert(0, chosen);
    if (_recentAttacks.length > 3) _recentAttacks.removeLast();
    return chosen;
  }

  void _telegraph(String attack) {
    _pendingAttack = attack;
    _telegraphRemaining = switch (attack) {
      'timeCage' || 'vectorCage' => .78,
      'rewindCharge' || 'mergeSlam' => .58,
      _ => .45,
    };
    unawaited(game.audio.playEnemyAttack('${kind.name}.telegraph.$attack'));
  }

  void _executeAttack(String attack) {
    final owner = parent;
    if (owner == null) return;
    unawaited(game.audio.playEnemyAttack('${kind.name}.$attack'));
    switch (attack) {
      case 'rewindCharge' || 'mergeSlam':
        final direction = (game.world.player.position.x - position.x).sign;
        final facing = direction == 0 ? 1.0 : direction.toDouble();
        unawaited(
          _addToOwner(
            owner,
            EnemyDamageVolumeComponent(
              position: position + Vector2(facing * 98, 10),
              size: Vector2(190, 76),
              sourceId: 'enemy.${kind.name}.$attack',
              activeSeconds: .24,
              volumeColor: kind.accentColor.withAlpha(125),
            ),
          ),
        );
      case 'clockSweep':
        unawaited(
          _addToOwner(
            owner,
            EnemyDamageVolumeComponent(
              position: position + Vector2(0, 30),
              size: Vector2(330, 38),
              sourceId: 'enemy.chronoJailer.clockSweep',
              activeSeconds: .2,
              volumeColor: kind.accentColor.withAlpha(115),
            ),
          ),
        );
      case 'clockFan' || 'splitKernel' || 'polarityCross':
        final angles = attack == 'polarityCross'
            ? <double>[-math.pi / 2, 0, math.pi / 2, math.pi]
            : <double>[-.34, -.17, 0, .17, .34];
        for (final angle in angles) {
          final direction = attack == 'polarityCross'
              ? (Vector2(1, 0)..rotate(angle))
              : game.world.player.position - position;
          if (direction.length2 == 0) direction.x = 1;
          direction.normalize();
          if (attack != 'polarityCross') direction.rotate(angle);
          unawaited(
            _addToOwner(
              owner,
              EnemyProjectileComponent(
                position: position.clone(),
                velocity: direction * (attack == 'splitKernel' ? 300 : 270),
                sourceId: 'enemy.${kind.name}.$attack',
                attackTier: angle == 0
                    ? AttackTier.parryable
                    : AttackTier.normal,
                projectileRadius: angle == 0 ? 9 : 6,
                assetSlug: kind.assetSlug,
              ),
            ),
          );
        }
      case 'timeCage' || 'vectorCage':
        final target = game.world.player.position.clone();
        for (final offset in <Vector2>[
          Vector2(-105, 0),
          Vector2(105, 0),
          Vector2(0, -105),
        ]) {
          unawaited(
            _addToOwner(
              owner,
              EnemyDamageVolumeComponent(
                position: target + offset,
                size: offset.y == 0 ? Vector2(34, 150) : Vector2(180, 30),
                sourceId: 'enemy.${kind.name}.$attack',
                activeSeconds: .28,
                volumeColor: kind.accentColor.withAlpha(120),
              ),
            ),
          );
        }
      case 'hourglassMine' || 'gravityShard':
        final direction = game.world.player.position - position;
        if (direction.length2 == 0) direction.x = 1;
        direction.normalize();
        unawaited(
          _addToOwner(
            owner,
            EnemyProjectileComponent(
              position: position + Vector2(direction.x * 32, -20),
              velocity: Vector2(direction.x * 220, -260),
              sourceId: 'enemy.${kind.name}.$attack',
              attackTier: AttackTier.enhanced,
              gravity: 620,
              remainingBounces: 1,
              projectileRadius: 10,
              assetSlug: kind.assetSlug,
            ),
          ),
        );
    }
  }

  Future<void> _addToOwner(Component owner, Component child) async {
    await owner.add(child);
  }

  void _finishDefeat() {
    game.world.spawnDataShards(position, count: 8, corrupted: false);
    onDefeated();
    removeFromParent();
  }

  void _syncVisual() {
    final visual = _visual;
    final frames = _frames;
    if (visual == null || frames == null) return;
    final frameIndex = switch (phase) {
      CampaignChapterBossPhase.dormant => 0,
      CampaignChapterBossPhase.intro => 2 + ((_clock * 6).floor() % 2),
      CampaignChapterBossPhase.phaseOne => _pendingAttack == null ? 0 : 4,
      CampaignChapterBossPhase.phaseTwo => _pendingAttack == null ? 1 : 5,
      CampaignChapterBossPhase.phaseThree => _pendingAttack == null ? 3 : 6,
      CampaignChapterBossPhase.defeated => 7,
    };
    visual.sprite = frames[frameIndex];
    visual.position.setValues(
      size.x / 2,
      size.y / 2 + math.sin(_clock * 3.1) * 1.5,
    );
    final pulse = _pendingAttack == null
        ? 1.0
        : 1 + math.sin(_clock * 18).abs() * .07;
    visual.scale.setAll(pulse);
  }

  @override
  void render(Canvas canvas) {
    if (_visual == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7, 10, size.x - 14, size.y - 12),
          const Radius.circular(9),
        ),
        Paint()..color = kind.accentColor.withAlpha(170),
      );
    }
    if (_pendingAttack != null) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        52 + math.sin(_clock * 20).abs() * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = kind.accentColor,
      );
    }
    super.render(canvas);
  }
}
