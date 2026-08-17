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

    let channel = FlutterMethodChannel(
      name: "com.example.wikiman_app/heic",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "convertToPng" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_PATH",
            message: "변환할 파일 경로가 없습니다.",
            details: nil
          )
        )
        return
      }

      do {
        result(try Self.convertHeicToPng(path: path))
      } catch {
        result(
          FlutterError(
            code: "CONVERT_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private static func convertHeicToPng(path: String) throws -> String {
    guard FileManager.default.fileExists(atPath: path) else {
      throw NSError(
        domain: "wikiman.heic",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "변환할 HEIC 파일을 찾을 수 없습니다."]
      )
    }

    guard let image = UIImage(contentsOfFile: path) else {
      throw NSError(
        domain: "wikiman.heic",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "HEIC 이미지를 읽지 못했습니다."]
      )
    }

    guard let pngData = image.pngData() else {
      throw NSError(
        domain: "wikiman.heic",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "PNG로 변환하지 못했습니다."]
      )
    }

    let outUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("heic-\(Int(Date().timeIntervalSince1970 * 1000)).png")
    try pngData.write(to: outUrl, options: .atomic)
    return outUrl.path
  }
}
