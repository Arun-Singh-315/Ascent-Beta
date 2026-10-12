import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AscentDeviceTimeZone") {
      let channel = FlutterMethodChannel(name: "ascent/device-timezone", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "getTimeZone" { result(TimeZone.current.identifier) }
        else { result(FlutterMethodNotImplemented) }
      }
    }
  }
}
