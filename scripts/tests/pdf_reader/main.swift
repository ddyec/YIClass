import AppKit
import PDFKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  if !condition() { fatalError(message) }
}

func fixture(rotated: Bool) -> PDFDocument {
  let data = NSMutableData()
  let consumer = CGDataConsumer(data: data as CFMutableData)!
  var box = CGRect(x: 0, y: 0, width: rotated ? 595 : 842, height: rotated ? 842 : 595)
  let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
  for index in 0..<2 {
    context.beginPDFPage(nil)
    context.saveGState()
    if rotated {
      context.translateBy(x: 595, y: 0)
      context.rotate(by: .pi / 2)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    func draw(_ value: String, x: CGFloat, y: CGFloat) {
      (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont(name: "PingFangSC-Regular", size: 10) ?? NSFont.systemFont(ofSize: 10),
        .foregroundColor: NSColor.black
      ])
    }
    if index == 0 {
      for (day, label) in ["星期⼀", "星期⼆", "星期三", "星期四", "星期五", "星期六", "星期⽇"].enumerated() {
        draw(label, x: CGFloat(80 + day * 100), y: 540)
        draw("课程\(day + 1)", x: CGFloat(70 + day * 100), y: 500)
        draw("(1-2节)4-14周", x: CGFloat(70 + day * 100), y: 480)
      }
    } else {
      draw("续页课程", x: 170, y: 520)
      draw("(9-10节)5-11周(单)", x: 170, y: 500)
      draw("其他课程：网络课", x: 40, y: 100)
    }
    NSGraphicsContext.restoreGraphicsState()
    context.restoreGState()
    context.endPDFPage()
  }
  context.closePDF()
  let doc = PDFDocument(data: data as Data)!
  if rotated {
    for i in 0..<doc.pageCount { doc.page(at: i)!.rotation = 90 }
  }
  // Reload so CGPDFPage carries the same /Rotate entry as a real imported PDF.
  return PDFDocument(data: doc.dataRepresentation()!)!
}

check(PdfTimetableReader.normalize("星期⼀ 星期⼆ 星期⽇ ⼤学语⽂Ⅱ") == "星期一 星期二 星期日 大学语文II", "Compatibility glyphs must normalize")
for rotated in [false, true] {
  let text = PdfTimetableReader.read(fixture(rotated: rotated))
  for day in 1...7 {
    let start = "[YICLASS_COLUMN weekday=\(day)]\n"
    check(text.contains(start), "Missing weekday column, rotated=\(rotated), day=\(day)")
    let column = text.components(separatedBy: start)[1].components(separatedBy: "[/YICLASS_COLUMN]")[0]
    check(column.contains("课程\(day)"), "Course assigned to incorrect weekday")
    for other in 1...7 where other != day {
      check(!column.contains("课程\(other)"), "Adjacent weekday leaked into column")
    }
    check(column.contains("续页课程") == (day == 2), "Continuation page lost its weekday")
    check(!column.contains("网络课"), "Footer leaked into scheduled courses")
  }
  check(text.contains("其他课程"), "Unscheduled course notes lost")
}
print("PDF regression passed: compatibility glyphs, rotated pages, weekday columns, continuation and footer")
