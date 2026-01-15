import Foundation
import SwiftData

enum MediaType: String, Codable, CaseIterable {
    case movies = "Movies"
    case books = "Books"

    var icon: String {
        switch self {
        case .movies: return "film"
        case .books: return "book"
        }
    }
}

enum VideoType: String, Codable, CaseIterable {
    case movie = "Movie"
    case tvShow = "TV Show"

    var icon: String {
        switch self {
        case .movie: return "film"
        case .tvShow: return "tv"
        }
    }
}

enum SelectedTab: Hashable {
    case media(MediaType)
    case custom(UUID)
}

enum CalendarViewMode: String, CaseIterable {
    case month = "Month"
    case week = "Week"

    var icon: String {
        switch self {
        case .month: return "calendar"
        case .week: return "calendar.day.timeline.left"
        }
    }
}

enum RecurrencePattern: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        }
    }
}

enum RecurrenceEndCondition: String, CaseIterable {
    case never = "Never"
    case onDate = "On Date"
    case afterOccurrences = "After"
}

struct TabItem: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let tab: SelectedTab

    static func mediaTab(_ type: MediaType) -> TabItem {
        TabItem(
            id: type.rawValue.lowercased(),
            title: type.rawValue,
            icon: type.icon,
            tab: .media(type)
        )
    }

    static func customTab(_ section: CustomSection) -> TabItem {
        TabItem(
            id: section.id.uuidString,
            title: section.name,
            icon: section.icon,
            tab: .custom(section.id)
        )
    }
}

@Model
final class CustomSection {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "star.fill"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortOrder: Int = 0
    var suggestedActivities: [String] = []
    var notificationsEnabled: Bool = false
    var user: User?
    @Relationship(deleteRule: .cascade, inverse: \CustomEntry.section) var entries: [CustomEntry] = []

    init(id: UUID = UUID(), name: String, icon: String = "star.fill", createdAt: Date = Date(), sortOrder: Int = 0, suggestedActivities: [String] = [], notificationsEnabled: Bool = false, user: User? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sortOrder = sortOrder
        self.suggestedActivities = suggestedActivities
        self.notificationsEnabled = notificationsEnabled
        self.user = user
        self.entries = []
    }
}

@Model
final class CustomEntry {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var endDate: Date?
    var startTime: Date?
    var endTime: Date?
    var notifyBefore: Bool = false
    var rating: Int?
    var notes: String?
    var imagesData: [Data] = []
    var section: CustomSection?
    var user: User?
    var updatedAt: Date = Date()

    // Recurrence fields
    var recurrenceGroupId: UUID?
    var recurrencePatternRaw: String?
    var recurrenceWeekdays: [Int]?
    var recurrenceEndDate: Date?
    var recurrenceOccurrenceCount: Int?
    var isRecurrenceTemplate: Bool = false

    var formattedTimeRange: String? {
        guard let start = startTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if let end = endTime {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        return formatter.string(from: start)
    }

    var recurrencePattern: RecurrencePattern? {
        get { recurrencePatternRaw.flatMap { RecurrencePattern(rawValue: $0) } }
        set { recurrencePatternRaw = newValue?.rawValue }
    }

    var isRecurring: Bool {
        recurrenceGroupId != nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        notifyBefore: Bool = false,
        rating: Int? = nil,
        notes: String? = nil,
        imagesData: [Data] = [],
        section: CustomSection? = nil,
        user: User? = nil,
        recurrenceGroupId: UUID? = nil,
        recurrencePattern: RecurrencePattern? = nil,
        recurrenceWeekdays: [Int]? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceOccurrenceCount: Int? = nil,
        isRecurrenceTemplate: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.notifyBefore = notifyBefore
        self.rating = rating
        self.notes = notes
        self.imagesData = imagesData
        self.section = section
        self.user = user
        self.recurrenceGroupId = recurrenceGroupId
        self.recurrencePatternRaw = recurrencePattern?.rawValue
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceOccurrenceCount = recurrenceOccurrenceCount
        self.isRecurrenceTemplate = isRecurrenceTemplate
        self.updatedAt = Date()
    }

    func containsDate(_ checkDate: Date) -> Bool {
        let start = date.startOfDay
        let check = checkDate.startOfDay

        if let end = endDate?.startOfDay {
            return check >= start && check <= end
        } else {
            return check == start
        }
    }
}

@Model
final class User {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "😊"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()  // Track last modification for sync
    var yearlyMovieGoal: Int = 12
    var yearlyBookGoal: Int = 12
    var tabOrder: [String] = []  // Stores tab identifiers: "movies", "books", or custom section UUID strings
    var hasCompletedOnboarding: Bool = false
    var enabledTemplates: [String] = []  // Can contain "movies", "books"
    var ownerId: String?  // InstantDB user ID - nil means local-only/legacy data
    @Relationship(deleteRule: .cascade, inverse: \MediaEntry.user) var entries: [MediaEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \CustomSection.user) var customSections: [CustomSection] = []

    init(id: UUID = UUID(), name: String, emoji: String = "😊", createdAt: Date = Date(), yearlyMovieGoal: Int = 12, yearlyBookGoal: Int = 12, ownerId: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.yearlyMovieGoal = yearlyMovieGoal
        self.yearlyBookGoal = yearlyBookGoal
        self.tabOrder = []  // Empty by default, populated during onboarding
        self.hasCompletedOnboarding = false
        self.enabledTemplates = []
        self.ownerId = ownerId
        self.entries = []
        self.customSections = []
    }
}

@Model
final class MediaEntry {
    var id: UUID = UUID()
    var title: String = ""
    var mediaTypeRaw: String = "Movies"
    var videoTypeRaw: String?
    var date: Date = Date()
    var endDate: Date?
    var imageURL: String?
    var rating: Int?
    var notes: String?
    var user: User?
    var updatedAt: Date = Date()

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .movies }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var videoType: VideoType? {
        get { videoTypeRaw.flatMap { VideoType(rawValue: $0) } }
        set { videoTypeRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        mediaType: MediaType,
        videoType: VideoType? = nil,
        date: Date,
        endDate: Date? = nil,
        imageURL: String? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        user: User? = nil
    ) {
        self.id = id
        self.title = title
        self.mediaTypeRaw = mediaType.rawValue
        self.videoTypeRaw = videoType?.rawValue
        self.date = date
        self.endDate = endDate
        self.imageURL = imageURL
        self.rating = rating
        self.notes = notes
        self.user = user
        self.updatedAt = Date()
    }

    func containsDate(_ checkDate: Date) -> Bool {
        let start = date.startOfDay
        let check = checkDate.startOfDay

        if let end = endDate?.startOfDay {
            return check >= start && check <= end
        } else {
            return check == start
        }
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameMonth(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.month, from: self) == calendar.component(.month, from: other) &&
               calendar.component(.year, from: self) == calendar.component(.year, from: other)
    }
}
