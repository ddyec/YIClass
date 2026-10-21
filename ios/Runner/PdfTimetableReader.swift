import Foundation
import PDFKit

/// PDF text is stored in unrotated page coordinates and may contain Kangxi
/// radicals (星期⼀/星期⼆/星期⽇). Normalize both text and display geometry.
enum PdfTimetableReader {
  static func normalize(_ text: String) -> String {
    text.precomposedStringWithCompatibilityMapping
  }

  static func read(_ pdf: PDFDocument, diagnostics: Bool = false) -> String {
    var sections = [String]()
    var columns = [Int: String]()
    var previousCenters = [CGFloat]()
    for index in 0..<pdf.pageCount {
      guard let page = pdf.page(at: index) else { continue }
      let box = page.pageRef?.getBoxRect(.mediaBox) ?? page.bounds(for: .mediaBox)
      let rotated = abs(page.rotation) % 180 == 90
      let display = CGRect(x: 0, y: 0,
                           width: rotated ? box.height : box.width,
                           height: rotated ? box.width : box.height)
      let transform = page.pageRef?.getDrawingTransform(
        .mediaBox, rect: display, rotate: 0, preserveAspectRatio: true) ?? .identity
      let raw = (page.string ?? "") as NSString
      var normalized = ""
      var sourceRanges = [NSRange]()
      var offset = 0
      while offset < raw.length {
        let range = raw.rangeOfComposedCharacterSequence(at: offset)
        let text = normalize(raw.substring(with: range))
        normalized += text
        sourceRanges.append(contentsOf: Array(repeating: range, count: (text as NSString).length))
        offset = NSMaxRange(range)
      }
      func matches(_ pattern: String) -> [CGRect] {
        let regex = try! NSRegularExpression(pattern: pattern)
        var found = [CGRect]()
        for match in regex.matches(in: normalized, range: NSRange(location: 0, length: (normalized as NSString).length)) {
          let first = sourceRanges[match.range.location]
          let last = sourceRanges[NSMaxRange(match.range) - 1]
          let value = raw.substring(with: NSRange(location: first.location, length: NSMaxRange(last) - first.location))
          // PDFKit's characterBounds indices exclude synthesized line breaks,
          // unlike page.string indices. Find the original substring instead of
          // mapping NSString offsets into characterBounds(at:).
          for selection in pdf.findString(value, withOptions: []) where selection.pages.contains(page) {
            let bounds = selection.bounds(for: page).applying(transform)
            if !bounds.isEmpty && !found.contains(bounds) { found.append(bounds) }
          }
        }
        return found
      }
      let labels = ["一", "二", "三", "四", "五", "六", "[日天]"]
      let candidates = labels.map { matches("(?:星\\s*期|周)\\s*\($0)") }
      if diagnostics {
        let info = "Page \(index): rotation=\(page.rotation) box=\(box) transform=\(transform)\n" +
          "Text=\(normalized.prefix(300))\nCandidates=\(candidates)\n"
        FileHandle.standardOutput.write(Data(info.utf8))
      }
      // Pick a single aligned header row; mentions of weekdays in notes do not
      // invalidate a real table header.
      var headers = [CGRect]()
      for first in candidates[0] {
        let row = candidates.map { options in
          options.first { abs($0.midY - first.midY) < max(15, first.height) }
        }
        if row.allSatisfy({ $0 != nil }) {
          let found = row.map { $0! }
          if zip(found, found.dropFirst()).allSatisfy({ $0.0.midX < $0.1.midX }) {
            headers = found
            break
          }
        }
      }
      let hasHeader = headers.count == 7
      let centers = hasHeader ? headers.map { $0.midX / display.width } : previousCenters
      guard centers.count == 7 else {
        sections.append(normalize(page.string ?? ""))
        continue
      }
      previousCenters = centers
      let top = hasHeader ? headers.map { $0.minY }.min()! : display.maxY
      let footer = matches("其\\s*他\\s*课\\s*程").first
      let bottom = footer.map { $0.maxY + 1 } ?? display.minY
      for i in 0..<7 {
        let center = centers[i] * display.width
        let left = i == 0 ? center - (centers[1] * display.width - center) / 2
          : (centers[i - 1] * display.width + center) / 2
        let right = i == 6 ? center + (center - centers[5] * display.width) / 2
          : (center + centers[i + 1] * display.width) / 2
        let rect = CGRect(x: left + 0.5, y: bottom, width: right - left - 1, height: max(0, top - bottom))
        let content = page.selection(for: rect.applying(transform.inverted()))?.string ?? ""
        columns[i + 1, default: ""] += "\n" + normalize(content)
      }
      if let footer = footer {
        let rect = CGRect(x: display.minX, y: display.minY, width: display.width, height: footer.maxY - display.minY)
        sections.append(normalize(page.selection(for: rect.applying(transform.inverted()))?.string ?? ""))
      }
    }
    for day in columns.keys.sorted() {
      sections.append("[YICLASS_COLUMN weekday=\(day)]\n\(columns[day]!)\n[/YICLASS_COLUMN]")
    }
    return sections.joined(separator: "\n---分页---\n")
  }

}
