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
    let shared = SharedGroup.container()
    let group = shared?.identifier ?? (Bundle.main.object(forInfoDictionaryKey: "YIClassAppGroup") as? String ?? "")
    let container = shared?.url
    switch call.method {
    case "widgetStatus": result(["available": container != nil, "group": group])
    case "updateWidget":
      guard let directory = container else {
        result(FlutterError(code: "APP_GROUP", message: "签名未授权 App Group：\(group)", details: nil)); return
      }
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
      // PDF string reading order can interleave neighboring timetable columns.
      // Crop each weekday spatially before sending text to the model.
      var sections = [String]()
      var previousHeaders = [(day: Int, bounds: CGRect)]()
      var columnText = [Int: String]()
      let labels = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
      for index in 0..<pdf.pageCount {
        guard let page = pdf.page(at: index) else { continue }
        var headers = [(day: Int, bounds: CGRect)]()
        for (day, label) in labels.enumerated() {
          for selection in pdf.findString(label, withOptions: []) where selection.pages.contains(page) {
            headers.append((day + 1, selection.bounds(for: page)))
          }
        }
        // Only treat a complete horizontal weekday header as a table.
        let hasHeader = headers.count == 7
        let sorted = (hasHeader ? headers : previousHeaders).sorted { $0.bounds.midX < $1.bounds.midX }
        if sorted.count == 7 && Set(sorted.map { $0.day }).count == 7 &&
            (sorted.map { $0.bounds.midY }.max()! - sorted.map { $0.bounds.midY }.min()!) < 15 {
          let box = page.bounds(for: .mediaBox)
          previousHeaders = sorted
          let rowBottom = hasHeader ? sorted.map { $0.bounds.minY }.min()! : box.maxY
          let footer = pdf.findString("其他课程", withOptions: []).first { $0.pages.contains(page) }?.bounds(for: page)
          let bodyBottom = footer.map { $0.maxY + 1 } ?? box.minY
          for i in sorted.indices {
            let center = sorted[i].bounds.midX
            let left = i == 0 ? center - (sorted[1].bounds.midX - center) / 2 : (sorted[i-1].bounds.midX + center) / 2
            let right = i == 6 ? center + (center - sorted[5].bounds.midX) / 2 : (center + sorted[i+1].bounds.midX) / 2
            let rect = CGRect(x: left + 1, y: bodyBottom, width: right - left - 2, height: rowBottom - bodyBottom)
            columnText[sorted[i].day, default: ""] += "\n" + (page.selection(for: rect)?.string ?? "")
          }
          if let footer = footer {
            sections.append(page.selection(for: CGRect(x: box.minX, y: box.minY, width: box.width, height: footer.maxY - box.minY))?.string ?? "")
          }
        } else {
          sections.append(page.string ?? "")
        }
      }
      for day in columnText.keys.sorted() {
        sections.append("[YICLASS_COLUMN weekday=\(day)]\n\(columnText[day]!)\n[/YICLASS_COLUMN]")
      }
      let text = sections.joined(separator: "\n---分页---\n")
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
