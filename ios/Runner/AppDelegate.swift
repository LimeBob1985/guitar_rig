import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController

    let channel = FlutterMethodChannel(
      name: "audio_channel",
      binaryMessenger: controller.binaryMessenger
    )

    AudioEngine.shared.setFlutterChannel(channel)

    channel.setMethodCallHandler { call, result in
      switch call.method {

      case "start":
        AudioEngine.shared.start()
        result(nil)

      case "setGain":
        if let args = call.arguments as? [String: Any],
           let value = args["value"] as? Double {
          AudioEngine.shared.setExternalGain(Float(value))
        }
        result(nil)

      case "setMixer":
        if let args = call.arguments as? [String: Any],
           let name = args["name"] as? String,
           let value = args["value"] as? Double {
          AudioEngine.shared.setMixerParam(name: name, value: Float(value))
        }
        result(nil)

      case "setPedal":
        if let args = call.arguments as? [String: Any],
           let name = args["name"] as? String,
           let value = args["value"] as? Double {
          AudioEngine.shared.setPedalValue(name: name, value: Float(value))
        }
        result(nil)

      case "setPedalEQ":
        if let args = call.arguments as? [String: Any],
           let pedal = args["pedal"] as? String,
           let band = args["band"] as? String,
           let value = args["value"] as? Double {
          AudioEngine.shared.setPedalEQ(pedal: pedal, band: band, value: Float(value))
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
