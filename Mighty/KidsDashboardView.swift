import SwiftUI
import SwiftData

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

#Preview {
    KidsDashboardView(
        selectedUser: .constant(nil),
        onUserSelected: { _ in }
    )
    .modelContainer(for: [MediaEntry.self, User.self, CustomSection.self, CustomEntry.self], inMemory: true)
}
