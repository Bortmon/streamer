import 'package:flutter/services.dart';

class CastService {
  static const MethodChannel _channel = MethodChannel('com.example.streamer/cast');

  Future<void> startSmartCasting(String url, String title, List<Map<String, String>> subtitles) async {
    try {
      await _channel.invokeMethod('startSmartCasting', {
        'url': url,
        'title': title,
        'subtitles': subtitles,
      });
    } on PlatformException catch (e) {
      print('Error starting cast: ${e.message}');
    }
  }

  Future<void> setActiveSubtitle(int trackId) async {
    try {
      await _channel.invokeMethod('setActiveSubtitle', {'trackId': trackId});
    } on PlatformException catch (e) {
      print('Error setting active subtitle: ${e.message}');
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } on PlatformException catch (e) {
      print('Error playing: ${e.message}');
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException catch (e) {
      print('Error pausing: ${e.message}');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      print('Error stopping: ${e.message}');
    }
  }

  Future<void> seekTo(double position) async {
    try {
      await _channel.invokeMethod('seekTo', {'position': position});
    } on PlatformException catch (e) {
      print('Error seeking: ${e.message}');
    }
  }

  Future<void> skipForward(int seconds) async {
    try {
      await _channel.invokeMethod('skipForward', {'seconds': seconds});
    } on PlatformException catch (e) {
      print('Error skipping forward: ${e.message}');
    }
  }

  Future<void> skipBackward(int seconds) async {
    try {
      await _channel.invokeMethod('skipBackward', {'seconds': seconds});
    } on PlatformException catch (e) {
      print('Error skipping backward: ${e.message}');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print('Error setting volume: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      print('Error disconnecting: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('Error getting status: ${e.message}');
      return null;
    }
  }
}