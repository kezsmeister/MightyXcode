import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [MediaEntry]
    @Query(sort: \User.createdAt) private var allUsers: [User]
    @Query private var customSections: [CustomSection]
    @Query private var customEntries: [CustomEntry]

    // Filter users by current authenticated account
    private var users: [User] {
        let currentOwnerId = AuthState.shared.instantDBUserId
        if let ownerId = currentOwnerId {
            // Authenticated - show only profiles owned by this account
            return allUsers.filter { $0.ownerId == ownerId }
        } else {
            // Not authenticated - show profiles without ownerId (local-only)
            return allUsers.filter { $0.ownerId == nil }
        }
    }

    @State private var selectedDate = Date()
    @State private var selectedTab: SelectedTab? = nil
    @State private var showingAddSheet = false
    @State private var showingDetailSheet = false
    @State private var showingYearOverview = false
    @State private var showingUserManager = false
    @State private var showingStats = false
    @State private var showingSettings = false
    @State private var showingAddSectionSheet = false
    @State private var showingReorderSheet = false
    @State private var showingDashboard = false
    @State private var selectedEntry: MediaEntry?
    @State private var selectedCustomEntry: CustomEntry?
    @State private var selectedUser: User?
    @State private var prefilledActivityName: String?
    @State private var showingEditActivities = false
    @State private var calendarViewMode: CalendarViewMode = .month
    @State private var showingDayActivitiesSheet = false
    @State private var dayActivitiesEntries: [CustomEntry] = []
    @State private var dayActivitiesMediaEntries: [MediaEntry] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    // Filter entries for the current user
    private var userEntries: [MediaEntry] {
        guard let user = selectedUser else { return [] }
        return entries.filter { $0.user?.id == user.id }
    }

    // Get custom sections for the current user
    private var userCustomSections: [CustomSection] {
        guard let user = selectedUser else { return [] }
        return user.customSections
    }

    // Filter custom entries for the current user
    private var userCustomEntries: [CustomEntry] {
        guard let user = selectedUser else { return [] }
        return customEntries.filter { $0.user?.id == user.id }
    }

    // Get all tabs in the correct order
    private var orderedTabs: [TabItem] {
        guard let user = selectedUser else {
            return []
        }

        // Build tabs from stored order
        var tabs: [TabItem] = []
        var usedIds = Set<String>()

        for tabId in user.tabOrder {
            // Only include movies/books if they're in enabledTemplates
            if tabId == "movies" && user.enabledTemplates.contains("movies") {
                tabs.append(TabItem.mediaTab(.movies))
                usedIds.insert(tabId)
            } else if tabId == "books" && user.enabledTemplates.contains("books") {
                tabs.append(TabItem.mediaTab(.books))
                usedIds.insert(tabId)
            } else if let section = userCustomSections.first(where: { $0.id.uuidString == tabId }) {
                tabs.append(TabItem.customTab(section))
                usedIds.insert(tabId)
            }
        }

        // Add any new custom sections not in the order yet
        for section in userCustomSections {
            if !usedIds.contains(section.id.uuidString) {
                tabs.append(TabItem.customTab(section))
            }
        }

        // Add enabled templates not in order yet (e.g., just enabled)
        if user.enabledTemplates.contains("movies") && !usedIds.contains("movies") {
            tabs.append(TabItem.mediaTab(.movies))
        }
        if user.enabledTemplates.contains("books") && !usedIds.contains("books") {
            tabs.append(TabItem.mediaTab(.books))
        }

        return tabs
    }

    // Get the current custom section
    private var currentCustomSection: CustomSection? {
        guard let tab = selectedTab, case .custom(let sectionId) = tab else { return nil }
        return userCustomSections.first { $0.id == sectionId }
    }

    // Check if showing a custom section tab
    private var isCustomSectionSelected: Bool {
        guard let tab = selectedTab else { return false }
        if case .custom = tab { return true }
        return false
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if orderedTabs.isEmpty {
                // Empty state when no sections exist
                emptyStateView
            } else if isCustomSectionSelected {
                // Use ScrollView for custom sections to allow scrolling through activities
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        userSelector
                        headerView
                        categoryTabs
                        calendarSection
                        activityListSection
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for floating button
                }
            } else {
                VStack(spacing: 16) {
                    userSelector
                    headerView
                    categoryTabs
                    calendarSection
                    Spacer()
                }
                .padding()
            }

            // Only show FAB if user can edit (not a viewer)
            if !orderedTabs.isEmpty && AuthState.shared.canEdit {
                floatingActionButton
            }
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: {
            prefilledActivityName = nil
        }) {
            if let user = selectedUser, let tab = selectedTab {
                switch tab {
                case .media(let mediaType):
                    AddEntrySheet(date: selectedDate, mediaType: mediaType, user: user)
                case .custom(let sectionId):
                    if let section = userCustomSections.first(where: { $0.id == sectionId }) {
                        AddCustomEntrySheet(date: selectedDate, section: section, user: user, prefilledActivity: prefilledActivityName)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetailSheet) {
            if let entry = selectedEntry {
                EntryDetailSheet(entry: entry)
            } else if let customEntry = selectedCustomEntry {
                CustomEntryDetailSheet(entry: customEntry)
            }
        }
        .sheet(isPresented: $showingAddSectionSheet) {
            if let user = selectedUser {
                AddSectionSheet(user: user)
            }
        }
        .sheet(isPresented: $showingReorderSheet) {
            if let user = selectedUser {
                ReorderTabsSheet(user: user, customSections: userCustomSections)
            }
        }
        .sheet(isPresented: $showingYearOverview) {
            YearOverviewSheet(selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showingUserManager) {
            UserManagerSheet(selectedUser: $selectedUser)
        }
        .sheet(isPresented: $showingStats) {
            if let user = selectedUser {
                StatsView(user: user, entries: entries, customEntries: customEntries)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: selectedUser)
        }
        .sheet(isPresented: $showingEditActivities) {
            if let section = currentCustomSection {
                EditActivitiesSheet(section: section)
            }
        }
        .sheet(isPresented: $showingDashboard) {
            KidsDashboardView(
                selectedUser: $selectedUser,
                onUserSelected: { user in
                    selectedUser = user
                    selectDefaultTabIfNeeded()
                }
            )
        }
        .sheet(isPresented: $showingDayActivitiesSheet) {
            DayActivitiesSheet(
                date: selectedDate,
                entries: dayActivitiesEntries,
                mediaEntries: dayActivitiesMediaEntries,
                section: currentCustomSection,
                mediaType: selectedTab.flatMap { tab -> MediaType? in
                    if case .media(let type) = tab { return type }
                    return nil
                },
                onEntryTap: { entry in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedCustomEntry = entry
                        selectedEntry = nil
                        showingDetailSheet = true
                    }
                },
                onMediaEntryTap: { entry in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedEntry = entry
                        selectedCustomEntry = nil
                        showingDetailSheet = true
                    }
                },
                onAddTap: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        prefilledActivityName = nil
                        showingAddSheet = true
                    }
                }
            )
        }
        .onAppear {
            ensureDefaultUser()
            selectDefaultTabIfNeeded()
        }
        .onChange(of: users) {
            // If selected user was deleted, select another
            if selectedUser == nil || !users.contains(where: { $0.id == selectedUser?.id }) {
                selectedUser = users.first
            }
        }
        .onChange(of: orderedTabs) {
            selectDefaultTabIfNeeded()
        }
    }

    private var userSelector: some View {
        HStack(spacing: 12) {
            Button(action: { showingUserManager = true }) {
                HStack(spacing: 8) {
                    if let user = selectedUser {
                        Text(user.emoji)
                            .font(.title3)

                        Text(user.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.circle")
                            .font(.title3)

                        Text("Select User")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.15))
                )
            }

            // Dashboard button
            Button(action: { showingDashboard = true }) {
                Image(systemName: "rectangle.grid.1x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                    )
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            // Left: Navigation
            HStack(spacing: 4) {
                Button(action: previousPeriod) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }

                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }

                // Viewer badge when viewing shared family
                if AuthState.shared.isViewingSharedFamily && !AuthState.shared.canEdit {
                    Text("Viewing")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .padding(.leading, 8)
                }
            }

            Spacer()

            // Center: Date title (tappable for year overview)
            Button(action: { showingYearOverview = true }) {
                Text(headerTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Spacer()

            // Right: Actions
            HStack(spacing: 12) {
                // View mode toggle
                Button(action: toggleViewMode) {
                    Image(systemName: calendarViewMode.icon)
                        .font(.system(size: 15))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                        )
                }

                // More menu
                Menu {
                    Button(action: { showingYearOverview = true }) {
                        Label("Year Overview", systemImage: "square.grid.2x2")
                    }
                    Button(action: { showingStats = true }) {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
                    Divider()
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private var headerTitle: String {
        switch calendarViewMode {
        case .month:
            return dateFormatter.string(from: selectedDate)
        case .week:
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: selectedDate)
            // Convert to Monday-first: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
            let offset = (weekday + 5) % 7
            guard let startOfWeek = calendar.date(byAdding: .day, value: -offset, to: selectedDate)?.startOfDay,
                  let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
                return dateFormatter.string(from: selectedDate)
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let year = calendar.component(.year, from: startOfWeek)
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek)), \(year)"
        case .agenda:
            return "Family Agenda"
        }
    }

    private func toggleViewMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            calendarViewMode = calendarViewMode.next
        }
    }

    private func previousPeriod() {
        withAnimation {
            switch calendarViewMode {
            case .month:
                selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            case .agenda:
                break // Agenda shows fixed 2-week window from today
            }
        }
    }

    private func nextPeriod() {
        withAnimation {
            switch calendarViewMode {
            case .month:
                selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            case .agenda:
                break // Agenda shows fixed 2-week window from today
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                // All tabs
                ForEach(orderedTabs) { tabItem in
                    CategoryTab(
                        title: tabItem.title,
                        icon: tabItem.icon,
                        isSelected: selectedTab == tabItem.tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tabItem.tab
                        }
                    }
                    .contextMenu {
                        // Only show reorder/delete options if user can edit
                        if AuthState.shared.canEdit {
                            Button {
                                showingReorderSheet = true
                            } label: {
                                Label("Reorder Sections", systemImage: "arrow.up.arrow.down")
                            }

                            if case .custom(let sectionId) = tabItem.tab,
                               let section = userCustomSections.first(where: { $0.id == sectionId }) {
                                Button(role: .destructive) {
                                    deleteSection(section)
                                } label: {
                                    Label("Delete Section", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Add section button - only show if user can edit
                if AuthState.shared.canEdit {
                    AddSectionButton {
                        showingAddSectionSheet = true
                    }

                    // Reorder button (only show if there are tabs to reorder)
                    if orderedTabs.count > 1 {
                        Button {
                            showingReorderSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func deleteSection(_ section: CustomSection) {
        // If we're viewing this section, switch to first available tab
        if let tab = selectedTab, case .custom(let id) = tab, id == section.id {
            // Find another tab to switch to
            let otherTabs = orderedTabs.filter { $0.id != section.id.uuidString }
            selectedTab = otherTabs.first?.tab
        }
        // Remove from tab order
        if let user = selectedUser {
            user.tabOrder.removeAll { $0 == section.id.uuidString }
        }

        // Capture ID before deleting
        let sectionId = section.id

        // Mark as deleted to prevent sync from restoring it
        DeletionTracker.shared.markSectionDeleted(sectionId)

        // Delete locally
        modelContext.delete(section)

        // Delete from cloud in background
        Task {
            try? await EntrySyncService.shared.deleteSectionFromCloud(sectionId: sectionId)
        }
    }

    private var calendarSection: some View {
        Group {
            switch calendarViewMode {
            case .month:
                CalendarView(
                    selectedDate: $selectedDate,
                    selectedTab: Binding(
                        get: { selectedTab ?? .media(.movies) },
                        set: { selectedTab = $0 }
                    ),
                    mediaEntries: userEntries,
                    customEntries: userCustomEntries,
                    customSections: userCustomSections,
                    onDayTap: handleDayTap
                )
            case .week:
                WeeklyScheduleView(
                    selectedDate: $selectedDate,
                    selectedTab: Binding(
                        get: { selectedTab ?? .media(.movies) },
                        set: { selectedTab = $0 }
                    ),
                    mediaEntries: userEntries,
                    customEntries: userCustomEntries,
                    customSections: userCustomSections,
                    onDayTap: handleDayTap,
                    onActivityTap: { entry in
                        selectedCustomEntry = entry
                        selectedEntry = nil
                        showingDetailSheet = true
                    }
                )
            case .agenda:
                MainAgendaView(
                    users: users,
                    customEntries: customEntries,
                    onEntryTap: { entry in
                        selectedCustomEntry = entry
                        selectedEntry = nil
                        showingDetailSheet = true
                    }
                )
            }
        }
    }

    private func handleDayTap(_ date: Date) {
        selectedDate = date
        guard let tab = selectedTab else { return }
        switch tab {
        case .media(let mediaType):
            let matchingEntries = userEntries.filter { $0.containsDate(date) && $0.mediaType == mediaType }
            if matchingEntries.count > 1 {
                // Multiple activities - show list sheet
                dayActivitiesMediaEntries = matchingEntries
                dayActivitiesEntries = []
                showingDayActivitiesSheet = true
            } else if let existingEntry = matchingEntries.first {
                // Single activity - show detail directly
                selectedEntry = existingEntry
                selectedCustomEntry = nil
                showingDetailSheet = true
            } else if AuthState.shared.canEdit {
                // No activities - show add sheet (only if user can edit)
                prefilledActivityName = nil
                showingAddSheet = true
            }
        case .custom(let sectionId):
            // Filter out recurrence templates - they're master records, not actual scheduled activities
            let matchingEntries = userCustomEntries.filter { $0.containsDate(date) && $0.section?.id == sectionId && !$0.isRecurrenceTemplate }
            if matchingEntries.count > 1 {
                // Multiple activities - show list sheet
                dayActivitiesEntries = matchingEntries
                dayActivitiesMediaEntries = []
                showingDayActivitiesSheet = true
            } else if let existingEntry = matchingEntries.first {
                // Single activity - show detail directly
                selectedCustomEntry = existingEntry
                selectedEntry = nil
                showingDetailSheet = true
            } else if AuthState.shared.canEdit {
                // No activities - show add sheet (only if user can edit)
                prefilledActivityName = nil
                showingAddSheet = true
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            userSelector

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No Activities Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if AuthState.shared.canEdit {
                    Text("Create your first section to start tracking activities")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        showingAddSectionSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Create Section")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                } else {
                    Text("No activities have been added to this family yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
        .padding()
    }

    private var activityListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activities")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)

                Spacer()

                // Only show Edit button if user can edit
                if AuthState.shared.canEdit {
                    Button {
                        showingEditActivities = true
                    } label: {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                }
            }

            if let section = currentCustomSection {
                if section.suggestedActivities.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No activities set up")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(section.suggestedActivities, id: \.self) { activity in
                            if AuthState.shared.canEdit {
                                SuggestedActivityRow(activity: activity) {
                                    prefilledActivityName = activity
                                    showingAddSheet = true
                                }
                            } else {
                                // Read-only view for viewers
                                SuggestedActivityRow(activity: activity) { }
                                    .allowsHitTesting(false)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
            }
        }
    }

    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    prefilledActivityName = nil
                    showingAddSheet = true
                }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .shadow(color: .purple.opacity(0.5), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .disabled(selectedUser == nil)
                .opacity(selectedUser == nil ? 0.5 : 1)
            }
        }
    }

    private func ensureDefaultUser() {
        // Only select an existing user, don't create new ones (onboarding handles that)
        if selectedUser == nil {
            selectedUser = users.first
        }
    }

    private func selectDefaultTabIfNeeded() {
        // Select first tab if none selected but tabs exist
        if selectedTab == nil && !orderedTabs.isEmpty {
            selectedTab = orderedTabs.first?.tab
        }
        // If selected tab no longer exists, select first available
        if let tab = selectedTab {
            let tabExists = orderedTabs.contains { $0.tab == tab }
            if !tabExists {
                selectedTab = orderedTabs.first?.tab
            }
        }
    }
}

struct CategoryTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
                .foregroundColor(isSelected ? .white : .gray)

                // Underline indicator
                Rectangle()
                    .fill(isSelected ? Color.purple : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
            .padding(.horizontal, 4)
        }
    }
}

struct AddSectionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.6))

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct ReorderTabsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let user: User
    let customSections: [CustomSection]

    @State private var tabItems: [TabItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(tabItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 24)

                        Text(item.title)
                            .font(.body)

                        Spacer()

                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveItem)
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveOrder()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear {
            loadTabItems()
        }
    }

    private func loadTabItems() {
        var items: [TabItem] = []
        var usedIds = Set<String>()

        // Build from stored order
        for tabId in user.tabOrder {
            // Only include movies/books if enabled
            if tabId == "movies" && user.enabledTemplates.contains("movies") {
                items.append(TabItem.mediaTab(.movies))
                usedIds.insert(tabId)
            } else if tabId == "books" && user.enabledTemplates.contains("books") {
                items.append(TabItem.mediaTab(.books))
                usedIds.insert(tabId)
            } else if let section = customSections.first(where: { $0.id.uuidString == tabId }) {
                items.append(TabItem.customTab(section))
                usedIds.insert(tabId)
            }
        }

        // Add missing custom sections
        for section in customSections {
            if !usedIds.contains(section.id.uuidString) {
                items.append(TabItem.customTab(section))
            }
        }

        // Add enabled templates not in order yet
        if user.enabledTemplates.contains("movies") && !usedIds.contains("movies") {
            items.append(TabItem.mediaTab(.movies))
        }
        if user.enabledTemplates.contains("books") && !usedIds.contains("books") {
            items.append(TabItem.mediaTab(.books))
        }

        tabItems = items
    }

    private func moveItem(from source: IndexSet, to destination: Int) {
        tabItems.move(fromOffsets: source, toOffset: destination)
    }

    private func saveOrder() {
        user.tabOrder = tabItems.map { $0.id }
    }
}

struct EditActivitiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let section: CustomSection

    @State private var activities: [String] = []
    @State private var newActivity = ""
    @State private var showingAddAlert = false
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(activities, id: \.self) { activity in
                        HStack(spacing: 12) {
                            Image(systemName: ActivityIconService.icon(for: activity))
                                .font(.system(size: 16))
                                .foregroundColor(.purple)
                                .frame(width: 24)

                            Text(activity)
                                .font(.body)
                        }
                    }
                    .onDelete(perform: deleteActivity)
                    .onMove(perform: moveActivity)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveActivities()
                        dismiss()
                    }
                }
            }
            .alert("Add Activity", isPresented: $showingAddAlert) {
                TextField("Activity name", text: $newActivity)
                Button("Cancel", role: .cancel) {
                    newActivity = ""
                }
                Button("Add") {
                    addActivity()
                }
            } message: {
                Text("Enter the name of the new activity")
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear {
            activities = section.suggestedActivities
        }
    }

    private func deleteActivity(at offsets: IndexSet) {
        activities.remove(atOffsets: offsets)
    }

    private func moveActivity(from source: IndexSet, to destination: Int) {
        activities.move(fromOffsets: source, toOffset: destination)
    }

    private func addActivity() {
        let trimmed = newActivity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Don't add duplicates
        if !activities.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            activities.append(trimmed)
        }
        newActivity = ""
    }

    private func saveActivities() {
        section.suggestedActivities = activities
    }
}

struct SuggestedActivityRow: View {
    let activity: String
    let onTap: () -> Void

    private var activityIcon: String {
        ActivityIconService.icon(for: activity)
    }

    private var activityColors: (primary: String, secondary: String) {
        ActivityIconService.colors(for: activity)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Activity icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [colorFromName(activityColors.primary).opacity(0.7),
                                        colorFromName(activityColors.secondary).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: activityIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(activity)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12))
            )
        }
        .buttonStyle(.plain)
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

struct DayActivitiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let entries: [CustomEntry]
    let mediaEntries: [MediaEntry]
    let section: CustomSection?
    let mediaType: MediaType?
    let onEntryTap: (CustomEntry) -> Void
    let onMediaEntryTap: (MediaEntry) -> Void
    let onAddTap: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Custom entries
                    if !entries.isEmpty {
                        ForEach(entries.sorted(by: { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) })) { entry in
                            DayActivityRow(entry: entry)
                                .onTapGesture {
                                    dismiss()
                                    onEntryTap(entry)
                                }
                        }
                    }

                    // Media entries
                    if !mediaEntries.isEmpty {
                        ForEach(mediaEntries) { entry in
                            MediaActivityRow(entry: entry)
                                .onTapGesture {
                                    dismiss()
                                    onMediaEntryTap(entry)
                                }
                        }
                    }

                    // Add button - only show if user can edit
                    if AuthState.shared.canEdit {
                        Button {
                            dismiss()
                            onAddTap()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add Activity")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            )
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle(dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

struct DayActivityRow: View {
    let entry: CustomEntry

    private var activityIcon: String {
        ActivityIconService.icon(for: entry.title)
    }

    private var activityColors: (primary: String, secondary: String) {
        ActivityIconService.colors(for: entry.title)
    }

    private var timeString: String? {
        guard let startTime = entry.startTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var result = formatter.string(from: startTime)
        if let endTime = entry.endTime {
            result += " - \(formatter.string(from: endTime))"
        }
        return result
    }

    var body: some View {
        HStack(spacing: 12) {
            // Activity icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [colorFromName(activityColors.primary).opacity(0.7),
                                    colorFromName(activityColors.secondary).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: activityIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(.white)

                if let time = timeString {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
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

struct MediaActivityRow: View {
    let entry: MediaEntry

    var body: some View {
        HStack(spacing: 12) {
            // Media poster or icon
            if let imageURL = entry.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        mediaPlaceholder
                    }
                }
            } else {
                mediaPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(entry.mediaType.rawValue)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }

    private var mediaPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            Image(systemName: entry.mediaType.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MediaEntry.self, User.self, CustomSection.self, CustomEntry.self], inMemory: true)
}
