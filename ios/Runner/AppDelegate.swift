import Flutter
import UIKit
import WidgetKit
import PDFKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var iosChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "yiclass/ios", binaryMessenger: controller.binaryMessenger)
      iosChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    }
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let group = Bundle.main.object(forInfoDictionaryKey: "YIClassAppGroup") as? String ?? ""
    let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    switch call.method {
    case "widgetStatus": result(["available": container != nil, "group": group])
    case "updateWidget":
      guard let directory = container else {
        result(FlutterError(code: "APP_GROUP", message: "签名未授权 App Group：\(group)", details: nil)); return
      }
      do {
        let data = try JSONSerialization.data(withJSONObject: call.arguments ?? [:])
        try data.write(to: directory.appendingPathComponent("timetable.json"), options: .atomic)
        WidgetCenter.shared.reloadTimelines(ofKind: "YIClassSchedule")
        result(nil)
      } catch { result(FlutterError(code: "WIDGET_WRITE", message: error.localizedDescription, details: nil)) }
    case "readPdf":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
            let pdf = PDFDocument(url: URL(fileURLWithPath: path)) else {
        result(FlutterError(code: "PDF", message: "无法读取 PDF", details: nil)); return
      }
      guard pdf.pageCount <= 30 else {
        result(FlutterError(code: "PDF", message: "请使用不超过 30 页的课表 PDF", details: nil)); return
      }
      let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n---分页---\n")
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "PDF", message: "这是扫描版 PDF，请转为图片并使用视觉模型导入", details: nil)); return
      }
      result(text)
    case "exportJson":
      guard let args = call.arguments as? [String: String], let content = args["content"],
            let name = args["name"], let controller = window?.rootViewController else {
        result(FlutterError(code: "EXPORT", message: "无法导出", details: nil)); return
      }
      do {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(URL(fileURLWithPath: name).lastPathComponent)
        try Data(content.utf8).write(to: url, options: .atomic)
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = controller.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
        sheet.completionWithItemsHandler = { _, completed, _, error in
          if let error = error { result(FlutterError(code: "EXPORT", message: error.localizedDescription, details: nil)) }
          else { result(completed ? name : nil) }
        }
        controller.present(sheet, animated: true)
      } catch { result(FlutterError(code: "EXPORT", message: error.localizedDescription, details: nil)) }
    default: result(FlutterMethodNotImplemented)
    }
  }
}
