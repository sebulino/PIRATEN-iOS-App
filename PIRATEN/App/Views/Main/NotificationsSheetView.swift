//
//  NotificationsSheetView.swift
//  PIRATEN
//
//  Created by Claude Code on 18.02.26.
//

import SwiftUI
import UserNotifications

/// Sheet showing delivered notifications from the system notification center.
/// Shown when user taps the bell icon in the navigation toolbar.
struct NotificationsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [UNNotification] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                if !notifications.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Alle löschen") {
                            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                            notifications = []
                        }
                    }
                }
            }
            .task {
                await loadNotifications()
            }
        }
    }

    // MARK: - State Views

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Keine Benachrichtigungen")
                .font(.headline)
            Text("Du hast derzeit keine neuen Benachrichtigungen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationsList: some View {
        List {
            ForEach(notifications, id: \.request.identifier) { notification in
                NotificationRow(notification: notification)
            }
            .onDelete { indexSet in
                let identifiers = indexSet.map { notifications[$0].request.identifier }
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
                notifications.remove(atOffsets: indexSet)
            }
        }
    }

    // MARK: - Data Loading

    private func loadNotifications() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        // Show newest first
        notifications = delivered.sorted { $0.date > $1.date }
        isLoading = false
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: UNNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !notification.request.content.title.isEmpty {
                Text(notification.request.content.title)
                    .font(.headline)
            }
            if !notification.request.content.body.isEmpty {
                Text(notification.request.content.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(notification.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NotificationsSheetView()
}
