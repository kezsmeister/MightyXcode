import SwiftUI
import SwiftData

struct AddEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let mediaType: MediaType
    let user: User

    @State private var title = ""
    @State private var imageURL = ""
    @State private var rating: Int = 0
    @State private var notes = ""
    @State private var selectedType: MediaType
    @State private var selectedVideoType: VideoType = .movie
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isDateRange = false

    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var showDropdown = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelectingResult = false
    @FocusState private var isTitleFocused: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    init(date: Date, mediaType: MediaType, user: User) {
        self.date = date
        self.mediaType = mediaType
        self.user = user
        _selectedType = State(initialValue: mediaType)
        _startDate = State(initialValue: date)
        _endDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Title", text: $title)
                            .focused($isTitleFocused)
                            .onChange(of: title) {
                                performSearch()
                            }

                        if showDropdown && !searchResults.isEmpty {
                            searchDropdown
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .onTapGesture {
                                        rating = star == rating ? 0 : star
                                    }
                            }
                        }
                    }
                }

                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MediaType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .onChange(of: selectedType) {
                        if !title.isEmpty {
                            performSearch()
                        }
                        // Reset date range when switching to movies
                        if selectedType == .movies {
                            isDateRange = false
                        }
                    }

                    if selectedType == .movies {
                        Picker("", selection: $selectedVideoType) {
                            ForEach(VideoType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedVideoType) {
                            if !title.isEmpty {
                                performSearch()
                            }
                        }
                    }

                    if selectedType == .books {
                        Toggle("Date Range", isOn: $isDateRange)
                    }

                    if isDateRange && selectedType == .books {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add \(selectedType.rawValue.dropLast())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .task {
            // Small delay to ensure view is fully presented before focusing
            try? await Task.sleep(for: .milliseconds(300))
            isTitleFocused = true
        }
    }

    private var searchDropdown: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 8)

            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
        Button(action: {
            selectResult(result)
        }) {
            HStack(spacing: 12) {
                if let imageURL = result.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let year = result.year {
                        Text(year)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 56)
            .overlay(
                Image(systemName: selectedType == .movies ? selectedVideoType.icon : selectedType.icon)
                    .foregroundColor(.gray)
            )
    }

    private func performSearch() {
        searchTask?.cancel()

        guard !isSelectingResult else {
            isSelectingResult = false
            return
        }

        guard title.count >= 3 else {
            searchResults = []
            showDropdown = false
            return
        }

        showDropdown = true
        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            let results: [SearchResult]
            switch selectedType {
            case .movies:
                switch selectedVideoType {
                case .movie:
                    results = await MediaSearchService.shared.searchMovies(query: title)
                case .tvShow:
                    results = await MediaSearchService.shared.searchTVShows(query: title)
                }
            case .books:
                results = await MediaSearchService.shared.searchBooks(query: title)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func selectResult(_ result: SearchResult) {
        isSelectingResult = true
        showDropdown = false
        searchResults = []
        title = result.title
        if let url = result.imageURL {
            imageURL = url
        }
        isTitleFocused = false
    }

    private func saveEntry() {
        let entry = MediaEntry(
            title: title,
            mediaType: selectedType,
            videoType: selectedType == .movies ? selectedVideoType : nil,
            date: startDate,
            endDate: isDateRange ? endDate : nil,
            imageURL: imageURL.isEmpty ? nil : imageURL,
            rating: rating > 0 ? rating : nil,
            notes: notes.isEmpty ? nil : notes,
            user: user
        )
        modelContext.insert(entry)

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)

        dismiss()
    }
}

// Preview requires a User object, so disabled for now
