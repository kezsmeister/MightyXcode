import SwiftUI
import SwiftData

struct WeeklyScheduleView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTab: SelectedTab
    let mediaEntries: [MediaEntry]
    let customEntries: [CustomEntry]
    let customSections: [CustomSection]
    let onDayTap: (Date) -> Void
    let onActivityTap: ((CustomEntry) -> Void)?

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2
        return cal
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 8) {
            weekdayHeader
            dateRow
            Divider()
                .background(Color.gray.opacity(0.3))
            activitiesGrid
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Week Header
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

    // MARK: - Date Row
    private var dateRow: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekDates, id: \.self) { date in
                WeekDateCell(
                    date: date,
                    isToday: calendar.isDateInToday(date),
                    isSelected: date.isSameDay(as: selectedDate),
                    hasActivities: !entriesFor(date: date).isEmpty
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onDayTap(date)
                    }
                }
            }
        }
    }

    // MARK: - Activities Grid
    private var activitiesGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 4) {
                        let entries = entriesFor(date: date)
                        ForEach(entries) { entry in
                            WeekActivityCard(entry: entry) {
                                onActivityTap?(entry)
                            }
                        }

                        // Empty state for day with no activities
                        if entries.isEmpty {
                            Color.clear
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 150, maxHeight: 280)
    }

    // MARK: - Computed Properties
    private var weekDates: [Date] {
        let weekday = calendar.component(.weekday, from: selectedDate)
        // Convert to Monday-first: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
        let offset = (weekday + 5) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -offset, to: selectedDate)?.startOfDay else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func entriesFor(date: Date) -> [CustomEntry] {
        switch selectedTab {
        case .media:
            return []  // Media entries not shown in weekly view
        case .custom(let sectionId):
            // Filter out recurrence templates - they're master records, not actual scheduled activities
            return customEntries
                .filter { $0.containsDate(date) && $0.section?.id == sectionId && !$0.isRecurrenceTemplate }
                .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
        }
    }
}

// MARK: - Week Date Cell
struct WeekDateCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasActivities: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(textColor)

            // Activity indicator dot
            Circle()
                .fill(hasActivities ? Color.purple : Color.clear)
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
        )
    }

    private var textColor: Color {
        if isToday { return .white }
        if isSelected { return .purple }
        return .white
    }

    private var backgroundColor: Color {
        if isToday { return Color.purple.opacity(0.3) }
        return Color(white: 0.15)
    }
}

// MARK: - Week Activity Card
struct WeekActivityCard: View {
    let entry: CustomEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: ActivityIconService.icon(for: entry.title))
                        .font(.system(size: 10))

                    Text(entry.title)
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundColor(.white)

                if let time = entry.formattedTimeRange {
                    Text(time)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(activityGradient)
            )
        }
        .buttonStyle(.plain)
    }

    private var activityGradient: LinearGradient {
        let colors = ActivityIconService.colors(for: entry.title)
        return LinearGradient(
            colors: [colorFromName(colors.primary).opacity(0.8),
                    colorFromName(colors.secondary).opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
