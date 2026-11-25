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

  static Future<void> sound(
    String name, {
    double pan = 0,
    double pitch = 1,
  }) async {
    await call('sound', {
      'name': name,
      'pan': pan.clamp(-1, 1),
      'pitch': pitch.clamp(.7, 1.5),
    });
  }

  static Future<void> drive(
    bool playing, {
    String form = 'car',
    int scene = 0,
    double speed = 0,
  }) async {
    await call('drive', {
      'playing': playing,
      'form': form,
      'scene': scene,
      'speed': speed,
    });
  }

  static Future<void> music(bool play, {int track = 0}) async {
    await call('music', {'play': play, 'track': track});
  }
}
