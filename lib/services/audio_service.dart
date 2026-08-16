import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

final class AudioService {
  bool _preloaded = false;
  bool _unlocked = false;
  bool _bgmPlaying = false;
  bool _available = true;
  double _bgmVolume = 0.55;
  double _sfxVolume = 0.80;
  AudioPool? _patchPulsePool;
  AudioPool? _damagePool;
  final Map<String, AudioPool> _sfxPools = <String, AudioPool>{};

  bool get isUnlocked => _unlocked;
  bool get isAvailable => _available;

  Future<void> preloadSafely() async {
    try {
      await preload();
    } catch (_) {
      _available = false;
    }
  }

  Future<void> preload() async {
    if (_preloaded) return;
    await FlameAudio.audioCache.loadAll(<String>[
      'bgm/archive_hum.wav',
      'bgm/optimizer_layer.wav',
      'sfx/patch_pulse.wav',
      'sfx/damage.wav',
      'sfx/heal.wav',
      'sfx/overflow_warning.wav',
      'sfx/overflow_blast.wav',
      'sfx/time_freeze.wav',
      'sfx/frame_burst.wav',
      'sfx/terminal.wav',
      'sfx/ui_confirm.wav',
      'sfx/jump.wav',
      'sfx/double_jump.wav',
      'sfx/land.wav',
      'sfx/sword_slash.wav',
      'sfx/sword_dash.wav',
      'sfx/gauntlet_hit.wav',
      'sfx/gun_shot.wav',
      'sfx/gun_rail.wav',
      'sfx/platform_break.wav',
      'sfx/jump_pad.wav',
      'sfx/laser_fire.wav',
      'sfx/crusher_impact.wav',
      'sfx/checkpoint.wav',
      'sfx/enemy_melee.wav',
      'sfx/enemy_projectile.wav',
      'sfx/enemy_field.wav',
      'sfx/enemy_boss.wav',
    ]);
    _patchPulsePool = await FlameAudio.createPool(
      'sfx/patch_pulse.wav',
      minPlayers: 3,
      maxPlayers: 8,
    );
    _damagePool = await FlameAudio.createPool(
      'sfx/damage.wav',
      minPlayers: 2,
      maxPlayers: 6,
    );
    for (final entry in <String, String>{
      'jump': 'sfx/jump.wav',
      'doubleJump': 'sfx/double_jump.wav',
      'land': 'sfx/land.wav',
      'sword': 'sfx/sword_slash.wav',
      'swordDash': 'sfx/sword_dash.wav',
      'gauntlet': 'sfx/gauntlet_hit.wav',
      'gun': 'sfx/gun_shot.wav',
      'gunRail': 'sfx/gun_rail.wav',
      'enemyMelee': 'sfx/enemy_melee.wav',
      'enemyProjectile': 'sfx/enemy_projectile.wav',
      'enemyField': 'sfx/enemy_field.wav',
      'enemyBoss': 'sfx/enemy_boss.wav',
    }.entries) {
      _sfxPools[entry.key] = await FlameAudio.createPool(
        entry.value,
        minPlayers: 1,
        maxPlayers: entry.key.startsWith('enemy') ? 6 : 4,
      );
    }
    _preloaded = true;
  }

  Future<void> unlockFromUserGesture() async {
    if (_unlocked || !_available) return;
    _unlocked = true;
    try {
      await startArchiveBgm();
    } catch (_) {
      _available = false;
      _bgmPlaying = false;
    }
  }

  Future<void> startArchiveBgm({bool restart = false}) async {
    if (!_unlocked || !_available) return;
    if (_bgmPlaying && !restart) return;
    if (_bgmPlaying) await FlameAudio.bgm.stop();
    _bgmPlaying = true;
    await FlameAudio.bgm.play('bgm/archive_hum.wav', volume: _bgmVolume);
  }

  Future<void> startOptimizerBgm() async {
    if (!_unlocked || !_available) return;
    try {
      await FlameAudio.bgm.stop();
      _bgmPlaying = true;
      await FlameAudio.bgm.play('bgm/optimizer_layer.wav', volume: _bgmVolume);
    } catch (_) {
      _available = false;
      _bgmPlaying = false;
    }
  }

  Future<void> playPatchPulse() async {
    if (_unlocked && _available) {
      await _patchPulsePool?.start(volume: _sfxVolume);
    }
  }

  Future<void> playDamage() async {
    if (_unlocked && _available) {
      await _damagePool?.start(volume: _sfxVolume);
    }
  }

  Future<void> playHeal() async {
    if (!_unlocked || !_available) return;
    try {
      await FlameAudio.play('sfx/heal.wav', volume: _sfxVolume);
    } catch (_) {
      _available = false;
    }
  }

  Future<void> playJump({bool doubleJump = false}) =>
      _playPooled(doubleJump ? 'doubleJump' : 'jump', volume: 0.72);

  Future<void> playLand() => _playPooled('land', volume: 0.50);

  Future<void> playSwordDash() => _playPooled('swordDash', volume: 0.82);

  Future<void> playWeaponAttack(PlayerWeapon weapon, {bool heavy = false}) =>
      _playPooled(switch (weapon) {
        PlayerWeapon.sword => 'sword',
        PlayerWeapon.gauntlet => 'gauntlet',
        PlayerWeapon.gun => heavy ? 'gunRail' : 'gun',
      }, volume: heavy ? 0.88 : 0.74);

  Future<void> playWeaponImpact(PlayerWeapon weapon, {bool heavy = false}) =>
      _playPooled(switch (weapon) {
        PlayerWeapon.sword => 'sword',
        PlayerWeapon.gauntlet => 'gauntlet',
        PlayerWeapon.gun => heavy ? 'gunRail' : 'gun',
      }, volume: heavy ? .62 : .42);

  Future<void> playPlatformBreak() =>
      _playOneShot('sfx/platform_break.wav', volume: 0.72);

  Future<void> playJumpPad() => _playOneShot('sfx/jump_pad.wav', volume: 0.70);

  Future<void> playLaserFire() =>
      _playOneShot('sfx/laser_fire.wav', volume: 0.58);

  Future<void> playCrusherImpact() =>
      _playOneShot('sfx/crusher_impact.wav', volume: 0.68);

  Future<void> playCheckpoint() =>
      _playOneShot('sfx/checkpoint.wav', volume: 0.72);

  Future<void> playEnemyAttack(String actionId) {
    final poolKey = switch (actionId) {
      final value
          when value.contains('warden') ||
              value.contains('Jailer') ||
              value.contains('Chimera') =>
        'enemyBoss',
      final value
          when value.contains('bite') ||
              value.contains('Lunge') ||
              value.contains('dash') ||
              value.contains('Charge') ||
              value.contains('slam') ||
              value.contains('impact') =>
        'enemyMelee',
      final value
          when value.contains('Field') ||
              value.contains('field') ||
              value.contains('rewind') ||
              value.contains('Cage') ||
              value.contains('polarity') =>
        'enemyField',
      _ => 'enemyProjectile',
    };
    return _playPooled(poolKey, volume: 0.58);
  }

  Future<void> _playPooled(String key, {required double volume}) async {
    if (!_unlocked || !_available) return;
    try {
      await _sfxPools[key]?.start(volume: _sfxVolume * volume);
    } catch (_) {
      // One failed voice should not disable music or the remaining SFX pools.
    }
  }

  Future<void> _playOneShot(String path, {required double volume}) async {
    if (!_unlocked || !_available) return;
    try {
      await FlameAudio.play(path, volume: _sfxVolume * volume);
    } catch (_) {
      // Keep the audio service available when a single optional cue fails.
    }
  }

  void setBgmVolume(double value) => _bgmVolume = value.clamp(0, 1);
  void setSfxVolume(double value) => _sfxVolume = value.clamp(0, 1);

  Future<void> dispose() async {
    await FlameAudio.bgm.stop();
    _bgmPlaying = false;
    await _patchPulsePool?.dispose();
    await _damagePool?.dispose();
    for (final pool in _sfxPools.values) {
      await pool.dispose();
    }
    _sfxPools.clear();
  }
}
