import SwiftUI
import SwiftData

struct UserManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \User.createdAt) private var allUsers: [User]

    @Binding var selectedUser: User?

    // Filter users by current authenticated account
    private var users: [User] {
        let currentOwnerId = AuthState.shared.instantDBUserId
        if let ownerId = currentOwnerId {
            return allUsers.filter { $0.ownerId == ownerId }
        } else {
            return allUsers.filter { $0.ownerId == nil }
        }
    }

    @State private var showingAddUser = false
    @State private var userToEdit: User?
    @State private var showDeleteConfirmation = false
    @State private var userToDelete: User?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(users) { user in
                        UserRow(
                            user: user,
                            isSelected: selectedUser?.id == user.id,
                            onSelect: {
                                selectedUser = user
                                dismiss()
                            },
                            onEdit: {
                                userToEdit = user
                            },
                            onDelete: {
                                userToDelete = user
                                showDeleteConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("Users")
                } footer: {
                    Text("Tap to switch user. Swipe for options.")
                }

                Section {
                    Button(action: { showingAddUser = true }) {
                        Label("Add New User", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("Manage Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddUser) {
                AddUserSheet()
            }
            .sheet(item: $userToEdit) { user in
                EditUserSheet(user: user)
            }
            .confirmationDialog("Delete User", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let user = userToDelete {
                        deleteUser(user)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let user = userToDelete {
                    Text("Delete \"\(user.name)\"? All their entries will also be deleted. This cannot be undone.")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func deleteUser(_ user: User) {
        // If deleting the selected user, switch to another user
        if selectedUser?.id == user.id {
            selectedUser = users.first { $0.id != user.id }
        }

        // Capture ID before deleting
        let userId = user.id

        // Mark as deleted to prevent sync from restoring it
        DeletionTracker.shared.markProfileDeleted(userId)

        // Delete locally
        modelContext.delete(user)

        // Delete from cloud in background
        Task {
            try? await ProfileSyncService.shared.deleteProfileFromCloud(userId: userId)
        }
    }
}

struct UserRow: View {
    let user: User
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var totalEntryCount: Int {
        let mediaCount = user.entries.count
        let customCount = user.customSections.reduce(0) { $0 + $1.entries.count }
        return mediaCount + customCount
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Text(user.emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(totalEntryCount) entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddUserSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedEmoji = "😊"
    @FocusState private var isNameFocused: Bool

    private let emojis = ["😊", "😎", "🤓", "👶", "👧", "👦", "👩", "👨", "👵", "👴", "🦸", "🧚", "🐱", "🐶", "🦊", "🐼"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Enter name", text: $name)
                        .focused($isNameFocused)
                }

                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.purple.opacity(0.3) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedEmoji == emoji ? Color.purple : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedEmoji = emoji
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addUser()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isNameFocused = true
        }
    }

    private func addUser() {
        let user = User(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: selectedEmoji,
            ownerId: AuthState.shared.instantDBUserId
        )
        user.hasCompletedOnboarding = true  // Skip onboarding for manually added users

        // Create default "Kids Activities" section
        let defaultSection = CustomSection(
            name: "Kids Activities",
            icon: "figure.play",
            suggestedActivities: ["Soccer", "Piano", "Swimming", "Dance", "Art Class", "Gymnastics"],
            user: user
        )
        user.customSections.append(defaultSection)
        user.tabOrder.append(defaultSection.id.uuidString)

        modelContext.insert(user)
        modelContext.insert(defaultSection)

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)

        dismiss()
    }
}

struct EditUserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let user: User

    @State private var name: String
    @State private var selectedEmoji: String
    @FocusState private var isNameFocused: Bool

    private let emojis = ["😊", "😎", "🤓", "👶", "👧", "👦", "👩", "👨", "👵", "👴", "🦸", "🧚", "🐱", "🐶", "🦊", "🐼"]

    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name)
        _selectedEmoji = State(initialValue: user.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Enter name", text: $name)
                        .focused($isNameFocused)
                }

                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.purple.opacity(0.3) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedEmoji == emoji ? Color.purple : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedEmoji = emoji
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isNameFocused = true
        }
    }

    private func saveChanges() {
        user.name = name.trimmingCharacters(in: .whitespaces)
        user.emoji = selectedEmoji

        // Trigger background sync
        SyncManager.shared.triggerSync(context: modelContext)

        dismiss()
    }
}
