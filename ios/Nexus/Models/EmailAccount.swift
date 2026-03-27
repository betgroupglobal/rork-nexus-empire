import Foundation
import SwiftUI

nonisolated enum EmailProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case gmail = "Gmail"
    case outlook = "Outlook"
    case yahoo = "Yahoo"
    case imap = "IMAP"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gmail: "envelope.fill"
        case .outlook: "envelope.badge.fill"
        case .yahoo: "envelope.open.fill"
        case .imap: "server.rack"
        }
    }

    var color: Color {
        switch self {
        case .gmail: .red
        case .outlook: .blue
        case .yahoo: .purple
        case .imap: .orange
        }
    }

    var subtitle: String {
        switch self {
        case .gmail: "Google Gmail"
        case .outlook: "Microsoft Outlook"
        case .yahoo: "Yahoo Mail"
        case .imap: "IMAP / Custom"
        }
    }

    var defaultIMAPHost: String {
        switch self {
        case .gmail: "imap.gmail.com"
        case .outlook: "outlook.office365.com"
        case .yahoo: "imap.mail.yahoo.com"
        case .imap: ""
        }
    }

    var defaultIMAPPort: Int { 993 }

    var defaultSMTPHost: String {
        switch self {
        case .gmail: "smtp.gmail.com"
        case .outlook: "smtp.office365.com"
        case .yahoo: "smtp.mail.yahoo.com"
        case .imap: ""
        }
    }

    var defaultSMTPPort: Int {
        switch self {
        case .gmail: 587
        case .outlook: 587
        case .yahoo: 587
        case .imap: 587
        }
    }

    var requiresAppPassword: Bool {
        switch self {
        case .gmail, .yahoo: true
        case .outlook, .imap: false
        }
    }

    var appPasswordHelp: String {
        switch self {
        case .gmail: "Enable 2FA on your Google account, then generate an App Password at myaccount.google.com/apppasswords"
        case .yahoo: "Generate an App Password in Yahoo Account Security settings"
        case .outlook, .imap: ""
        }
    }
}

nonisolated enum EmailLoginStatus: String, Codable, Sendable {
    case loggedIn = "Logged In"
    case loggedOut = "Logged Out"
    case error = "Error"
    case authenticating = "Authenticating"
}

struct EmailAccount: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var provider: EmailProvider
    var emailAddress: String
    var displayName: String
    var isConnected: Bool
    var loginStatus: EmailLoginStatus
    var imapHost: String
    var imapPort: Int
    var smtpHost: String
    var smtpPort: Int
    var useSSL: Bool
    var lastSyncDate: Date?
    var loginError: String?
    var addedDate: Date

    init(
        id: UUID = UUID(),
        provider: EmailProvider,
        emailAddress: String,
        displayName: String = "",
        isConnected: Bool = false,
        loginStatus: EmailLoginStatus = .loggedOut,
        imapHost: String = "",
        imapPort: Int = 993,
        smtpHost: String = "",
        smtpPort: Int = 587,
        useSSL: Bool = true,
        lastSyncDate: Date? = nil,
        loginError: String? = nil,
        addedDate: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.emailAddress = emailAddress
        self.displayName = displayName.isEmpty ? emailAddress : displayName
        self.isConnected = isConnected
        self.loginStatus = loginStatus
        self.imapHost = imapHost.isEmpty ? provider.defaultIMAPHost : imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost.isEmpty ? provider.defaultSMTPHost : smtpHost
        self.smtpPort = smtpPort
        self.useSSL = useSSL
        self.lastSyncDate = lastSyncDate
        self.loginError = loginError
        self.addedDate = addedDate
    }
}
