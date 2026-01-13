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

            if !orderedTabs.isEmpty {
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
        }
    }

    private func toggleViewMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            calendarViewMode = calendarViewMode == .month ? .week : .month
        }
    }

    private func previousPeriod() {
        withAnimation {
            switch calendarViewMode {
            case .month:
                selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
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

                // Add section button
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
        modelContext.delete(section)
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
            }
        }
    }

    private func handleDayTap(_ date: Date) {
        selectedDate = date
        guard let tab = selectedTab else { return }
        switch tab {
        case .media(let mediaType):
            if let existingEntry = userEntries.first(where: { $0.containsDate(date) && $0.mediaType == mediaType }) {
                selectedEntry = existingEntry
                selectedCustomEntry = nil
                showingDetailSheet = true
            } else {
                prefilledActivityName = nil
                showingAddSheet = true
            }
        case .custom(let sectionId):
            if let existingEntry = userCustomEntries.first(where: { $0.containsDate(date) && $0.section?.id == sectionId }) {
                selectedCustomEntry = existingEntry
                selectedEntry = nil
                showingDetailSheet = true
            } else {
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

                Button {
                    showingEditActivities = true
                } label: {
                    Text("Edit")
                        .font(.subheadline)
                        .foregroundColor(.purple)
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
                            SuggestedActivityRow(activity: activity) {
                                prefilledActivityName = activity
                                showingAddSheet = true
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

#Preview {
    ContentView()
        .modelContainer(for: [MediaEntry.self, User.self, CustomSection.self, CustomEntry.self], inMemory: true)
}
