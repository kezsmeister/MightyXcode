import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]

    @State private var currentStep = 0
    @State private var userName = ""
    @State private var userEmoji = "😊"
    @State private var sectionDescription = ""
    @State private var sectionName = ""
    @State private var selectedIcon = "star.fill"
    @State private var suggestedActivities: [String] = []
    @State private var customActivity = ""
    @State private var enableMovies = false
    @State private var enableBooks = false

    @Binding var hasCompletedOnboarding: Bool

    private let emojiOptions = ["😊", "👦", "👧", "👶", "🧒", "👨", "👩", "🎯", "⭐️", "🌟", "💪", "🏃", "🎨", "📚", "🎵", "⚽️"]

    private let availableIcons = [
        "star.fill", "heart.fill", "figure.run", "sportscourt.fill",
        "music.note", "paintbrush.fill", "book.fill", "graduationcap.fill",
        "bicycle", "football.fill", "basketball.fill", "tennisball.fill",
        "dumbbell.fill", "figure.dance", "theatermasks.fill", "gamecontroller.fill",
        "puzzlepiece.fill", "leaf.fill", "pawprint.fill", "house.fill"
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: 5)
                    .tint(.purple)
                    .padding()

                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        createUserStep
                    case 2:
                        descriptionStep
                    case 3:
                        suggestionsStep
                    case 4:
                        templatesStep
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Step 0: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.purple)

            Text("Welcome to Mighty")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track activities, build habits, and celebrate progress")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: { withAnimation { currentStep = 1 } }) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 1: Create User
    private var createUserStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Who's tracking?")
                .font(.title)
                .fontWeight(.bold)

            Text("Create a profile for the person you're tracking activities for")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Emoji picker
            Text(userEmoji)
                .font(.system(size: 60))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(emojiOptions, id: \.self) { emoji in
                    Button {
                        userEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(userEmoji == emoji ? Color.purple.opacity(0.3) : Color.clear)
                            )
                    }
                }
            }
            .padding(.horizontal, 32)

            TextField("Name", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: { withAnimation { currentStep = 2 } }) {
                Text("Next")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userName.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(userName.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 2: Description
    private var descriptionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("What would you like to track?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Describe what you want to track and we'll suggest activities")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("e.g., track my kids activities", text: $sectionDescription)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)
                .onKeyPress(.tab) {
                    if sectionDescription.isEmpty {
                        sectionDescription = "track my kids activities"
                    }
                    return .handled
                }

            Spacer()

            HStack(spacing: 16) {
                Button(action: { withAnimation { currentStep = 1 } }) {
                    Text("Back")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(white: 0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: generateSuggestionsAndAdvance) {
                    Text("Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(sectionDescription.isEmpty ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(sectionDescription.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3: Suggestions
    private var suggestionsStep: some View {
        VStack(spacing: 16) {
            Text("Customize Activities")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            // Section name and icon
            HStack(spacing: 12) {
                // Icon picker dropdown
                Menu {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Label(icon, systemImage: icon)
                        }
                    }
                } label: {
                    Image(systemName: selectedIcon)
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                TextField("Section name", text: $sectionName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            // Custom activity input
            HStack {
                TextField("Add custom activity", text: $customActivity)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addCustomActivity()
                    }

                Button(action: addCustomActivity) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(customActivity.isEmpty ? .gray : .purple)
                }
                .disabled(customActivity.isEmpty)
            }
            .padding(.horizontal)

            // Suggestion chips
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(suggestedActivities, id: \.self) { activity in
                        SuggestionChip(
                            title: activity,
                            onDelete: { suggestedActivities.removeAll { $0 == activity } }
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: { withAnimation { currentStep = 2 } }) {
                    Text("Back")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(white: 0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: { withAnimation { currentStep = 4 } }) {
                    Text("Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(sectionName.isEmpty ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(sectionName.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 4: Templates
    private var templatesStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Want to track more?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enable these templates to track movies and books with search integration")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                TemplateToggleCard(
                    icon: "film",
                    title: "Movies & TV Shows",
                    description: "Track what you watch with poster art",
                    isEnabled: $enableMovies
                )

                TemplateToggleCard(
                    icon: "book.fill",
                    title: "Books",
                    description: "Track your reading with cover images",
                    isEnabled: $enableBooks
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button(action: { withAnimation { currentStep = 3 } }) {
                        Text("Back")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(white: 0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: completeOnboarding) {
                        Text("Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }

                Button(action: completeOnboarding) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions
    private func generateSuggestionsAndAdvance() {
        suggestedActivities = ActivitySuggestionService.generateSuggestions(for: sectionDescription)
        sectionName = ActivitySuggestionService.extractSectionName(from: sectionDescription)
        withAnimation { currentStep = 3 }
    }

    private func addCustomActivity() {
        guard !customActivity.isEmpty else { return }
        if !suggestedActivities.contains(customActivity) {
            suggestedActivities.append(customActivity)
        }
        customActivity = ""
    }

    private func completeOnboarding() {
        // Create user with current account's ownerId
        let user = User(name: userName, emoji: userEmoji, ownerId: AuthState.shared.instantDBUserId)

        // Create first section
        let section = CustomSection(
            name: sectionName,
            icon: selectedIcon,
            suggestedActivities: suggestedActivities,
            user: user
        )
        user.customSections.append(section)
        user.tabOrder.append(section.id.uuidString)

        // Enable templates if selected
        if enableMovies {
            user.enabledTemplates.append("movies")
            user.tabOrder.append("movies")
        }
        if enableBooks {
            user.enabledTemplates.append("books")
            user.tabOrder.append("books")
        }

        // Mark onboarding complete
        user.hasCompletedOnboarding = true

        // Save
        modelContext.insert(user)
        modelContext.insert(section)

        hasCompletedOnboarding = true
    }
}

struct TemplateToggleCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(isEnabled ? Color.purple : Color(white: 0.2))
                    .foregroundColor(isEnabled ? .white : .gray)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isEnabled ? .purple : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? Color.purple : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
