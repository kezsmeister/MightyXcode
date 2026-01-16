import SwiftUI
import SwiftData

enum DashboardViewMode: String, CaseIterable {
    case cards = "Cards"
    case agenda = "Agenda"
}

struct KidsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \User.createdAt) private var allUsers: [User]
    @Query private var allCustomEntries: [CustomEntry]
    @Query private var allMediaEntries: [MediaEntry]

    @Binding var selectedUser: User?
    let onUserSelected: (User) -> Void

    @State private var selectedDate = Date()
    @State private var quickAddUser: User?
    @State private var viewMode: DashboardViewMode = .cards

    private var users: [User] {
        let currentOwnerId = AuthState.shared.instantDBUserId
        if let ownerId = currentOwnerId {
            return allUsers.filter { $0.ownerId == ownerId }
        } else {
            return allUsers.filter { $0.ownerId == nil }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // View mode picker
                    Picker("View", selection: $viewMode) {
                        ForEach(DashboardViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if viewMode == .cards {
                        // Cards view (existing)
                        ScrollView {
                            VStack(spacing: 20) {
                                // Date selector
                                dateSelector

                                // Summary header
                                summaryHeader

                                // Kids cards
                                LazyVStack(spacing: 16) {
                                    ForEach(users) { user in
                                        KidActivityCard(
                                            user: user,
                                            date: selectedDate,
                                            customEntries: entriesForUser(user),
                                            mediaEntries: mediaEntriesForUser(user),
                                            onTap: {
                                                selectedUser = user
                                                onUserSelected(user)
                                                dismiss()
                                            },
                                            onQuickAdd: {
                                                quickAddUser = user
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)

                                if users.isEmpty {
                                    emptyState
                                }
                            }
                            .padding(.vertical)
                        }
                    } else {
                        // Agenda view
                        AgendaContentView(
                            users: users,
                            allCustomEntries: allCustomEntries
                        )
                    }
                }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $quickAddUser) { user in
            QuickAddSheet(user: user, date: selectedDate)
        }
    }

    private var dateSelector: some View {
        HStack(spacing: 16) {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(spacing: 2) {
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                Text(dateFormatter.string(from: selectedDate))
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            Spacer()

            Button("Today") {
                withAnimation { selectedDate = Date() }
            }
            .font(.subheadline)
            .foregroundColor(.purple)
            .opacity(Calendar.current.isDateInToday(selectedDate) ? 0 : 1)
        }
        .padding(.horizontal)
    }

    private var summaryHeader: some View {
        let totalActivities = users.reduce(0) { count, user in
            count + activitiesCountForUser(user)
        }

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(users.count) Kids")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(totalActivities) activities scheduled")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("No kids added yet")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Add a profile to start tracking activities")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.top, 40)
    }

    private func entriesForUser(_ user: User) -> [CustomEntry] {
        allCustomEntries.filter { entry in
            entry.user?.id == user.id && entry.containsDate(selectedDate)
        }
    }

    private func mediaEntriesForUser(_ user: User) -> [MediaEntry] {
        allMediaEntries.filter { entry in
            entry.user?.id == user.id && entry.containsDate(selectedDate)
        }
    }

    private func activitiesCountForUser(_ user: User) -> Int {
        entriesForUser(user).count + mediaEntriesForUser(user).count
    }

    private func previousDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    private func nextDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

struct KidActivityCard: View {
    let user: User
    let date: Date
    let customEntries: [CustomEntry]
    let mediaEntries: [MediaEntry]
    let onTap: () -> Void
    let onQuickAdd: () -> Void

    private var totalActivities: Int {
        customEntries.count + mediaEntries.count
    }

    private var hasActivities: Bool {
        totalActivities > 0
    }

    private var canAdd: Bool {
        !user.customSections.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with kid info
            HStack(spacing: 12) {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        Text(user.emoji)
                            .font(.system(size: 36))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("\(totalActivities) \(totalActivities == 1 ? "activity" : "activities")")
                                .font(.subheadline)
                                .foregroundColor(hasActivities ? .green : .gray)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Quick add button
                if canAdd {
                    Button(action: onQuickAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.purple)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onTap) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

                // Activities list
                if hasActivities {
                    Divider()
                        .background(Color.gray.opacity(0.3))

                    VStack(alignment: .leading, spacing: 8) {
                        // Custom entries
                        ForEach(customEntries.prefix(3)) { entry in
                            ActivityRow(
                                icon: entry.section?.icon ?? "star.fill",
                                title: entry.title,
                                subtitle: entry.section?.name,
                                time: entry.formattedTimeRange
                            )
                        }

                        // Media entries
                        ForEach(mediaEntries.prefix(3 - min(customEntries.count, 3))) { entry in
                            ActivityRow(
                                icon: entry.mediaType.icon,
                                title: entry.title,
                                subtitle: entry.mediaType.rawValue,
                                time: nil
                            )
                        }

                        // Show more indicator
                        if totalActivities > 3 {
                            Text("+\(totalActivities - 3) more")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.top, 4)
                        }
                    }
                } else {
                    // Empty state for this kid
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No activities scheduled")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(hasActivities ? Color.purple.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let time: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if let time = time {
                Text(time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Quick Add Sheet

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let user: User
    let date: Date

    @State private var selectedSection: CustomSection?
    @State private var selectedMediaType: MediaType?
    @State private var showingAddCustomEntry = false
    @State private var showingAddMediaEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Add activity for \(user.name)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Custom sections
                Section("Sections") {
                    if user.customSections.isEmpty {
                        Text("No custom sections")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(user.customSections) { section in
                            Button {
                                selectedSection = section
                                showingAddCustomEntry = true
                            } label: {
                                Label(section.name, systemImage: section.icon)
                            }
                        }
                    }
                }

                // Media templates
                if user.enabledTemplates.contains("movies") || user.enabledTemplates.contains("books") {
                    Section("Media") {
                        if user.enabledTemplates.contains("movies") {
                            Button {
                                selectedMediaType = .movies
                                showingAddMediaEntry = true
                            } label: {
                                Label("Movies & TV", systemImage: "film")
                            }
                        }

                        if user.enabledTemplates.contains("books") {
                            Button {
                                selectedMediaType = .books
                                showingAddMediaEntry = true
                            } label: {
                                Label("Books", systemImage: "book.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddCustomEntry) {
            if let section = selectedSection {
                AddCustomEntrySheet(date: date, section: section, user: user, prefilledActivity: nil)
            }
        }
        .sheet(isPresented: $showingAddMediaEntry) {
            if let mediaType = selectedMediaType {
                AddEntrySheet(date: date, mediaType: mediaType, user: user)
            }
        }
    }
}

struct QuickAddSectionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agenda Content View (embedded in dashboard)

struct AgendaContentView: View {
    let users: [User]
    let allCustomEntries: [CustomEntry]

    @State private var selectedEntry: CustomEntry?
    @State private var showingEntryDetail = false

    // Get entries for the next 14 days, grouped by date
    private var groupedEntries: [(date: Date, entries: [AgendaItem])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let twoWeeksLater = calendar.date(byAdding: .day, value: 14, to: today) else {
            return []
        }

        // Get all entries for our users within the date range
        let userIds = Set(users.map { $0.id })
        let relevantEntries = allCustomEntries.filter { entry in
            guard let userId = entry.user?.id else { return false }
            guard userIds.contains(userId) else { return false }
            let entryDate = calendar.startOfDay(for: entry.date)
            return entryDate >= today && entryDate <= twoWeeksLater
        }

        // Convert to AgendaItem and group by date
        var entriesByDate: [Date: [AgendaItem]] = [:]

        for entry in relevantEntries {
            let dateKey = calendar.startOfDay(for: entry.date)
            let agendaItem = AgendaItem(
                id: entry.id,
                title: entry.title,
                time: entry.startTime,
                endTime: entry.endTime,
                userName: entry.user?.name ?? "Unknown",
                userEmoji: entry.user?.emoji ?? "👤",
                sectionName: entry.section?.name ?? "",
                sectionIcon: entry.section?.icon ?? "star.fill",
                customEntry: entry
            )

            if entriesByDate[dateKey] != nil {
                entriesByDate[dateKey]?.append(agendaItem)
            } else {
                entriesByDate[dateKey] = [agendaItem]
            }
        }

        // Sort entries within each day by time
        for (date, entries) in entriesByDate {
            entriesByDate[date] = entries.sorted { a, b in
                guard let timeA = a.time else { return false }
                guard let timeB = b.time else { return true }
                return timeA < timeB
            }
        }

        // Sort dates and return
        return entriesByDate
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, entries: $0.value) }
    }

    private var totalActivitiesCount: Int {
        groupedEntries.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        if groupedEntries.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No Upcoming Activities")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Activities scheduled for the next 2 weeks will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Summary header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next 2 Weeks")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("\(totalActivitiesCount) activities")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Kid avatars
                        HStack(spacing: -8) {
                            ForEach(users.prefix(4)) { user in
                                Text(user.emoji)
                                    .font(.callout)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color(white: 0.15))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black, lineWidth: 2)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // Agenda list
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedEntries, id: \.date) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    AgendaItemRow(entry: entry)
                                        .onTapGesture {
                                            selectedEntry = entry.customEntry
                                            showingEntryDetail = true
                                        }
                                }
                            } header: {
                                AgendaDateHeader(date: group.date, count: group.entries.count)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEntryDetail) {
                if let entry = selectedEntry {
                    CustomEntryDetailSheet(entry: entry)
                }
            }
        }
    }
}

// MARK: - Agenda Supporting Types

struct AgendaItem: Identifiable {
    let id: UUID
    let title: String
    let time: Date?
    let endTime: Date?
    let userName: String
    let userEmoji: String
    let sectionName: String
    let sectionIcon: String
    let customEntry: CustomEntry
}

struct AgendaDateHeader: View {
    let date: Date
    let count: Int

    private var dateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack {
            Text(dateText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isToday ? .purple : .white)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(white: 0.2))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}

struct AgendaItemRow: View {
    let entry: AgendaItem

    private var timeText: String {
        guard let time = entry.time else { return "All day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if let endTime = entry.endTime {
            return "\(formatter.string(from: time)) - \(formatter.string(from: endTime))"
        }
        return formatter.string(from: time)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            Text(timeText)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            // Kid emoji
            Text(entry.userEmoji)
                .font(.callout)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                )

            // Activity details
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(entry.userName)
                        .font(.caption)
                        .foregroundColor(.purple)

                    if !entry.sectionName.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Image(systemName: entry.sectionIcon)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        Text(entry.sectionName)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
        .contentShape(Rectangle())
    }
}

// MARK: - Main Agenda View (for ContentView calendar section)

struct MainAgendaView: View {
    let users: [User]
    let customEntries: [CustomEntry]
    let onEntryTap: (CustomEntry) -> Void

    // Get entries for the next 14 days, grouped by date
    private var groupedEntries: [(date: Date, entries: [AgendaItem])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let twoWeeksLater = calendar.date(byAdding: .day, value: 14, to: today) else {
            return []
        }

        // Get all entries for our users within the date range
        let userIds = Set(users.map { $0.id })
        let relevantEntries = customEntries.filter { entry in
            guard let userId = entry.user?.id else { return false }
            guard userIds.contains(userId) else { return false }
            let entryDate = calendar.startOfDay(for: entry.date)
            return entryDate >= today && entryDate <= twoWeeksLater
        }

        // Convert to AgendaItem and group by date
        var entriesByDate: [Date: [AgendaItem]] = [:]

        for entry in relevantEntries {
            let dateKey = calendar.startOfDay(for: entry.date)
            let agendaItem = AgendaItem(
                id: entry.id,
                title: entry.title,
                time: entry.startTime,
                endTime: entry.endTime,
                userName: entry.user?.name ?? "Unknown",
                userEmoji: entry.user?.emoji ?? "👤",
                sectionName: entry.section?.name ?? "",
                sectionIcon: entry.section?.icon ?? "star.fill",
                customEntry: entry
            )

            if entriesByDate[dateKey] != nil {
                entriesByDate[dateKey]?.append(agendaItem)
            } else {
                entriesByDate[dateKey] = [agendaItem]
            }
        }

        // Sort entries within each day by time
        for (date, entries) in entriesByDate {
            entriesByDate[date] = entries.sorted { a, b in
                guard let timeA = a.time else { return false }
                guard let timeB = b.time else { return true }
                return timeA < timeB
            }
        }

        // Sort dates and return
        return entriesByDate
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, entries: $0.value) }
    }

    private var totalActivitiesCount: Int {
        groupedEntries.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        if groupedEntries.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "calendar")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No Upcoming Activities")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Activities for the next 2 weeks will appear here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Summary
                    HStack {
                        Text("\(totalActivitiesCount) activities")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        // Kid avatars
                        HStack(spacing: -6) {
                            ForEach(users.prefix(5)) { user in
                                Text(user.emoji)
                                    .font(.caption)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(Color(white: 0.15))
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black, lineWidth: 1.5)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    // Agenda list
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedEntries, id: \.date) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    AgendaItemRow(entry: entry)
                                        .onTapGesture {
                                            onEntryTap(entry.customEntry)
                                        }
                                }
                            } header: {
                                AgendaDateHeader(date: group.date, count: group.entries.count)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    KidsDashboardView(
        selectedUser: .constant(nil),
        onUserSelected: { _ in }
    )
    .modelContainer(for: [MediaEntry.self, User.self, CustomSection.self, CustomEntry.self], inMemory: true)
}
