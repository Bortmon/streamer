import 'package:flutter/services.dart';

class CastService {
  static const MethodChannel _channel = MethodChannel('com.example.streamer/cast');

  Future<void> startSmartCasting(String url) async {
    try {
      await _channel.invokeMethod('startSmartCasting', {'url': url});
    } on PlatformException catch (e) {
      print("Fout bij het starten van smart casting: ${e.message}");
    }
  }
}