import Flutter
import UIKit
import CoreMotion
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private let motion = CMMotionManager()
  private var sink: FlutterEventSink?
  private var sounds: [String: [AVAudioPlayer]] = [:]
  private var music: AVAudioPlayer?
  private var tracks: [AVAudioPlayer] = []
  private let keys = ["music", "effects", "fast", "scene", "best", "musicTrack", "gentleRock"]

  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    NotificationCenter.default.addObserver(self, selector: #selector(stopInBackground),
      name: UIApplication.willResignActiveNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterEventChannel(name: "little_driver/tilt", binaryMessenger: messenger).setStreamHandler(self)
    FlutterMethodChannel(name: "little_driver/platform", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "sound":
          if let name = call.arguments as? String, let players = self.sounds[name],
             let player = players.first(where: { !$0.isPlaying }) ?? players.first {
            player.currentTime = 0; player.play()
          }
          result(nil)
        case "music":
          let args = call.arguments as? [String: Any]
          let track = min(2, max(0, (args?["track"] as? NSNumber)?.intValue ?? 0))
          if args?["play"] as? Bool == true, self.tracks.indices.contains(track) {
            let player = self.tracks[track]
            if self.music !== player { self.music?.stop(); self.music = player; player.currentTime = 0 }
            self.music?.play()
          } else { self.music?.pause() }
          result(nil)
        case "load":
          var values: [String: Any] = [:]
          for key in self.keys { values[key] = UserDefaults.standard.object(forKey: "driver_" + key) }
          result(values)
        case "save":
          if let values = call.arguments as? [String: Any] {
            for key in self.keys { if let value = values[key] { UserDefaults.standard.set(value, forKey: "driver_" + key) } }
          }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    for name in ["coin", "bump", "start", "go", "finish", "pickup", "power", "guard", "horn", "transform", "smash"] {
      if let path = assetPath(name) {
        sounds[name] = (0..<3).compactMap { _ in
          let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
          player?.volume = 0.65; player?.prepareToPlay(); return player
        }
      }
    }
    for name in ["twinkle", "frere", "music"] {
      guard let path = assetPath(name), let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else { continue }
      player.numberOfLoops = -1; player.volume = 0.3; player.prepareToPlay(); tracks.append(player)
    }
  }
  private func assetPath(_ name: String) -> String? {
    let key = FlutterDartProject.lookupKey(forAsset: "assets/audio/\(name).wav")
    return Bundle.main.path(forResource: key, ofType: nil)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isAccelerometerAvailable else { return FlutterError(code: "NO_SENSOR", message: "Touch controls available", details: nil) }
    sink = events; motion.accelerometerUpdateInterval = 1.0 / 50
    motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
      if let error = error { self?.sink?(FlutterError(code: "SENSOR", message: error.localizedDescription, details: nil)); return }
      guard let a = data?.acceleration else { return }
      // Core Motion reports gravity; Android reports its opposite in m/s².
      self?.sink?([-a.x * 9.81, -a.y * 9.81, -a.z * 9.81])
    }
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopAccelerometerUpdates(); sink = nil; return nil
  }
  @objc private func stopInBackground() {
    music?.pause(); motion.stopAccelerometerUpdates()
    for players in sounds.values { for player in players { player.stop() } }
  }
}
