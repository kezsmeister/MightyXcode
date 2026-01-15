import SwiftUI
import SwiftData

struct AddCustomEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCustomEntries: [CustomEntry]

    let date: Date
    let section: CustomSection
    let user: User
    let prefilledActivity: String?

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedDate: Date
    @State private var hasTime = false
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
    @State private var notifyMe = false
    @State private var showingSuggestions = false
    @State private var showingPermissionDenied = false
    @FocusState private var isTitleFocused: Bool

    // Recurrence state
    @State private var isRepeating = false
    @State private var recurrencePattern: RecurrencePattern = .weekly
    @State private var selectedWeekdays: Set<Int> = []
    @State private var endCondition: RecurrenceEndCondition = .never
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    @State private var occurrenceCount: Int = 10

    // Conflict detection
    @State private var conflicts: [TimeConflict] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    init(date: Date, section: CustomSection, user: User, prefilledActivity: String? = nil) {
        self.date = date
        self.section = section
        self.user = user
        self.prefilledActivity = prefilledActivity
        _selectedDate = State(initialValue: date)
        _title = State(initialValue: prefilledActivity ?? "")
    }

    private var filteredSuggestions: [String] {
        if title.isEmpty {
            return section.suggestedActivities
        }
        return section.suggestedActivities.filter {
            $0.lowercased().contains(title.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Activity name", text: $title)
                            .focused($isTitleFocused)
                            .onChange(of: title) {
                                if isTitleFocused && !title.isEmpty {
                                    showingSuggestions = true
                                }
                            }

                        if showingSuggestions && !filteredSuggestions.isEmpty {
                            suggestionsDropdown
                        }
                    }
                }

                Section {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .onChange(of: selectedDate) { _, _ in
                            if hasTime {
                                checkForConflicts()
                            }
                        }
                }

                Section("Time (Optional)") {
                    Toggle("Add Time", isOn: $hasTime)
                        .onChange(of: hasTime) { _, newValue in
                            if !newValue {
                                notifyMe = false
                                conflicts = []
                            } else {
                                // Set end time to 1 hour after start time
                                endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
                                checkForConflicts()
                            }
                        }

                    if hasTime {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                            .onChange(of: startTime) { _, newValue in
                                // Keep end time 1 hour after start time when start time changes
                                endTime = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                                checkForConflicts()
                            }

                        Toggle("End Time", isOn: $hasEndTime)
                            .onChange(of: hasEndTime) { _, _ in
                                checkForConflicts()
                            }

                        if hasEndTime {
                            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                                .onChange(of: endTime) { _, _ in
                                    checkForConflicts()
                                }
                        }

                        Toggle("Remind me 1 hour before", isOn: $notifyMe)
                            .onChange(of: notifyMe) { _, newValue in
                                if newValue {
                                    NotificationManager.shared.requestPermission { granted in
                                        if !granted {
                                            notifyMe = false
                                            showingPermissionDenied = true
                                        }
                                    }
                                }
                            }
                    }
                }

                // Conflict warning
                if hasTime && !conflicts.isEmpty {
                    Section {
                        ForEach(conflicts, id: \.conflictingEntry.id) { conflict in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(conflict.warningMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    } header: {
                        Text("Schedule Conflict")
                    }
                }

                Section("Repeat") {
                    Toggle("Repeat", isOn: $isRepeating)

                    if isRepeating {
                        Picker("Frequency", selection: $recurrencePattern) {
                            ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                                Text(pattern.displayName).tag(pattern)
                            }
                        }

                        if recurrencePattern == .weekly || recurrencePattern == .biweekly {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("On days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                WeekdayPicker(selectedWeekdays: $selectedWeekdays)
                            }
                            .padding(.vertical, 4)
                        }

                        Picker("Ends", selection: $endCondition) {
                            ForEach(RecurrenceEndCondition.allCases, id: \.self) { condition in
                                Text(condition.rawValue).tag(condition)
                            }
                        }

                        if endCondition == .onDate {
                            DatePicker("End Date", selection: $recurrenceEndDate, displayedComponents: .date)
                        } else if endCondition == .afterOccurrences {
                            Stepper("After \(occurrenceCount) times", value: $occurrenceCount, in: 2...100)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add \(section.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .alert("Notifications Disabled", isPresented: $showingPermissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable notifications in Settings to receive reminders.")
        }
        .task {
            // Only focus title field if no activity was pre-selected
            if prefilledActivity == nil {
                try? await Task.sleep(for: .milliseconds(300))
                isTitleFocused = true
            }
        }
    }

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSuggestions, id: \.self) { suggestion in
                        Button {
                            title = suggestion
                            showingSuggestions = false
                            isTitleFocused = false
                        } label: {
                            HStack {
                                Image(systemName: ActivityIconService.icon(for: suggestion))
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    private func checkForConflicts() {
        guard hasTime else {
            conflicts = []
            return
        }

        conflicts = ConflictDetectionService.shared.findConflicts(
            date: selectedDate,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            allEntries: allCustomEntries
        )
    }

    private func saveEntry() {
        // Add new activity to suggestions if not already present
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            let isNewActivity = !section.suggestedActivities.contains {
                $0.lowercased() == trimmedTitle.lowercased()
            }
            if isNewActivity {
                section.suggestedActivities.append(trimmedTitle)
            }
        }

        if isRepeating {
            // Create recurring entry
            let groupId = UUID()

            // Create template entry (master record)
            let template = CustomEntry(
                title: trimmedTitle,
                date: selectedDate,
                startTime: hasTime ? startTime : nil,
                endTime: (hasTime && hasEndTime) ? endTime : nil,
                notifyBefore: hasTime && notifyMe,
                notes: notes.isEmpty ? nil : notes,
                section: section,
                user: user,
                recurrenceGroupId: groupId,
                recurrencePattern: recurrencePattern,
                recurrenceWeekdays: (recurrencePattern == .weekly || recurrencePattern == .biweekly) && !selectedWeekdays.isEmpty ? Array(selectedWeekdays) : nil,
                recurrenceEndDate: endCondition == .onDate ? recurrenceEndDate : nil,
                recurrenceOccurrenceCount: endCondition == .afterOccurrences ? occurrenceCount : nil,
                isRecurrenceTemplate: true
            )
            modelContext.insert(template)

            // Generate instances
            let instances = RecurrenceService.shared.generateInstances(for: template)
            for instance in instances {
                modelContext.insert(instance)
                if instance.notifyBefore && instance.startTime != nil {
                    NotificationManager.shared.scheduleNotification(for: instance)
                }
            }
        } else {
            // Create single entry (existing behavior)
            let entry = CustomEntry(
                title: trimmedTitle,
                date: selectedDate,
                startTime: hasTime ? startTime : nil,
                endTime: (hasTime && hasEndTime) ? endTime : nil,
                notifyBefore: hasTime && notifyMe,
                notes: notes.isEmpty ? nil : notes,
                section: section,
                user: user
            )
            modelContext.insert(entry)

            // Schedule notification if user opted in
            if hasTime && notifyMe {
                NotificationManager.shared.scheduleNotification(for: entry)
            }
        }

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)

        dismiss()
    }
}

// MARK: - Weekday Picker

struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Int>

    // Weekday values: 1=Sunday, 2=Monday, etc.
    private let weekdays: [(Int, String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "Th"), (6, "F"), (7, "Sa"), (1, "Su")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekdays, id: \.0) { day, label in
                Button {
                    if selectedWeekdays.contains(day) {
                        selectedWeekdays.remove(day)
                    } else {
                        selectedWeekdays.insert(day)
                    }
                } label: {
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(selectedWeekdays.contains(day) ? Color.purple : Color.gray.opacity(0.3))
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
