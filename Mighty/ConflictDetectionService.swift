import Foundation

struct TimeConflict {
    let conflictingEntry: CustomEntry
    let sectionName: String

    var warningMessage: String {
        let shortName = sectionName.replacingOccurrences(of: "'s Activities", with: "")
            .replacingOccurrences(of: " Activities", with: "")
        let time = conflictingEntry.startTime.map {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: $0)
        } ?? ""
        return "\(shortName): \(conflictingEntry.title) @ \(time)"
    }
}

@MainActor
class ConflictDetectionService {
    static let shared = ConflictDetectionService()

    private init() {}

    /// Check if a proposed time range conflicts with any existing entries
    /// - Parameters:
    ///   - date: The date of the activity
    ///   - startTime: The start time of the activity
    ///   - endTime: The end time of the activity (optional, defaults to 1 hour after start)
    ///   - excludeEntryId: Entry ID to exclude from conflict check (for editing existing entries)
    ///   - allEntries: All custom entries to check against
    /// - Returns: Array of conflicts found
    func findConflicts(
        date: Date,
        startTime: Date,
        endTime: Date?,
        excludeEntryId: UUID? = nil,
        allEntries: [CustomEntry]
    ) -> [TimeConflict] {
        let calendar = Calendar.current

        // Normalize the proposed time range to the target date
        let proposedStart = combineDateTime(date: date, time: startTime)
        let proposedEnd: Date
        if let endTime = endTime {
            proposedEnd = combineDateTime(date: date, time: endTime)
        } else {
            // Default to 1 hour duration if no end time specified
            proposedEnd = calendar.date(byAdding: .hour, value: 1, to: proposedStart) ?? proposedStart
        }

        var conflicts: [TimeConflict] = []

        for entry in allEntries {
            // Skip the entry being edited
            if let excludeId = excludeEntryId, entry.id == excludeId {
                continue
            }

            // Skip entries without time
            guard let entryStartTime = entry.startTime else {
                continue
            }

            // Skip recurrence templates (they're not actual scheduled events)
            if entry.isRecurrenceTemplate {
                continue
            }

            // Check if on the same day
            guard entry.date.isSameDay(as: date) else {
                continue
            }

            // Get entry's time range
            let entryStart = combineDateTime(date: entry.date, time: entryStartTime)
            let entryEnd: Date
            if let end = entry.endTime {
                entryEnd = combineDateTime(date: entry.date, time: end)
            } else {
                entryEnd = calendar.date(byAdding: .hour, value: 1, to: entryStart) ?? entryStart
            }

            // Check for overlap: two ranges overlap if start1 < end2 AND start2 < end1
            if proposedStart < entryEnd && entryStart < proposedEnd {
                let sectionName = entry.section?.name ?? "Another activity"
                conflicts.append(TimeConflict(conflictingEntry: entry, sectionName: sectionName))
            }
        }

        return conflicts
    }

    /// Check if an entry has conflicts with other entries
    func findConflictsForEntry(_ entry: CustomEntry, allEntries: [CustomEntry]) -> [TimeConflict] {
        guard let startTime = entry.startTime else {
            return []
        }

        return findConflicts(
            date: entry.date,
            startTime: startTime,
            endTime: entry.endTime,
            excludeEntryId: entry.id,
            allEntries: allEntries
        )
    }

    /// Get all entries on a specific date that have conflicts
    func entriesWithConflicts(on date: Date, allEntries: [CustomEntry]) -> Set<UUID> {
        var conflictingIds = Set<UUID>()

        // Get entries on this date that have times
        let entriesOnDate = allEntries.filter {
            $0.date.isSameDay(as: date) && $0.startTime != nil && !$0.isRecurrenceTemplate
        }

        // Check each pair
        for i in 0..<entriesOnDate.count {
            for j in (i + 1)..<entriesOnDate.count {
                let entry1 = entriesOnDate[i]
                let entry2 = entriesOnDate[j]

                if doEntriesConflict(entry1, entry2) {
                    conflictingIds.insert(entry1.id)
                    conflictingIds.insert(entry2.id)
                }
            }
        }

        return conflictingIds
    }

    private func doEntriesConflict(_ entry1: CustomEntry, _ entry2: CustomEntry) -> Bool {
        guard let start1 = entry1.startTime, let start2 = entry2.startTime else {
            return false
        }

        let calendar = Calendar.current

        let time1Start = combineDateTime(date: entry1.date, time: start1)
        let time1End: Date
        if let end = entry1.endTime {
            time1End = combineDateTime(date: entry1.date, time: end)
        } else {
            time1End = calendar.date(byAdding: .hour, value: 1, to: time1Start) ?? time1Start
        }

        let time2Start = combineDateTime(date: entry2.date, time: start2)
        let time2End: Date
        if let end = entry2.endTime {
            time2End = combineDateTime(date: entry2.date, time: end)
        } else {
            time2End = calendar.date(byAdding: .hour, value: 1, to: time2Start) ?? time2Start
        }

        return time1Start < time2End && time2Start < time1End
    }

    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}
