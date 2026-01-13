import Foundation
import SwiftData
import SwiftUI

/// Service for generating and managing recurring entry instances
@MainActor
class RecurrenceService {
    static let shared = RecurrenceService()
    private init() {}

    /// Generate instances for a recurring entry up to 3 months ahead
    func generateInstances(for template: CustomEntry) -> [CustomEntry] {
        guard let pattern = template.recurrencePattern,
              template.isRecurrenceTemplate,
              let groupId = template.recurrenceGroupId else {
            return []
        }

        let calendar = Calendar.current
        let startDate = template.date
        let endBoundary = calendar.date(byAdding: .month, value: 3, to: Date())!

        // Determine effective end date
        let effectiveEndDate = determineEndDate(
            pattern: pattern,
            startDate: startDate,
            endDate: template.recurrenceEndDate,
            occurrenceCount: template.recurrenceOccurrenceCount,
            endBoundary: endBoundary
        )

        var instances: [CustomEntry] = []
        var currentDate = startDate
        var count = 0
        let maxOccurrences = template.recurrenceOccurrenceCount ?? Int.max

        // Skip the first date (template itself) for weekly patterns with weekday selection
        // if the start date isn't one of the selected weekdays
        if pattern == .weekly || pattern == .biweekly {
            if let weekdays = template.recurrenceWeekdays, !weekdays.isEmpty {
                // For weekly with specific days, iterate through the week
                while currentDate <= effectiveEndDate && count < maxOccurrences {
                    let weekday = calendar.component(.weekday, from: currentDate)
                    if weekdays.contains(weekday) {
                        let instance = createInstance(from: template, on: currentDate, groupId: groupId)
                        instances.append(instance)
                        count += 1
                    }
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!

                    // For biweekly, skip a week after completing one week
                    if pattern == .biweekly {
                        let dayOfWeek = calendar.component(.weekday, from: currentDate)
                        if dayOfWeek == calendar.firstWeekday {
                            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
                        }
                    }
                }
            } else {
                // Weekly/biweekly without specific days - repeat on same weekday
                while currentDate <= effectiveEndDate && count < maxOccurrences {
                    let instance = createInstance(from: template, on: currentDate, groupId: groupId)
                    instances.append(instance)
                    count += 1
                    currentDate = nextDate(from: currentDate, pattern: pattern, calendar: calendar)
                }
            }
        } else {
            // Daily or Monthly
            while currentDate <= effectiveEndDate && count < maxOccurrences {
                let instance = createInstance(from: template, on: currentDate, groupId: groupId)
                instances.append(instance)
                count += 1
                currentDate = nextDate(from: currentDate, pattern: pattern, calendar: calendar)
            }
        }

        return instances
    }

    /// Regenerate future instances for an existing recurring series
    func regenerateFutureInstances(
        for groupId: UUID,
        template: CustomEntry,
        existingEntries: [CustomEntry],
        in context: ModelContext
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let existingFutureDates = Set(
            existingEntries
                .filter { calendar.startOfDay(for: $0.date) >= today }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let newInstances = generateInstances(for: template)

        for instance in newInstances {
            let instanceDate = calendar.startOfDay(for: instance.date)
            if instanceDate >= today && !existingFutureDates.contains(instanceDate) {
                context.insert(instance)
            }
        }
    }

    // MARK: - Private Helpers

    private func createInstance(from template: CustomEntry, on date: Date, groupId: UUID) -> CustomEntry {
        // Combine the date with the time from template
        var instanceStartTime: Date?
        var instanceEndTime: Date?

        if let templateStartTime = template.startTime {
            instanceStartTime = combineDateWithTime(date: date, time: templateStartTime)
        }
        if let templateEndTime = template.endTime {
            instanceEndTime = combineDateWithTime(date: date, time: templateEndTime)
        }

        return CustomEntry(
            id: UUID(),
            title: template.title,
            date: date,
            endDate: nil,
            startTime: instanceStartTime,
            endTime: instanceEndTime,
            notifyBefore: template.notifyBefore,
            rating: nil,
            notes: template.notes,
            imagesData: [],
            section: template.section,
            user: template.user,
            recurrenceGroupId: groupId,
            recurrencePattern: nil,
            recurrenceWeekdays: nil,
            recurrenceEndDate: nil,
            recurrenceOccurrenceCount: nil,
            isRecurrenceTemplate: false
        )
    }

    private func combineDateWithTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return calendar.date(from: dateComponents) ?? date
    }

    private func determineEndDate(
        pattern: RecurrencePattern,
        startDate: Date,
        endDate: Date?,
        occurrenceCount: Int?,
        endBoundary: Date
    ) -> Date {
        // If explicit end date is set, use the earlier of end date and boundary
        if let endDate = endDate {
            return min(endDate, endBoundary)
        }

        // If occurrence count is set, calculate approximate end date
        if let count = occurrenceCount {
            let calendar = Calendar.current
            let estimatedEnd: Date
            switch pattern {
            case .daily:
                estimatedEnd = calendar.date(byAdding: .day, value: count, to: startDate)!
            case .weekly:
                estimatedEnd = calendar.date(byAdding: .weekOfYear, value: count, to: startDate)!
            case .biweekly:
                estimatedEnd = calendar.date(byAdding: .weekOfYear, value: count * 2, to: startDate)!
            case .monthly:
                estimatedEnd = calendar.date(byAdding: .month, value: count, to: startDate)!
            }
            return min(estimatedEnd, endBoundary)
        }

        // No end condition - use boundary (3 months ahead)
        return endBoundary
    }

    private func nextDate(from date: Date, pattern: RecurrencePattern, calendar: Calendar) -> Date {
        switch pattern {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)!
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)!
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)!
        }
    }
}
