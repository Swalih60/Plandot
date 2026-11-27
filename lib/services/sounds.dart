import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { complete, uncheck, add, delete, tap, allDone, focusEnd }

/// Short UI sound effects (bundled, generated in-house — no licensed audio).
/// They mix with music, respect the iPhone silent switch, and can be turned
/// off in Settings.
class Sounds {
  Sounds._();
  static final instance = Sounds._();

  bool enabled = true;
  final Map<Sfx, AudioPool> _pools = {};
  bool _ready = false;

  static const _files = {
    Sfx.complete: 'sounds/complete.wav',
    Sfx.uncheck: 'sounds/uncheck.wav',
    Sfx.add: 'sounds/add.wav',
    Sfx.delete: 'sounds/delete.wav',
    Sfx.tap: 'sounds/tap.wav',
    Sfx.allDone: 'sounds/alldone.wav',
    Sfx.focusEnd: 'sounds/focusend.wav',
  };

  static const _volume = {Sfx.tap: 0.35, Sfx.uncheck: 0.5};

  Future<void> init() async {
    if (_ready) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
          respectSilence: true,
        ).build(),
      );
      for (final e in _files.entries) {
        _pools[e.key] = await AudioPool.createFromAsset(
          path: e.value,
          maxPlayers: 2,
          playerMode: PlayerMode.lowLatency,
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sounds init failed: $e');
    }
  }

  void play(Sfx s) {
    if (!enabled || !_ready) return;
    _pools[s]?.start(volume: _volume[s] ?? 0.8).catchError((Object e) {
      debugPrint('Sound failed: $e');
      return () async {};
    });
  }
}
