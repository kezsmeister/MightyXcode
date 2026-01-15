import SwiftUI
import SwiftData
import PhotosUI

struct CustomEntryDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCustomEntries: [CustomEntry]

    let entry: CustomEntry

    @State private var title: String
    @State private var notes: String
    @State private var selectedDate: Date
    @State private var hasTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var notifyMe: Bool
    @State private var displayedImages: [UIImage] = []

    @State private var isEditing = false
    @State private var showingPermissionDenied = false
    @State private var showDeleteConfirmation = false
    @State private var showRecurringDeleteConfirmation = false
    @State private var showingSuggestions = false
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var fullscreenImageIndex: Int?
    @State private var conflicts: [TimeConflict] = []
    @FocusState private var isTitleFocused: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    init(entry: CustomEntry) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _notes = State(initialValue: entry.notes ?? "")
        _selectedDate = State(initialValue: entry.date)
        _hasTime = State(initialValue: entry.startTime != nil)
        let start = entry.startTime ?? Date()
        _startTime = State(initialValue: start)
        _hasEndTime = State(initialValue: entry.endTime != nil)
        // Default end time to 1 hour after start time if not set
        let end = entry.endTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
        _endTime = State(initialValue: end)
        _notifyMe = State(initialValue: entry.notifyBefore)
        let images = entry.imagesData.compactMap { UIImage(data: $0) }
        _displayedImages = State(initialValue: images)
    }

    private var filteredSuggestions: [String] {
        guard let section = entry.section else { return [] }
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
                // Section icon and name header
                if let section = entry.section {
                    Section {
                        HStack {
                            Image(systemName: section.icon)
                                .font(.title2)
                                .foregroundColor(.purple)
                            Text(section.name)
                                .font(.headline)
                            Spacer()
                        }
                    }
                }

                Section {
                    if isEditing {
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
                    } else {
                        HStack {
                            Text("Activity")
                            Spacer()
                            Text(title)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section {
                    if isEditing {
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                            .onChange(of: selectedDate) { _, _ in
                                if hasTime {
                                    checkForConflicts()
                                }
                            }
                    } else {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(dateFormatter.string(from: selectedDate))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section("Time") {
                    if isEditing {
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
                    } else {
                        if let timeRange = entry.formattedTimeRange {
                            HStack {
                                Text("Time")
                                Spacer()
                                Text(timeRange)
                                    .foregroundColor(.gray)
                            }
                            if entry.notifyBefore {
                                HStack {
                                    Text("Reminder")
                                    Spacer()
                                    Text("1 hour before")
                                        .foregroundColor(.gray)
                                }
                            }
                        } else {
                            HStack {
                                Text("Time")
                                Spacer()
                                Text("Not set")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                // Conflict warning (only in edit mode)
                if isEditing && hasTime && !conflicts.isEmpty {
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

                Section("Notes") {
                    if isEditing {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    } else {
                        Text(notes.isEmpty ? "No notes" : notes)
                            .foregroundColor(notes.isEmpty ? .gray : .primary)
                    }
                }

                Section("Photos (\(displayedImages.count)/5)") {
                    if !displayedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(displayedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .cornerRadius(8)
                                            .clipped()
                                            .onTapGesture {
                                                fullscreenImageIndex = index
                                            }

                                        Button {
                                            displayedImages.remove(at: index)
                                            savePhotoChange()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    if displayedImages.count < 5 {
                        Button {
                            showingPhotoOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Photo")
                            }
                        }
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
                    HStack(spacing: 16) {
                        Button {
                            // Show different dialog for recurring entries
                            if entry.recurrenceGroupId != nil {
                                showRecurringDeleteConfirmation = true
                            } else {
                                showDeleteConfirmation = true
                            }
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
            .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(entry.title)\"? This action cannot be undone.")
            }
            .confirmationDialog("Delete Recurring Activity", isPresented: $showRecurringDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete This Only", role: .destructive) {
                    deleteEntry()
                }
                Button("Delete All Recurring", role: .destructive) {
                    deleteAllRecurring()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is a recurring activity. Would you like to delete just this one or all occurrences?")
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .alert("Notifications Disabled", isPresented: $showingPermissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable notifications in Settings to receive reminders.")
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                if let image = image, displayedImages.count < 5 {
                    displayedImages.append(image)
                    savePhotoChange()
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   displayedImages.count < 5 {
                    displayedImages.append(image)
                    savePhotoChange()
                }
            }
        }
        .fullScreenCover(item: $fullscreenImageIndex) { index in
            FullscreenImageViewer(images: displayedImages, initialIndex: index)
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

    private func resetToOriginal() {
        title = entry.title
        notes = entry.notes ?? ""
        selectedDate = entry.date
        hasTime = entry.startTime != nil
        startTime = entry.startTime ?? Date()
        hasEndTime = entry.endTime != nil
        endTime = entry.endTime ?? Date()
        notifyMe = entry.notifyBefore
        showingSuggestions = false
        displayedImages = entry.imagesData.compactMap { UIImage(data: $0) }
        conflicts = []
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
            excludeEntryId: entry.id,
            allEntries: allCustomEntries
        )
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add new activity to suggestions if not already present
        if let section = entry.section, !trimmedTitle.isEmpty {
            let isNewActivity = !section.suggestedActivities.contains {
                $0.lowercased() == trimmedTitle.lowercased()
            }
            if isNewActivity {
                section.suggestedActivities.append(trimmedTitle)
            }
        }

        entry.title = trimmedTitle
        entry.notes = notes.isEmpty ? nil : notes
        entry.date = selectedDate
        entry.startTime = hasTime ? startTime : nil
        entry.endTime = (hasTime && hasEndTime) ? endTime : nil
        entry.notifyBefore = hasTime && notifyMe
        entry.imagesData = displayedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        // Update notification based on new settings
        if hasTime && notifyMe {
            NotificationManager.shared.rescheduleNotification(for: entry)
        } else {
            NotificationManager.shared.cancelNotification(for: entry)
        }

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)
    }

    private func deleteEntry() {
        // Cancel notification before deleting
        NotificationManager.shared.cancelNotification(for: entry)

        // Capture ID before deleting
        let entryId = entry.id

        // Mark as deleted to prevent sync from restoring it
        DeletionTracker.shared.markCustomEntryDeleted(entryId)

        // Delete locally
        modelContext.delete(entry)

        // Delete from cloud in background
        Task {
            try? await EntrySyncService.shared.deleteCustomEntryFromCloud(entryId: entryId)
        }

        dismiss()
    }

    private func deleteAllRecurring() {
        guard let groupId = entry.recurrenceGroupId else {
            // Fallback to single delete if no group
            deleteEntry()
            return
        }

        // Get the day of week and time of the entry being deleted
        let calendar = Calendar.current
        let entryWeekday = calendar.component(.weekday, from: entry.date)
        let entryStartTime = entry.startTime

        // Find all entries in the same recurrence group that match the same day of week and time
        let recurringEntries = allCustomEntries.filter { otherEntry in
            guard otherEntry.recurrenceGroupId == groupId else { return false }

            // Must be same day of week
            let otherWeekday = calendar.component(.weekday, from: otherEntry.date)
            guard otherWeekday == entryWeekday else { return false }

            // Must be same start time (if both have times)
            if let entryTime = entryStartTime, let otherTime = otherEntry.startTime {
                let entryHour = calendar.component(.hour, from: entryTime)
                let entryMinute = calendar.component(.minute, from: entryTime)
                let otherHour = calendar.component(.hour, from: otherTime)
                let otherMinute = calendar.component(.minute, from: otherTime)
                return entryHour == otherHour && entryMinute == otherMinute
            }

            // If neither has a time, they match
            return entryStartTime == nil && otherEntry.startTime == nil
        }

        // Delete all matching entries
        for recurringEntry in recurringEntries {
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: recurringEntry)

            // Mark as deleted to prevent sync from restoring it
            DeletionTracker.shared.markCustomEntryDeleted(recurringEntry.id)

            // Delete from cloud in background
            let entryId = recurringEntry.id
            Task {
                try? await EntrySyncService.shared.deleteCustomEntryFromCloud(entryId: entryId)
            }

            // Delete locally
            modelContext.delete(recurringEntry)
        }

        dismiss()
    }

    private func savePhotoChange() {
        entry.imagesData = displayedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Fullscreen Image Viewer

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct FullscreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let images: [UIImage]
    let initialIndex: Int

    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()

                if images.count > 1 {
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            currentIndex = initialIndex
        }
    }
}
