import SwiftUI
import SwiftData

struct EntryDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: MediaEntry

    @State private var title: String
    @State private var imageURL: String
    @State private var rating: Int
    @State private var notes: String
    @State private var selectedType: MediaType
    @State private var selectedVideoType: VideoType
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isDateRange: Bool

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

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

    init(entry: MediaEntry) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _imageURL = State(initialValue: entry.imageURL ?? "")
        _rating = State(initialValue: entry.rating ?? 0)
        _notes = State(initialValue: entry.notes ?? "")
        _selectedType = State(initialValue: entry.mediaType)
        _selectedVideoType = State(initialValue: entry.videoType ?? .movie)
        _startDate = State(initialValue: entry.date)
        _endDate = State(initialValue: entry.endDate ?? entry.date)
        _isDateRange = State(initialValue: entry.endDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Cover image preview
                if !imageURL.isEmpty {
                    Section {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure(_):
                                Label("Failed to load image", systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }

                Section {
                    if isEditing {
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
                    } else {
                        HStack {
                            Text("Title")
                            Spacer()
                            Text(title)
                                .foregroundColor(.gray)
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
                                        if isEditing {
                                            rating = star == rating ? 0 : star
                                        }
                                    }
                            }
                        }
                    }
                }

                Section {
                    if isEditing {
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
                    } else {
                        HStack {
                            Text("Type")
                            Spacer()
                            if selectedType == .movies {
                                Label(selectedVideoType.rawValue, systemImage: selectedVideoType.icon)
                                    .foregroundColor(.gray)
                            } else {
                                Label(selectedType.rawValue, systemImage: selectedType.icon)
                                    .foregroundColor(.gray)
                            }
                        }

                        if isDateRange {
                            HStack {
                                Text("Date Range")
                                Spacer()
                                Text("\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))")
                                    .foregroundColor(.gray)
                            }
                        } else {
                            HStack {
                                Text("Date")
                                Spacer()
                                Text(dateFormatter.string(from: startDate))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section("Notes") {
                    if isEditing {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    } else {
                        Text(notes.isEmpty ? "No notes" : notes)
                            .foregroundColor(notes.isEmpty ? .gray : .primary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Entry" : "Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            resetToOriginal()
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // Only show edit/delete buttons if user can edit
                    if AuthState.shared.canEdit {
                        HStack(spacing: 16) {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }

                            Button(isEditing ? "Save" : "Edit") {
                                if isEditing {
                                    saveChanges()
                                    isEditing = false
                                } else {
                                    isEditing = true
                                }
                            }
                            .disabled(isEditing && title.isEmpty)
                        }
                    }
                }
            }
            .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(entry.title)\"? This action cannot be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
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
                if let url = result.imageURL {
                    AsyncImage(url: URL(string: url)) { phase in
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
            try? await Task.sleep(nanoseconds: 300_000_000)

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

    private func resetToOriginal() {
        title = entry.title
        imageURL = entry.imageURL ?? ""
        rating = entry.rating ?? 0
        notes = entry.notes ?? ""
        selectedType = entry.mediaType
        selectedVideoType = entry.videoType ?? .movie
        startDate = entry.date
        endDate = entry.endDate ?? entry.date
        isDateRange = entry.endDate != nil
        showDropdown = false
        searchResults = []
    }

    private func saveChanges() {
        entry.title = title
        entry.imageURL = imageURL.isEmpty ? nil : imageURL
        entry.rating = rating > 0 ? rating : nil
        entry.notes = notes.isEmpty ? nil : notes
        entry.mediaType = selectedType
        entry.videoType = selectedType == .movies ? selectedVideoType : nil
        entry.date = startDate
        entry.endDate = isDateRange ? endDate : nil

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)
    }

    private func deleteEntry() {
        // Capture ID before deleting
        let entryId = entry.id

        // Mark as deleted to prevent sync from restoring it
        DeletionTracker.shared.markMediaEntryDeleted(entryId)

        // Delete locally
        modelContext.delete(entry)

        // Delete from cloud in background
        Task {
            try? await EntrySyncService.shared.deleteMediaEntryFromCloud(entryId: entryId)
        }

        dismiss()
    }
}
