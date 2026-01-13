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
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var authState = AuthState.shared
    @State private var isSigningOut = false
    @State private var signOutError: String?

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

                        Button {
                            syncProfiles()
                        } label: {
                            HStack {
                                Label("Sync Profiles", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if isSyncing {
                                    ProgressView()
                                        .tint(.purple)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .disabled(isSyncing)

                        if let message = syncMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(message.contains("Error") ? .red : .green)
                        }

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
        }
        .preferredColorScheme(.dark)
    }

    private func syncProfiles() {
        guard user != nil else { return }

        isSyncing = true
        syncMessage = nil

        Task {
            do {
                try await ProfileSyncService.shared.performFullSync(context: modelContext)
                await MainActor.run {
                    isSyncing = false
                    syncMessage = "Synced successfully"
                    // Clear message after 3 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        await MainActor.run {
                            syncMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncMessage = "Error: \(error.localizedDescription)"
                }
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
