import SwiftUI
import SwiftData

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTab: SelectedTab
    let mediaEntries: [MediaEntry]
    let customEntries: [CustomEntry]
    let customSections: [CustomSection]
    let onDayTap: (Date) -> Void

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2
        return cal
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 12) {
            weekdayHeader
            calendarGrid
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth(), id: \.self) { date in
                if let date = date {
                    let cellData = entryDataFor(date: date)
                    DayCell(
                        date: date,
                        isToday: calendar.isDateInToday(date),
                        isFuture: date.startOfDay > Date().startOfDay,
                        isSelected: date.isSameDay(as: selectedDate),
                        cellData: cellData
                    )
                    .onTapGesture {
                        selectedDate = date
                        onDayTap(date)
                    }
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        let startOfMonth = selectedDate.startOfMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)!.count

        var days: [Date?] = []

        // Calculate offset for Monday-first calendar
        // Sunday = 1, Monday = 2, ... Saturday = 7
        // For Mon-first: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
        let offset = (firstWeekday + 5) % 7

        // Add empty cells for days before the first of the month
        for _ in 0..<offset {
            days.append(nil)
        }

        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func entryDataFor(date: Date) -> DayCellData? {
        switch selectedTab {
        case .media(let mediaType):
            let matchingEntries = mediaEntries.filter { $0.containsDate(date) && $0.mediaType == mediaType }
            if let entry = matchingEntries.first {
                let additionalCount = matchingEntries.count - 1
                let additionalIcons = matchingEntries.dropFirst().prefix(2).map { $0.videoType?.icon ?? $0.mediaType.icon }
                return DayCellData(
                    title: entry.title,
                    icon: entry.videoType?.icon ?? entry.mediaType.icon,
                    imageURL: entry.imageURL,
                    isCustom: false,
                    activityColors: nil,
                    hasConflict: false,
                    additionalCount: additionalCount,
                    additionalIcons: Array(additionalIcons)
                )
            }
        case .custom(let sectionId):
            // Filter out recurrence templates - they're master records, not actual scheduled activities
            let matchingEntries = customEntries.filter { $0.containsDate(date) && $0.section?.id == sectionId && !$0.isRecurrenceTemplate }
            if let entry = matchingEntries.first {
                let additionalCount = matchingEntries.count - 1
                let activityIcon = ActivityIconService.icon(for: entry.title)
                let activityColors = ActivityIconService.colors(for: entry.title)
                // Collect icons from additional activities (up to 2 more)
                let additionalIcons = matchingEntries.dropFirst().prefix(2).map { ActivityIconService.icon(for: $0.title) }
                // Check if any entry on this date has a conflict
                let sectionEntries = customEntries.filter { $0.section?.id == sectionId }
                let conflictingIds = ConflictDetectionService.shared.entriesWithConflicts(on: date, allEntries: sectionEntries)
                let hasConflict = matchingEntries.contains { conflictingIds.contains($0.id) }
                return DayCellData(
                    title: entry.title,
                    icon: activityIcon,
                    imageURL: nil,
                    isCustom: true,
                    activityColors: activityColors,
                    hasConflict: hasConflict,
                    additionalCount: additionalCount,
                    additionalIcons: Array(additionalIcons)
                )
            }
        }
        return nil
    }
}

struct DayCellData {
    let title: String
    let icon: String
    let imageURL: String?
    let isCustom: Bool
    let activityColors: (primary: String, secondary: String)?
    let hasConflict: Bool
    let additionalCount: Int
    let additionalIcons: [String]
    let participantEmojis: [String]

    init(title: String, icon: String, imageURL: String?, isCustom: Bool, activityColors: (primary: String, secondary: String)?, hasConflict: Bool, additionalCount: Int = 0, additionalIcons: [String] = [], participantEmojis: [String] = []) {
        self.title = title
        self.icon = icon
        self.imageURL = imageURL
        self.isCustom = isCustom
        self.activityColors = activityColors
        self.hasConflict = hasConflict
        self.additionalCount = additionalCount
        self.additionalIcons = additionalIcons
        self.participantEmojis = participantEmojis
    }
}

struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let cellData: DayCellData?

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
                .overlay(
                    // Diagonal lines pattern for future dates
                    isFuture && cellData == nil ?
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    : nil
                )

            if let data = cellData {
                if let imageURL = data.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        case .failure(_):
                            placeholderWithDay
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholderWithDay
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        dayNumber
                            .padding(4)
                    }
                    .overlay(alignment: .topTrailing) {
                        if data.additionalCount > 0 {
                            additionalCountBadge(count: data.additionalCount)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if data.hasConflict {
                            conflictIndicator
                        }
                    }
                } else {
                    placeholderImage(for: data)
                        .overlay(alignment: .topLeading) {
                            dayNumber
                                .padding(4)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if data.hasConflict {
                                conflictIndicator
                            }
                        }
                }
            } else {
                placeholderWithDay
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var conflictIndicator: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.orange)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 16, height: 16)
            )
            .padding(2)
    }

    private func additionalCountBadge(count: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.purple)
            )
            .padding(3)
    }

    private var backgroundColor: Color {
        if isToday {
            return Color.purple.opacity(0.3)
        }
        if isFuture {
            return Color(white: 0.08)
        }
        return Color(white: 0.15)
    }

    private var dayNumber: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .shadow(color: .black, radius: 2)
    }

    private var placeholderWithDay: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isFuture ? .gray.opacity(0.5) : .white)
    }

    private func placeholderImage(for data: DayCellData) -> some View {
        ZStack {
            LinearGradient(
                colors: gradientColors(for: data),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(spacing: 2) {
                // Icon with +N badge next to it
                HStack(spacing: 2) {
                    Image(systemName: data.icon)
                        .font(.system(size: 12, weight: .medium))
                    if data.additionalCount > 0 {
                        Text("+\(data.additionalCount)")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                Text(String(data.title.prefix(8)))
                    .font(.system(size: 8))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
        }
    }

    private func gradientColors(for data: DayCellData) -> [Color] {
        if data.isCustom, let colors = data.activityColors {
            return [colorFromName(colors.primary).opacity(0.7), colorFromName(colors.secondary).opacity(0.7)]
        }
        return data.isCustom
            ? [.green.opacity(0.6), .teal.opacity(0.6)]
            : [.purple.opacity(0.6), .blue.opacity(0.6)]
    }

    private func colorFromName(_ name: String) -> Color {
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
