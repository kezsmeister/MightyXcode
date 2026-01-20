import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [MediaEntry]

    let user: User?

    @State private var showingDeleteAlert = false
    @State private var showingTemplateManager = false
    @State private var showingLoginSheet = false
    @State private var showingFamilySharing = false
    @State private var authState = AuthState.shared
    @State private var syncManager = SyncManager.shared
    @State private var isSigningOut = false
    @State private var signOutError: String?
    @State private var familyMemberCount = 0

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    if authState.isAuthenticated {
                        HStack {
                            Label("Email", systemImage: "envelope")
                            Spacer()
                            Text(authState.currentUserEmail ?? "")
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        // Sync Status
                        HStack {
                            Label("Cloud Sync", systemImage: "icloud")
                            Spacer()
                            syncStatusView
                        }

                        if let lastSync = syncManager.lastSyncDescription {
                            Text("Last synced \(lastSync)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        // Manual sync button (fallback)
                        Button {
                            Task {
                                await syncManager.performFullSync(context: modelContext)
                            }
                        } label: {
                            HStack {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if syncManager.isSyncing {
                                    ProgressView()
                                        .tint(.purple)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .disabled(syncManager.isSyncing)

                        Button(role: .destructive) {
                            signOut()
                        } label: {
                            HStack {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                                if isSigningOut {
                                    ProgressView()
                                        .tint(.red)
                                }
                            }
                        }
                        .disabled(isSigningOut)

                        if let error = signOutError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        Button {
                            showingLoginSheet = true
                        } label: {
                            Label("Sign In", systemImage: "person.crop.circle")
                        }
                        .foregroundColor(.purple)

                        Text("Sign in to sync profiles across devices")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Family Sharing Section - only show when authenticated
                if authState.isAuthenticated {
                    Section("Family Sharing") {
                        Button {
                            showingFamilySharing = true
                        } label: {
                            HStack {
                                Label("Manage Family", systemImage: "person.2")
                                Spacer()
                                if familyMemberCount > 1 {
                                    Text("\(familyMemberCount) members")
                                        .foregroundColor(.gray)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.white)

                        Text("Invite partners, co-parents, or caregivers to view your activities")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                if let user = user {
                    Section("Templates") {
                        Button {
                            showingTemplateManager = true
                        } label: {
                            HStack {
                                Label("Manage Templates", systemImage: "square.stack.3d.up")
                                Spacer()
                                Text("\(user.enabledTemplates.count) enabled")
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.white)
                    }
                }

                Section("Statistics") {
                    HStack {
                        Label("Movies", systemImage: "film")
                        Spacer()
                        Text("\(movieCount)")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Label("Books", systemImage: "book")
                        Spacer()
                        Text("\(bookCount)")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Label("Total Entries", systemImage: "calendar")
                        Spacer()
                        Text("\(userEntries.count)")
                            .foregroundColor(.gray)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("App")
                        Spacer()
                        Text("Mighty")
                            .foregroundColor(.gray)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your entries. This action cannot be undone.")
            }
            .sheet(isPresented: $showingTemplateManager) {
                if let user = user {
                    TemplateManagerSheet(user: user)
                }
            }
            .sheet(isPresented: $showingLoginSheet) {
                LoginView()
            }
            .sheet(isPresented: $showingFamilySharing) {
                FamilySharingView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadFamilyMemberCount()
        }
    }

    private func loadFamilyMemberCount() async {
        guard authState.isAuthenticated else { return }
        do {
            let response = try await FamilySharingService.shared.getMembers()
            await MainActor.run {
                familyMemberCount = response.members.count
            }
        } catch {
            // Silently fail - count will just show 0
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch syncManager.syncStatus {
        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)
        case .syncing(let message):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Synced")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        signOutError = nil

        Task {
            do {
                try await AuthenticationService.shared.logout()
                await MainActor.run {
                    isSigningOut = false
                    // Auth state will update automatically, dismissing account section
                }
            } catch {
                await MainActor.run {
                    isSigningOut = false
                    signOutError = "Sign out failed: \(error.localizedDescription)"
                    print("[Auth] Sign out error: \(error)")
                }
            }
        }
    }

    // Filter entries for current user only
    private var userEntries: [MediaEntry] {
        guard let user = user else { return [] }
        return entries.filter { $0.user?.id == user.id }
    }

    private var movieCount: Int {
        userEntries.filter { $0.mediaType == .movies }.count
    }

    private var bookCount: Int {
        userEntries.filter { $0.mediaType == .books }.count
    }

    private func deleteAllData() {
        guard let user = user else { return }

        // Delete all media entries for current user
        for entry in userEntries {
            modelContext.delete(entry)
        }

        // Delete all custom entries for current user
        for section in user.customSections {
            for entry in section.entries {
                modelContext.delete(entry)
            }
        }
    }
}

#Preview {
    SettingsView(user: nil)
        .modelContainer(for: [MediaEntry.self, User.self, CustomSection.self, CustomEntry.self], inMemory: true)
}
