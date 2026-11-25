import 'package:flutter/services.dart';

class GamePlatform {
  static const channel = MethodChannel('little_driver/platform');
  static const sensor = EventChannel('little_driver/tilt');
  static Future<T?> call<T>(String method, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> sound(String name) async {
    await call('sound', name);
  }

  static Future<void> music(bool play, {int track = 0}) async {
    await call('music', {'play': play, 'track': track});
  }
}
