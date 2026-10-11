import Foundation

enum DisplayFormatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func storage(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else { return "Size unavailable" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func shortStorage(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "Date unavailable" }
        return Self.date.string(from: date)
    }
}
