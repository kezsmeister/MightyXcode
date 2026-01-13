import SwiftUI
import SwiftData

struct SectionSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let section: CustomSection

    @State private var notificationsEnabled: Bool
    @State private var showingPermissionDeniedAlert = false

    init(section: CustomSection) {
        self.section = section
        _notificationsEnabled = State(initialValue: section.notificationsEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: section.icon)
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text(section.name)
                            .font(.headline)
                    }
                }

                Section("Notifications") {
                    Toggle("Activity Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(newValue)
                        }

                    if notificationsEnabled {
                        Text("You'll be notified 1 hour before activities with a scheduled time")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Section Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Notifications Disabled", isPresented: $showingPermissionDeniedAlert) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive activity reminders.")
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    section.notificationsEnabled = true
                    NotificationManager.shared.scheduleAllNotifications(for: section)
                } else {
                    notificationsEnabled = false
                    showingPermissionDeniedAlert = true
                }
            }
        } else {
            section.notificationsEnabled = false
            NotificationManager.shared.cancelAllNotifications(for: section)
        }
    }
}
