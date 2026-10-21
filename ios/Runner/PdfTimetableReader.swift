import Foundation
import PDFKit

/// PDF text is stored in unrotated page coordinates and may contain Kangxi
/// radicals (星期⼀/星期⼆/星期⽇). Normalize both text and display geometry.
enum PdfTimetableReader {
  struct Glyph {
    let text: String
    let bounds: CGRect
  }

  static func normalize(_ text: String) -> String {
    text.precomposedStringWithCompatibilityMapping
  }

  static func read(_ pdf: PDFDocument) -> String {
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
      var glyphs = [Glyph]()
      var normalized = ""
      var origins = [CGRect]()
      var offset = 0
      while offset < raw.length {
        let range = raw.rangeOfComposedCharacterSequence(at: offset)
        let text = normalize(raw.substring(with: range))
        var bounds = CGRect.null
        for i in range.location..<NSMaxRange(range) {
          let charBox = page.characterBounds(at: i)
          if !charBox.isEmpty { bounds = bounds.union(charBox.applying(transform)) }
        }
        normalized += text
        origins.append(contentsOf: Array(repeating: bounds, count: (text as NSString).length))
        if !bounds.isNull && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          glyphs.append(Glyph(text: text, bounds: bounds))
        }
        offset = NSMaxRange(range)
      }
      func matches(_ pattern: String) -> [CGRect] {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: normalized, range: NSRange(location: 0, length: (normalized as NSString).length))
          .map { match in
            origins[match.range.location..<NSMaxRange(match.range)]
              .reduce(CGRect.null) { $0.union($1) }
          }.filter { !$0.isNull && !$0.isEmpty }
      }
      let labels = ["一", "二", "三", "四", "五", "六", "[日天]"]
      let candidates = labels.map { matches("(?:星\\s*期|周)\\s*\($0)") }
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
        let selected = glyphs.filter {
          $0.bounds.midX >= left && $0.bounds.midX < right &&
          $0.bounds.midY < top && $0.bounds.midY >= bottom
        }
        columns[i + 1, default: ""] += "\n" + lines(selected)
      }
      if let footer = footer {
        sections.append(lines(glyphs.filter { $0.bounds.midY <= footer.maxY }))
      }
    }
    for day in columns.keys.sorted() {
      sections.append("[YICLASS_COLUMN weekday=\(day)]\n\(columns[day]!)\n[/YICLASS_COLUMN]")
    }
    return sections.joined(separator: "\n---分页---\n")
  }

  private static func lines(_ glyphs: [Glyph]) -> String {
    var rows = [[Glyph]]()
    for glyph in glyphs.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
      if let last = rows.last, let first = last.first,
         abs(first.bounds.midY - glyph.bounds.midY) < max(2, first.bounds.height * 0.45) {
        rows[rows.count - 1].append(glyph)
      } else {
        rows.append([glyph])
      }
    }
    return rows.map { row in
      let sorted = row.sorted { $0.bounds.minX < $1.bounds.minX }
      var text = ""
      var previous: CGRect?
      for glyph in sorted {
        if let previous = previous, glyph.bounds.minX - previous.maxX > glyph.bounds.height * 0.35 {
          text += " "
        }
        text += glyph.text
        previous = glyph.bounds
      }
      return text
    }.joined(separator: "\n")
  }
}
