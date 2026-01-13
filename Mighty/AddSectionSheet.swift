import SwiftUI
import SwiftData

struct AddSectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let user: User

    @State private var currentStep = 0
    @State private var sectionDescription = ""
    @State private var sectionName = ""
    @State private var selectedIcon = "star.fill"
    @State private var suggestedActivities: [String] = []
    @State private var customActivity = ""
    @State private var detectedTemplate: DetectedTemplate?
    @State private var showTemplatePrompt = false

    private enum DetectedTemplate {
        case movies
        case books

        var title: String {
            switch self {
            case .movies: return "Movies & TV Shows"
            case .books: return "Books"
            }
        }

        var icon: String {
            switch self {
            case .movies: return "film"
            case .books: return "book.fill"
            }
        }

        var description: String {
            switch self {
            case .movies: return "Track what you watch with poster art and search integration"
            case .books: return "Track your reading with cover images and search integration"
            }
        }

        var templateId: String {
            switch self {
            case .movies: return "movies"
            case .books: return "books"
            }
        }
    }

    private static let movieKeywords = ["movie", "movies", "film", "films", "tv", "television", "shows", "series", "watch", "watching", "netflix", "cinema"]
    private static let bookKeywords = ["book", "books", "reading", "read", "novels", "literature", "library"]

    private let availableIcons = [
        "star.fill", "heart.fill", "figure.run", "sportscourt.fill",
        "music.note", "paintbrush.fill", "book.fill", "graduationcap.fill",
        "bicycle", "football.fill", "basketball.fill", "tennisball.fill",
        "dumbbell.fill", "figure.dance", "theatermasks.fill", "gamecontroller.fill",
        "puzzlepiece.fill", "leaf.fill", "pawprint.fill", "house.fill"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .tint(.purple)
                    .padding()

                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        descriptionStep
                    case 1:
                        suggestionsStep
                    case 2:
                        finalizeStep
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .alert("Use Built-in Template?", isPresented: $showTemplatePrompt) {
            Button("Use \(detectedTemplate?.title ?? "Template")", role: .none) {
                if let template = detectedTemplate {
                    enableTemplate(template)
                }
            }
            Button("Create Custom Section", role: .cancel) {
                proceedWithCustomSection()
            }
        } message: {
            if let template = detectedTemplate {
                Text("We have a built-in \(template.title) section with search integration and cover images. Would you like to use it instead?")
            }
        }
    }

    // MARK: - Step 1: Description
    private var descriptionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "plus.rectangle.on.folder.fill")
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

            Spacer()

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
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 2: Suggestions
    private var suggestionsStep: some View {
        VStack(spacing: 16) {
            Text("Suggested Activities")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            Text("Add, remove, or customize activities for your section")
                .font(.subheadline)
                .foregroundColor(.gray)

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

            // Navigation buttons
            HStack {
                Button("Back") {
                    currentStep = 0
                }
                .foregroundColor(.gray)

                Spacer()

                Button(action: { currentStep = 2 }) {
                    Text("Next")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3: Finalize
    private var finalizeStep: some View {
        VStack(spacing: 24) {
            Text("Customize Your Section")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            // Section name
            VStack(alignment: .leading, spacing: 8) {
                Text("Section Name")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("Section name", text: $sectionName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon ? Color.purple : Color(white: 0.2))
                                )
                                .foregroundColor(selectedIcon == icon ? .white : .gray)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Preview
            VStack(spacing: 8) {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                HStack(spacing: 6) {
                    Image(systemName: selectedIcon)
                        .font(.caption)
                    Text(sectionName.isEmpty ? "Section Name" : sectionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.purple)
                )
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button("Back") {
                    currentStep = 1
                }
                .foregroundColor(.gray)

                Spacer()

                Button(action: saveSection) {
                    Text("Create Section")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
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

    // MARK: - Actions
    private func generateSuggestionsAndAdvance() {
        // Check for Movies/Books template match first
        if let detected = detectTemplate(from: sectionDescription) {
            // Check if template is already enabled
            if !user.enabledTemplates.contains(detected.templateId) {
                detectedTemplate = detected
                showTemplatePrompt = true
                return
            }
        }

        // Generate suggestions for custom section
        suggestedActivities = ActivitySuggestionService.generateSuggestions(for: sectionDescription)
        sectionName = ActivitySuggestionService.extractSectionName(from: sectionDescription)
        currentStep = 1
    }

    private func detectTemplate(from description: String) -> DetectedTemplate? {
        let lowercased = description.lowercased()

        // Check for movie keywords
        for keyword in Self.movieKeywords {
            if lowercased.contains(keyword) {
                return .movies
            }
        }

        // Check for book keywords
        for keyword in Self.bookKeywords {
            if lowercased.contains(keyword) {
                return .books
            }
        }

        return nil
    }

    private func enableTemplate(_ template: DetectedTemplate) {
        user.enabledTemplates.append(template.templateId)
        user.tabOrder.append(template.templateId)
        dismiss()
    }

    private func proceedWithCustomSection() {
        suggestedActivities = ActivitySuggestionService.generateSuggestions(for: sectionDescription)
        sectionName = ActivitySuggestionService.extractSectionName(from: sectionDescription)
        showTemplatePrompt = false
        currentStep = 1
    }

    private func addCustomActivity() {
        guard !customActivity.isEmpty else { return }
        if !suggestedActivities.contains(customActivity) {
            suggestedActivities.append(customActivity)
        }
        customActivity = ""
    }

    private func saveSection() {
        let section = CustomSection(
            name: sectionName,
            icon: selectedIcon,
            suggestedActivities: suggestedActivities,
            user: user
        )
        user.customSections.append(section)
        user.tabOrder.append(section.id.uuidString)
        modelContext.insert(section)
        dismiss()
    }
}

// MARK: - Supporting Views

struct SuggestionChip: View {
    let title: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.2))
        .cornerRadius(16)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}
