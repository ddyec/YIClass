import SwiftUI
import WidgetKit

struct Lesson: Identifiable {
  let id: String
  let name: String
  let location: String
  let start: Date
  let end: Date
}

struct ScheduleEntry: TimelineEntry {
  let date: Date
  let lessons: [Lesson]
  let message: String
}

struct ScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ScheduleEntry {
    let now = Date()
    return ScheduleEntry(date: now, lessons: [Lesson(id: "preview", name: "下一节课程", location: "教学楼 · 教室", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(4500))], message: "")
  }

  func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
    if context.isPreview { completion(placeholder(in: context)); return }
    let (lessons, message) = loadLessons()
    completion(entry(at: Date(), lessons: lessons, message: message))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
    let now = Date()
    let calendar = Calendar.current
    let horizon = calendar.date(byAdding: .day, value: 8, to: now)!
    let (lessons, message) = loadLessons()
    var dates = Set<Date>([now])
    // Share the whole semester and precompute transitions. No daily app launch.
    for lesson in lessons {
      if lesson.start > now && lesson.start < horizon { dates.insert(lesson.start) }
      if lesson.end > now && lesson.end < horizon { dates.insert(lesson.end) }
    }
    for day in 1...8 {
      if let date = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)) { dates.insert(date) }
    }
    completion(Timeline(entries: dates.sorted().map { entry(at: $0, lessons: lessons, message: message) }, policy: .after(horizon)))
  }

  private func entry(at date: Date, lessons: [Lesson], message: String) -> ScheduleEntry {
    ScheduleEntry(date: date, lessons: Array(lessons.filter { $0.end > date }.prefix(4)), message: message)
  }

  private func loadLessons() -> ([Lesson], String) {
    guard let directory = SharedGroup.container()?.url else {
      return ([], "签名需授权共享 App Group")
    }
    guard let data = try? Data(contentsOf: directory.appendingPathComponent("timetable.json")),
          let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let settings = root["settings"] as? [String: Any],
          let startString = settings["startDate"] as? String,
          let courses = root["courses"] as? [[String: Any]],
          let times = settings["classTimes"] as? [[String: Any]] else {
      return ([], "请先打开 YIClass 并导入课表")
    }
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    guard let start = formatter.date(from: String(startString.prefix(10))) else { return ([], "学期日期无效") }
    let weekday = calendar.component(.weekday, from: start)
    let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: start)!
    let holidays = Set((settings["holidays"] as? [String] ?? []).map { String($0.prefix(10)) })
    var lessons = [Lesson]()
    func clock(_ day: Date, _ value: String?) -> Date? {
      guard let parts = value?.split(separator: ":"), parts.count == 2,
            let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
      return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }
    for (ci, course) in courses.enumerated() {
      for (si, schedule) in (course["schedules"] as? [[String: Any]] ?? []).enumerated() {
        guard let day = schedule["weekday"] as? Int, let periods = schedule["periods"] as? [Int],
              let weeks = schedule["weekPattern"] as? [Int] else { continue }
        var runs = [[Int]]()
        for p in periods.sorted() {
          if let last = runs.last?.last, p == last + 1 { runs[runs.count - 1].append(p) }
          else { runs.append([p]) }
        }
        for week in weeks {
          guard let date = calendar.date(byAdding: .day, value: (week - 1) * 7 + day - 1, to: monday),
                !holidays.contains(formatter.string(from: date)) else { continue }
          for run in runs {
            let first = times.first { ($0["period"] as? Int) == run.first }
            let last = times.first { ($0["period"] as? Int) == run.last }
            guard let begin = clock(date, first?["startTime"] as? String),
                  let end = clock(date, last?["endTime"] as? String), end > begin else { continue }
            lessons.append(Lesson(id: "\(ci)-\(si)-\(week)-\(run[0])", name: course["name"] as? String ?? "课程",
              location: course["location"] as? String ?? "", start: begin, end: end))
          }
        }
      }
    }
    lessons.sort { $0.start < $1.start }
    return (lessons, "学期暂无后续课程")
  }
}

struct ScheduleWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: ScheduleEntry
  var content: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(entry.lessons.first.map { $0.start <= entry.date ? "正在上课" : "下一节" } ?? "YIClass")
          .font(.caption.weight(.semibold)).foregroundColor(.blue)
        Spacer()
        Text(entry.lessons.first?.start ?? entry.date, format: .dateTime.month().day())
          .font(.caption2).foregroundColor(.secondary)
      }
      if let next = entry.lessons.first {
        Text(next.name).font(.headline).lineLimit(family == .systemSmall ? 2 : 1)
        HStack(spacing: 3) {
          Text(next.start, style: .time)
          Text("–")
          Text(next.end, style: .time)
        }.font(.subheadline.monospacedDigit())
        Text(next.location.isEmpty ? "地点待定" : next.location).font(.caption).lineLimit(1)
        if family == .systemMedium {
          ForEach(Array(entry.lessons.dropFirst().prefix(2))) { lesson in
            HStack {
              Text(lesson.start, format: .dateTime.day().hour().minute()).font(.caption.monospacedDigit()).foregroundColor(.secondary)
              Text(lesson.name).font(.caption).lineLimit(1)
              Spacer(minLength: 0)
            }
          }
        }
      } else {
        Spacer()
        Text(entry.message).font(.subheadline)
        Spacer()
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .widgetURL(URL(string: "yiclass://schedule"))
  }
  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(.background, for: .widget)
    } else {
      content.padding().background(Color(UIColor.systemBackground))
    }
  }
}

@main
struct ScheduleWidget: Widget {
  let kind = "YIClassSchedule"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in ScheduleWidgetView(entry: entry) }
    .configurationDisplayName("下节课与今日课表")
    .description("在主屏幕查看课程、时间和地点。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
