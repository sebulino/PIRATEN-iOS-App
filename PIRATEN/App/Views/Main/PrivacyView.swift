//
//  PrivacyView.swift
//  PIRATEN
//
//  Created by Claude Code on 12.02.26.
//

import SwiftUI

/// In-app privacy page summarizing data usage, storage, and user controls.
/// No analytics or tracking is performed by this app.
struct PrivacyView: View {

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Overview
                PrivacySection(title: "Überblick") {
                    Text("Diese App wird von der Piratenpartei für ihre Mitglieder bereitgestellt. Datenschutz und Privatsphäre sind zentrale Werte der Piratenpartei – das gilt auch für diese App.")
                        .font(.body)
                }

                // No tracking
                PrivacySection(title: "Kein Tracking", footer: "Es werden keinerlei Analytics-SDKs, Tracking-Dienste oder Werbenetzwerke eingesetzt.") {
                    Label {
                        Text("Kein Tracking oder Analytics")
                    } icon: {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.piratenPrimary)
                    }

                    Label {
                        Text("Keine Verhaltensanalyse")
                    } icon: {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.piratenPrimary)
                    }

                    Label {
                        Text("Keine Werbung oder Profiling")
                    } icon: {
                        Image(systemName: "person.badge.minus")
                            .foregroundColor(.piratenPrimary)
                    }
                }

                // Data usage
                PrivacySection(title: "Datenverwendung") {
                    PrivacyRow(
                        icon: "key.fill",
                        title: "Anmeldedaten",
                        detail: "Dein Passwort wird nur im System-Browser eingegeben und nie von der App gespeichert. Login-Tokens werden verschlüsselt in der iOS Keychain abgelegt."
                    )

                    PrivacyRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "Forum & Nachrichten",
                        detail: "Inhalte werden direkt vom Discourse-Server geladen und nicht auf deinem Gerät gespeichert. Die App ist ein Thin Client."
                    )

                    PrivacyRow(
                        icon: "checklist",
                        title: "Aufgaben",
                        detail: "Aufgaben werden vom Server geladen. Es findet keine lokale Speicherung statt."
                    )

                    PrivacyRow(
                        icon: "person.circle",
                        title: "Profildaten",
                        detail: "Dein Name, E-Mail und Mitgliedsdaten stammen aus dem SSO-System. Sie werden nur zur Anzeige geladen und nicht dauerhaft gespeichert."
                    )

                    PrivacyRow(
                        icon: "book",
                        title: "Wissen",
                        detail: "Lerninhalte werden von GitHub geladen und lokal zwischengespeichert (24 Stunden). Dein Lesefortschritt wird lokal auf deinem Gerät gespeichert."
                    )
                }

                // Notifications
                PrivacySection(title: "Mitteilungen") {
                    PrivacyRow(
                        icon: "bell",
                        title: "Push-Mitteilungen",
                        detail: "Mitteilungen sind standardmäßig deaktiviert (Opt-in). Es werden keine Nachrichteninhalte oder Absendernamen übertragen – nur ein allgemeiner Hinweis."
                    )

                    PrivacyRow(
                        icon: "gear",
                        title: "Mitteilungseinstellungen",
                        detail: "Du kannst Mitteilungen für Nachrichten und Aufgaben einzeln aktivieren oder deaktivieren. Die Einstellungen findest du auf der Profilseite."
                    )
                }

                // Local storage
                PrivacySection(title: "Datenspeicherung") {
                    PrivacyRow(
                        icon: "lock.shield",
                        title: "Sichere Speicherung",
                        detail: "Zugangsdaten werden ausschließlich in der iOS Keychain gespeichert (hardwareverschlüsselt, nicht in Backups enthalten)."
                    )

                    PrivacyRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Abmeldung",
                        detail: "Bei der Abmeldung werden alle gespeicherten Zugangsdaten und Mitteilungseinstellungen gelöscht."
                    )

                    PrivacyRow(
                        icon: "internaldrive",
                        title: "Lokale Daten",
                        detail: "Mitteilungseinstellungen und Lesefortschritt werden lokal gespeichert. Alle anderen Daten werden nur zur Anzeige geladen."
                    )
                }

                // Permissions
                PrivacySection(title: "Berechtigungen") {
                    PrivacyRow(
                        icon: "bell.badge",
                        title: "Mitteilungen",
                        detail: "Nur wenn du Mitteilungen aktivierst, wird die Systemberechtigung angefragt. Du kannst sie jederzeit in den iOS-Einstellungen widerrufen."
                    )

                    PrivacyRow(
                        icon: "network",
                        title: "Netzwerk",
                        detail: "Alle Verbindungen verwenden HTTPS. Es gibt keine Verbindungen zu Drittanbietern außer dem SSO-Server, dem Discourse-Forum und GitHub (für Wissensinhalte)."
                    )
                }

                // Contact
                Text("Bei Fragen zum Datenschutz wende dich an die Piratenpartei.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Datenschutz")
    }
}

/// A section container that mimics grouped List section styling using VStack.
/// Used instead of List sections to avoid UICollectionView dequeue crashes.
private struct PrivacySection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content

    init(title: String, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

/// A row displaying a privacy topic with icon, title, and detail text.
private struct PrivacyRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(.piratenPrimary)
            }

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}
