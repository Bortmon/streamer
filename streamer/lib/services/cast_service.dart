import 'package:flutter/services.dart';

class CastService {
  static const MethodChannel _channel = MethodChannel('com.example.streamer/cast');

  Future<void> castVideo(String url) async {
    try {
      print('Flutter roept native "castVideo" aan met URL: $url');
      await _channel.invokeMethod('castVideo', {'url': url});
    } on PlatformException catch (e) {
      print("Fout bij het aanroepen van native cast: ${e.message}");
    }
  }
}