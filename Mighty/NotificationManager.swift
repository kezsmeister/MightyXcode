import Foundation
import UserNotifications
import os.log

private let notificationLogger = Logger(subsystem: "com.mighty.app", category: "Notifications")

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    notificationLogger.error("Notification permission error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(granted)
            }
        }
    }

    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Schedule Notifications

    func scheduleNotification(for entry: CustomEntry) {
        guard let startTime = entry.startTime,
              entry.notifyBefore else {
            return
        }

        // Combine entry.date with startTime to get the full datetime
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute

        guard let activityTime = calendar.date(from: combinedComponents) else { return }

        // Schedule 1 hour before
        guard let notificationTime = calendar.date(byAdding: .hour, value: -1, to: activityTime) else { return }

        // Don't schedule if notification time is in the past
        if notificationTime <= Date() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Activity Reminder"
        content.body = "\(entry.title) in 1 hour"
        if let sectionName = entry.section?.name {
            content.subtitle = sectionName
        }
        content.sound = .default

        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: entry.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                notificationLogger.error("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelNotification(for entry: CustomEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [entry.id.uuidString])
    }

    func cancelAllNotifications(for section: CustomSection) {
        let identifiers = section.entries.map { $0.id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Reschedule

    func rescheduleNotification(for entry: CustomEntry) {
        cancelNotification(for: entry)
        scheduleNotification(for: entry)
    }

    // MARK: - Schedule all for section

    func scheduleAllNotifications(for section: CustomSection) {
        for entry in section.entries where entry.startTime != nil && entry.notifyBefore {
            scheduleNotification(for: entry)
        }
    }

    // MARK: - Batch Scheduling for Recurring Entries

    func scheduleNotifications(for entries: [CustomEntry]) {
        // iOS limits pending notifications to 64
        // Schedule only upcoming entries (sorted by date)
        let upcomingEntries = entries
            .filter { $0.startTime != nil && $0.notifyBefore && $0.date >= Date() }
            .sorted { $0.date < $1.date }
            .prefix(60) // Leave some room for other notifications

        for entry in upcomingEntries {
            scheduleNotification(for: entry)
        }
    }

    func cancelNotifications(for groupId: UUID, entries: [CustomEntry]) {
        let groupEntries = entries.filter { $0.recurrenceGroupId == groupId }
        let identifiers = groupEntries.map { $0.id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap if needed
        completionHandler()
    }
}
