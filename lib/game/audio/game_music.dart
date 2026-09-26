import 'package:flutter/services.dart';

class GameMusic {
  static const _channel = MethodChannel('system_fallen/music');
  static const _generalTrack = 'assets/audio/general_exploration.mp3';
  static const _voltTrack = 'assets/audio/boss_volt.mp3';

  String? _currentTrack;
  bool _disposed = false;

  Future<void> playGeneral() => _play(_generalTrack, 0.30);

  Future<void> playVolt() => _play(_voltTrack, 0.42);

  Future<void> _play(String asset, double volume) async {
    if (_disposed || _currentTrack == asset) return;
    _currentTrack = asset;
    await _invoke('play', {'asset': asset, 'volume': volume});
  }

  Future<void> pause() => _invoke('pause');

  Future<void> resume() => _invoke('resume');

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _currentTrack = null;
    await _invoke('stop');
  }

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Desktop tests and unsupported platforms run silently without music.
    } on PlatformException {
      // A music failure must never interrupt gameplay.
    }
  }
}
