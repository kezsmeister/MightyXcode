import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User
    let entries: [MediaEntry]
    var customEntries: [CustomEntry] = []

    @State private var showingGoalEditor = false

    private var userEntries: [MediaEntry] {
        entries.filter { $0.user?.id == user.id }
    }

    private var userCustomEntries: [CustomEntry] {
        customEntries.filter { $0.user?.id == user.id }
    }

    private var movieEntries: [MediaEntry] {
        userEntries.filter { $0.mediaType == .movies }
    }

    private var bookEntries: [MediaEntry] {
        userEntries.filter { $0.mediaType == .books }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Yearly goals (only show if templates enabled)
                    if !user.enabledTemplates.isEmpty {
                        goalsSection
                    }

                    // Overview cards
                    overviewSection

                    // Custom sections stats
                    if !user.customSections.isEmpty {
                        customSectionsSection
                    }

                    // This year stats
                    thisYearSection

                    // Ratings breakdown
                    ratingsSection

                    // Monthly activity
                    monthlyActivitySection

                    // Recent activity
                    recentActivitySection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorSheet(user: user)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Time")
                .font(.headline)
                .foregroundColor(.gray)

            // Only show movie/book stats if those templates are enabled
            if user.enabledTemplates.contains("movies") || user.enabledTemplates.contains("books") {
                HStack(spacing: 16) {
                    if user.enabledTemplates.contains("movies") {
                        StatCard(
                            icon: "film",
                            title: "Movies",
                            value: "\(movieEntries.count)",
                            color: .purple
                        )
                    }

                    if user.enabledTemplates.contains("books") {
                        StatCard(
                            icon: "book",
                            title: "Books",
                            value: "\(bookEntries.count)",
                            color: .blue
                        )
                    }
                }
            }

            HStack(spacing: 16) {
                StatCard(
                    icon: "star.fill",
                    title: "Avg Rating",
                    value: averageRating,
                    color: .yellow
                )

                StatCard(
                    icon: "calendar",
                    title: "Total",
                    value: "\(userEntries.count + userCustomEntries.count)",
                    color: .green
                )
            }
        }
    }

    // MARK: - Custom Sections
    private var customSectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Sections")
                .font(.headline)
                .foregroundColor(.gray)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(user.customSections) { section in
                    let count = userCustomEntries.filter { $0.section?.id == section.id }.count
                    StatCard(
                        icon: section.icon,
                        title: section.name,
                        value: "\(count)",
                        color: .green
                    )
                }
            }
        }
    }

    // MARK: - This Year Section
    @ViewBuilder
    private var thisYearSection: some View {
        if user.enabledTemplates.contains("movies") || user.enabledTemplates.contains("books") {
            VStack(alignment: .leading, spacing: 16) {
                Text("This Year (\(currentYear))")
                    .font(.headline)
                    .foregroundColor(.gray)

                HStack(spacing: 16) {
                    if user.enabledTemplates.contains("movies") {
                        StatCard(
                            icon: "film",
                            title: "Movies",
                            value: "\(moviesThisYear)",
                            color: .purple
                        )
                    }

                    if user.enabledTemplates.contains("books") {
                        StatCard(
                            icon: "book",
                            title: "Books",
                            value: "\(booksThisYear)",
                            color: .blue
                        )
                    }
                }
            }
        }
    }

    // MARK: - Ratings Section
    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ratings Breakdown")
                .font(.headline)
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                ForEach((1...5).reversed(), id: \.self) { rating in
                    RatingBar(
                        rating: rating,
                        count: entriesWithRating(rating),
                        total: entriesWithAnyRating
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
            )
        }
    }

    // MARK: - Monthly Activity Section
    private var monthlyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Activity (Last 6 Months)")
                .font(.headline)
                .foregroundColor(.gray)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(lastSixMonths, id: \.self) { month in
                    MonthBar(
                        month: month,
                        count: entriesInMonth(month),
                        maxCount: maxEntriesInLastSixMonths
                    )
                }
            }
            .frame(height: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
            )
        }
    }

    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.headline)
                .foregroundColor(.gray)

            if recentEntries.isEmpty {
                Text("No entries yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12))
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(recentEntries) { entry in
                        RecentEntryRow(entry: entry)
                        if entry.id != recentEntries.last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.12))
                )
            }
        }
    }

    // MARK: - Goals Section
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Yearly Goals (\(currentYear))")
                    .font(.headline)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: { showingGoalEditor = true }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }

            HStack(spacing: 16) {
                if user.enabledTemplates.contains("movies") {
                    GoalCard(
                        icon: "film",
                        title: "Movies",
                        current: moviesThisYear,
                        goal: user.yearlyMovieGoal,
                        color: .purple
                    )
                }

                if user.enabledTemplates.contains("books") {
                    GoalCard(
                        icon: "book",
                        title: "Books",
                        current: booksThisYear,
                        goal: user.yearlyBookGoal,
                        color: .blue
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var averageRating: String {
        let rated = userEntries.compactMap { $0.rating }
        guard !rated.isEmpty else { return "-" }
        let avg = Double(rated.reduce(0, +)) / Double(rated.count)
        return String(format: "%.1f", avg)
    }

    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private var moviesThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return movieEntries.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.count
    }

    private var booksThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return bookEntries.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.count
    }

    private func entriesWithRating(_ rating: Int) -> Int {
        userEntries.filter { $0.rating == rating }.count
    }

    private var entriesWithAnyRating: Int {
        userEntries.filter { $0.rating != nil }.count
    }

    private var lastSixMonths: [Date] {
        let calendar = Calendar.current
        return (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: Date())
        }.reversed()
    }

    private func entriesInMonth(_ date: Date) -> Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return userEntries.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }.count
    }

    private var maxEntriesInLastSixMonths: Int {
        max(lastSixMonths.map { entriesInMonth($0) }.max() ?? 1, 1)
    }

    private var recentEntries: [MediaEntry] {
        Array(userEntries.sorted { $0.date > $1.date }.prefix(5))
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.12))
        )
    }
}

struct RatingBar: View {
    let rating: Int
    let count: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                }
            }
            .frame(width: 70)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8)

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct MonthBar: View {
    let month: Date
    let count: Int
    let maxCount: Int

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    private var heightPercentage: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: max(CGFloat(heightPercentage) * 80, count > 0 ? 8 : 0))

            Text(monthName)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentEntryRow: View {
    let entry: MediaEntry

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.mediaType.icon)
                .font(.title3)
                .foregroundColor(entry.mediaType == .movies ? .purple : .blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(dateFormatter.string(from: entry.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if let rating = entry.rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(rating)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct GoalCard: View {
    let icon: String
    let title: String
    let current: Int
    let goal: Int
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    private var progressText: String {
        "\(current)/\(goal)"
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)

                    Text(progressText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80, height: 80)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            if current >= goal && goal > 0 {
                Text("Goal reached!")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.12))
        )
    }
}

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let user: User

    @State private var movieGoal: Int
    @State private var bookGoal: Int

    init(user: User) {
        self.user = user
        _movieGoal = State(initialValue: user.yearlyMovieGoal)
        _bookGoal = State(initialValue: user.yearlyBookGoal)
    }

    var body: some View {
        NavigationStack {
            Form {
                if user.enabledTemplates.contains("movies") {
                    Section("Movie Goal") {
                        Stepper(value: $movieGoal, in: 1...365) {
                            HStack {
                                Image(systemName: "film")
                                    .foregroundColor(.purple)
                                Text("\(movieGoal) movies")
                            }
                        }
                    }
                }

                if user.enabledTemplates.contains("books") {
                    Section("Book Goal") {
                        Stepper(value: $bookGoal, in: 1...365) {
                            HStack {
                                Image(systemName: "book")
                                    .foregroundColor(.blue)
                                Text("\(bookGoal) books")
                            }
                        }
                    }
                }

                Section {
                    Text("Set your yearly goals. Track your progress throughout the year!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Yearly Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoals()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func saveGoals() {
        if user.enabledTemplates.contains("movies") {
            user.yearlyMovieGoal = movieGoal
        }
        if user.enabledTemplates.contains("books") {
            user.yearlyBookGoal = bookGoal
        }
        dismiss()
    }
}
