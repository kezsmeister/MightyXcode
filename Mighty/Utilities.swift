import Foundation
import SwiftUI

// MARK: - Cached Date Formatters

/// Cached date formatters to avoid repeated allocations
enum DateFormatters {
    /// Cached ISO8601 formatter for cloud sync operations
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    /// Convert Date to ISO8601 string
    static func iso8601String(from date: Date) -> String {
        iso8601.string(from: date)
    }

    /// Parse ISO8601 string to Date
    static func date(fromISO8601 string: String) -> Date? {
        iso8601.date(from: string)
    }
}

// MARK: - Color Utilities

extension Color {
    /// Create a Color from a color name string
    static func fromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .teal
        }
    }
}
