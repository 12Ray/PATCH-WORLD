import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

final class AudioService {
  bool _preloaded = false;
  bool _unlocked = false;
  bool _bgmPlaying = false;
  bool _available = true;
  double _bgmVolume = 0.55;
  double _sfxVolume = 0.80;
  AudioPool? _patchPulsePool;
  AudioPool? _damagePool;

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

  void setBgmVolume(double value) => _bgmVolume = value.clamp(0, 1);
  void setSfxVolume(double value) => _sfxVolume = value.clamp(0, 1);

  Future<void> dispose() async {
    await FlameAudio.bgm.stop();
    _bgmPlaying = false;
    await _patchPulsePool?.dispose();
    await _damagePool?.dispose();
  }
}
