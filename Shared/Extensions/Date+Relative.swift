import Foundation

extension Date {
    /// Short relative string, e.g. "3m", "2h", "5d", "Mar 4".
    var relativeShort: String {
        let now = Date()
        let seconds = now.timeIntervalSince(self)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d" }

        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(self, equalTo: now, toGranularity: .year)
            ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: self)
    }

    /// Full relative string used in detail screens, e.g. "3 minutes ago".
    var relativeLong: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
