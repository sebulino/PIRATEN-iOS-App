//
//  NotificationsSheetView.swift
//  PIRATEN
//
//  Created by Claude Code on 18.02.26.
//

import SwiftUI

/// Sheet presenting notification settings.
/// Shown when user taps the bell icon in the navigation toolbar.
struct NotificationsSheetView: View {
    @ObservedObject var notificationSettings: NotificationSettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $notificationSettings.messagesEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nachrichten")
                                Text("Bei neuen privaten Nachrichten")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    Toggle(isOn: $notificationSettings.todosEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aufgaben")
                                Text("Bei neuen oder geänderten Aufgaben")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checklist")
                                .foregroundColor(.orange)
                        }
                    }

                    if notificationSettings.authorizationStatus == .denied {
                        Button {
                            notificationSettings.openSystemSettings()
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mitteilungen deaktiviert")
                                        .foregroundColor(.primary)
                                    Text("In den Einstellungen aktivieren")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    Text("Mitteilungen werden nur für die aktivierten Kategorien gesendet. Es werden keine Nachrichteninhalte übertragen – nur ein allgemeiner Hinweis.")
                        .font(.caption)
                }
            }
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NotificationsSheetView(
        notificationSettings: NotificationSettingsManager(
            deviceTokenManager: DeviceTokenManager()
        )
    )
}
