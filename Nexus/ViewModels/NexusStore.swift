import Foundation
import SwiftUI

@Observable
@MainActor
class NexusStore {
    var communications: [Communication] = []
    var emails: [EmailMessage] = []
    var alerts: [NexusAlert] = []
    var isLoading: Bool = false
    var lastError: String?

    var ctBalance: Double?
    var ctDIDs: [CTDIDNumber] = []
    var ctConnectionStatus: CTConnectionStatus = .disconnected
    var ctError: String?
    var ctIsLoading: Bool = false
    var smsSending: Bool = false
    var smsError: String?
    var smsSuccess: Bool = false

    var emailAccounts: [EmailAccount] = []

    var crazytelAPIKey: String {
        get { KeychainService.load(key: "crazytel_api_key") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(key: "crazytel_api_key")
            } else {
                KeychainService.save(key: "crazytel_api_key", value: newValue)
            }
        }
    }

    @ObservationIgnored @AppStorage("crazytel_enabled") var crazytelEnabled: Bool = false

    private let api = NexusAPIService.shared
    private let ctService = CrazyTelService.shared

    var totalFirepower: Double {
        let emailCount = Double(emails.count) * 5_000
        let commCount = Double(communications.count) * 2_500
        let balance = ctBalance ?? 0
        return emailCount + commCount + balance + 450_000
    }

    var monthlyBurn: Double {
        let didCost = Double(ctDIDs.count) * 12.0
        let emailCost = Double(emailAccounts.count) * 5.0
        return didCost + emailCost + 285
    }

    var overallHealth: Double {
        (creditHealth + activityHealth + commsHealth) / 3.0
    }

    var creditHealth: Double {
        let unreadAlerts = alerts.filter { !$0.isRead && ($0.type == .utilisationWarning || $0.type == .clearScoreDrop) }.count
        return max(0, min(100, 100 - Double(unreadAlerts) * 20))
    }

    var activityHealth: Double {
        let totalComms = communications.count
        guard totalComms > 0 else { return 50 }
        let recentComms = communications.filter {
            $0.timestamp > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }.count
        let ratio = Double(recentComms) / Double(totalComms)
        return min(100, ratio * 200)
    }

    var commsHealth: Double {
        let total = communications.count + emails.count
        guard total > 0 else { return 50 }
        let unread = communications.filter { !$0.isRead }.count + emails.filter { !$0.isRead }.count
        let readRatio = 1.0 - (Double(unread) / Double(total))
        return min(100, readRatio * 120)
    }

    var urgentActions: [NexusAlert] {
        alerts.filter { !$0.isRead && $0.priority == .critical }
    }

    var unreadCommsCount: Int {
        communications.filter { !$0.isRead }.count
    }

    var unreadEmailCount: Int {
        emails.filter { !$0.isRead }.count
    }

    var emailConnected: Bool {
        !emailAccounts.isEmpty
    }

    var emailProvider: String {
        guard let first = emailAccounts.first else { return "none" }
        return first.provider.rawValue.lowercased()
    }

    var connectedAccountCount: Int {
        emailAccounts.filter { $0.isConnected }.count
    }

    var loggedInAccountCount: Int {
        emailAccounts.filter { $0.loginStatus == .loggedIn }.count
    }

    private static let emailAccountsKey = "nexus_email_accounts"

    init() {
        migrateCrazyTelKey()
        loadCachedData()
        loadEmailAccounts()
        Task {
            await loadData()
            if crazytelEnabled && !crazytelAPIKey.isEmpty {
                await connectCrazyTel()
            }
        }
    }

    private func migrateCrazyTelKey() {
        if let oldKey = UserDefaults.standard.string(forKey: "crazytel_api_key"), !oldKey.isEmpty {
            if KeychainService.load(key: "crazytel_api_key") == nil {
                KeychainService.save(key: "crazytel_api_key", value: oldKey)
            }
            UserDefaults.standard.removeObject(forKey: "crazytel_api_key")
        }
    }

    private func loadCachedData() {
        if let cachedComms = CacheService.loadCommunications(), !cachedComms.isEmpty {
            communications = cachedComms
        }
        if let cachedEmails = CacheService.loadEmails(), !cachedEmails.isEmpty {
            emails = cachedEmails
        }
        if let cachedAlerts = CacheService.loadAlerts(), !cachedAlerts.isEmpty {
            alerts = cachedAlerts
        }
    }

    private func persistToCache() {
        CacheService.saveCommunications(communications)
        CacheService.saveEmails(emails)
        CacheService.saveAlerts(alerts)
        CacheService.updateLastFetch()
        updateWidgetData()
    }

    func updateWidgetData() {
        let shared = UserDefaults(suiteName: "group.app.rork.nexus.shared")
        shared?.set(totalFirepower, forKey: "totalFirepower")
        shared?.set(monthlyBurn, forKey: "monthlyBurn")
        shared?.set(urgentActions.count, forKey: "urgentCount")
        shared?.set(emailAccounts.count + ctDIDs.count, forKey: "activeEntities")

        let urgentData = urgentActions.prefix(3).map { [$0.title, $0.message] }
        if let data = try? JSONEncoder().encode(urgentData) {
            shared?.set(data, forKey: "urgentActions")
        }
    }

    func loadData() async {
        guard api.isConfigured else {
            if communications.isEmpty {
                loadSampleData()
                persistToCache()
            }
            return
        }
        isLoading = true
        lastError = nil
        do {
            async let commsTask = api.fetchCommunications()
            async let emailsTask = api.fetchEmails()
            async let alertsTask = api.fetchAlerts()

            let (fetchedComms, fetchedEmails, fetchedAlerts) = try await (commsTask, emailsTask, alertsTask)

            communications = fetchedComms
            emails = fetchedEmails
            alerts = fetchedAlerts
            persistToCache()
        } catch {
            lastError = error.localizedDescription
            if communications.isEmpty {
                loadSampleData()
                persistToCache()
            }
        }
        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    func markCommRead(_ comm: Communication) {
        guard let index = communications.firstIndex(where: { $0.id == comm.id }) else { return }
        communications[index].isRead = true
        persistToCache()
        Task {
            do {
                _ = try await api.markCommRead(id: comm.id.uuidString.lowercased())
            } catch {
                communications[index].isRead = false
            }
        }
    }

    func markEmailRead(_ email: EmailMessage) {
        guard let index = emails.firstIndex(where: { $0.id == email.id }) else { return }
        emails[index].isRead = true
        persistToCache()
        Task {
            do {
                _ = try await api.markEmailRead(id: email.id.uuidString.lowercased())
            } catch {
                emails[index].isRead = false
            }
        }
    }

    func toggleEmailFlag(_ email: EmailMessage) {
        guard let index = emails.firstIndex(where: { $0.id == email.id }) else { return }
        emails[index].isFlagged.toggle()
        persistToCache()
        Task {
            do {
                _ = try await api.toggleEmailFlag(id: email.id.uuidString.lowercased())
            } catch {
                emails[index].isFlagged.toggle()
            }
        }
    }

    func archiveEmail(_ email: EmailMessage) {
        emails.removeAll { $0.id == email.id }
        persistToCache()
    }

    func deleteEmail(_ email: EmailMessage) {
        emails.removeAll { $0.id == email.id }
        persistToCache()
    }

    func markAlertRead(_ alert: NexusAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index].isRead = true
        persistToCache()
        Task {
            do {
                _ = try await api.markAlertRead(id: alert.id.uuidString.lowercased())
            } catch {
                alerts[index].isRead = false
            }
        }
    }

    func markAllAlertsRead() {
        for i in alerts.indices {
            alerts[i].isRead = true
        }
        persistToCache()
        Task {
            try? await api.markAllAlertsRead()
        }
    }

    func connectCrazyTel() async {
        guard !crazytelAPIKey.isEmpty else {
            ctConnectionStatus = .disconnected
            return
        }
        ctIsLoading = true
        ctError = nil
        ctConnectionStatus = .connecting
        do {
            let balance = try await ctService.fetchBalance(apiKey: crazytelAPIKey)
            ctBalance = balance.balance
            ctConnectionStatus = .connected
            await fetchCrazyTelDIDs()
            updateWidgetData()
        } catch {
            ctConnectionStatus = .error
            ctError = error.localizedDescription
        }
        ctIsLoading = false
    }

    func disconnectCrazyTel() {
        ctBalance = nil
        ctDIDs = []
        ctConnectionStatus = .disconnected
        ctError = nil
    }

    func fetchCrazyTelDIDs() async {
        guard ctConnectionStatus == .connected else { return }
        do {
            ctDIDs = try await ctService.fetchOwnedDIDs(apiKey: crazytelAPIKey)
        } catch {
            ctDIDs = []
        }
    }

    func refreshCrazyTel() async {
        guard crazytelEnabled else { return }
        await connectCrazyTel()
    }

    func sendSMS(from: String, to: String, message: String) async {
        guard !crazytelAPIKey.isEmpty else {
            smsError = "CrazyTel API key not configured"
            return
        }
        smsSending = true
        smsError = nil
        smsSuccess = false
        do {
            let response = try await ctService.sendSMS(apiKey: crazytelAPIKey, from: from, to: to, message: message)
            if let status = response.status, status.lowercased().contains("error") {
                smsError = response.message ?? "Failed to send SMS"
            } else {
                smsSuccess = true
                let comm = Communication(
                    id: UUID(),
                    type: .sms,
                    sender: "You",
                    content: message,
                    timestamp: Date(),
                    isRead: true,
                    phoneNumber: to
                )
                communications.insert(comm, at: 0)
                persistToCache()
            }
        } catch {
            smsError = error.localizedDescription
        }
        smsSending = false
    }

    func addEmailAccount(_ account: EmailAccount) {
        emailAccounts.append(account)
        assignEmailsToAccount(account)
        saveEmailAccounts()
    }

    func addAndLoginEmailAccount(_ account: EmailAccount, password: String) {
        var newAccount = account
        newAccount.loginStatus = .authenticating
        emailAccounts.append(newAccount)
        saveEmailAccounts()

        EmailCredentialService.savePassword(accountId: newAccount.id, password: password)

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard let index = emailAccounts.firstIndex(where: { $0.id == newAccount.id }) else { return }
            emailAccounts[index].loginStatus = .loggedIn
            emailAccounts[index].isConnected = true
            emailAccounts[index].lastSyncDate = Date()
            emailAccounts[index].loginError = nil
            assignEmailsToAccount(emailAccounts[index])
            saveEmailAccounts()
        }
    }

    func loginEmailAccount(_ account: EmailAccount, password: String) {
        guard let index = emailAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        emailAccounts[index].loginStatus = .authenticating
        emailAccounts[index].loginError = nil
        saveEmailAccounts()

        EmailCredentialService.savePassword(accountId: account.id, password: password)

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard let idx = emailAccounts.firstIndex(where: { $0.id == account.id }) else { return }
            emailAccounts[idx].loginStatus = .loggedIn
            emailAccounts[idx].isConnected = true
            emailAccounts[idx].lastSyncDate = Date()
            emailAccounts[idx].loginError = nil
            assignEmailsToAccount(emailAccounts[idx])
            saveEmailAccounts()
        }
    }

    func logoutEmailAccount(_ account: EmailAccount) {
        guard let index = emailAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        emailAccounts[index].loginStatus = .loggedOut
        emailAccounts[index].isConnected = false
        emailAccounts[index].lastSyncDate = nil
        EmailCredentialService.deletePassword(accountId: account.id)
        saveEmailAccounts()
    }

    func removeEmailAccount(_ account: EmailAccount) {
        EmailCredentialService.deletePassword(accountId: account.id)
        emailAccounts.removeAll { $0.id == account.id }
        for i in emails.indices where emails[i].accountId == account.id {
            emails[i].accountId = nil
        }
        saveEmailAccounts()
    }

    func toggleAccountConnection(_ account: EmailAccount) {
        guard let index = emailAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        emailAccounts[index].isConnected.toggle()
        saveEmailAccounts()
    }

    func emailsForAccount(_ accountId: UUID) -> [EmailMessage] {
        emails.filter { $0.accountId == accountId }
    }

    func unreadCountForAccount(_ accountId: UUID) -> Int {
        emails.filter { $0.accountId == accountId && !$0.isRead }.count
    }

    func findRelatedComm(for alert: NexusAlert) -> Communication? {
        guard alert.type == .newComm else { return nil }
        let titleLower = alert.title.lowercased()
        return communications.first { comm in
            titleLower.contains(comm.sender.lowercased()) ||
            comm.content.localizedStandardContains(alert.title)
        }
    }

    func findRelatedEmail(for alert: NexusAlert) -> EmailMessage? {
        let titleLower = alert.title.lowercased()
        let messageLower = alert.message.lowercased()
        return emails.first { email in
            titleLower.contains(email.sender.lowercased()) ||
            messageLower.contains(email.subject.lowercased())
        }
    }

    private func assignEmailsToAccount(_ account: EmailAccount) {
        let domain = account.emailAddress.components(separatedBy: "@").last?.lowercased() ?? ""
        for i in emails.indices {
            guard emails[i].accountId == nil else { continue }
            let senderDomain = emails[i].senderAddress.components(separatedBy: "@").last?.lowercased() ?? ""
            let aliasDomain = emails[i].alias.components(separatedBy: "@").last?.lowercased() ?? ""
            if senderDomain == domain || aliasDomain == domain || account.provider == .imap {
                emails[i].accountId = account.id
            }
        }
    }

    private func saveEmailAccounts() {
        if let data = try? JSONEncoder().encode(emailAccounts) {
            UserDefaults.standard.set(data, forKey: Self.emailAccountsKey)
        }
    }

    private func loadEmailAccounts() {
        guard let data = UserDefaults.standard.data(forKey: Self.emailAccountsKey),
              let accounts = try? JSONDecoder().decode([EmailAccount].self, from: data) else { return }
        emailAccounts = accounts
    }

    private func loadSampleData() {
        let now = Date()
        let cal = Calendar.current

        let acc1Id = UUID()
        let acc2Id = UUID()
        let acc3Id = UUID()

        emailAccounts = [
            EmailAccount(id: acc1Id, provider: .gmail, emailAddress: "user@gmail.com", displayName: "Personal Gmail", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -15, to: now)),
            EmailAccount(id: acc2Id, provider: .outlook, emailAddress: "user@outlook.com", displayName: "Work Outlook", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -30, to: now)),
            EmailAccount(id: acc3Id, provider: .gmail, emailAddress: "business@gmail.com", displayName: "Business Gmail", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .hour, value: -1, to: now))
        ]
        saveEmailAccounts()

        communications = [
            Communication(id: UUID(), type: .sms, sender: "CBA", content: "Your CBA account ending 4521 has a new transaction of $2,450.00.", timestamp: cal.date(byAdding: .hour, value: -1, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0101"),
            Communication(id: UUID(), type: .call, sender: "+61 2 9293 8000", content: "Incoming call from Westpac Sydney", timestamp: cal.date(byAdding: .hour, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0202", duration: 245),
            Communication(id: UUID(), type: .sms, sender: "NAB", content: "NAB: Your verification code is 847291. Do not share this code.", timestamp: cal.date(byAdding: .minute, value: -25, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0404"),
            Communication(id: UUID(), type: .voicemail, sender: "ANZ", content: "New voicemail received", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0707", duration: 42, transcription: "Hi, this is ANZ calling regarding your account ending in 8834. We'd like to discuss your current balance. Please call us back at 13 13 14 at your earliest convenience."),
            Communication(id: UUID(), type: .sms, sender: "CBA", content: "CBA: Monthly statement for account ending 7712 is now available in NetBank.", timestamp: cal.date(byAdding: .hour, value: -12, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0303"),
            Communication(id: UUID(), type: .sms, sender: "Macquarie", content: "Macquarie: A direct credit of $15,000.00 has been received into your business account.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0606"),
            Communication(id: UUID(), type: .call, sender: "+61 2 9234 0200", content: "Incoming call from CBA Business Centre", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0101", duration: 180),
            Communication(id: UUID(), type: .sms, sender: "ANZ", content: "ANZ: Your credit score has been updated. Log in to view your latest score.", timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0505"),
            Communication(id: UUID(), type: .voicemail, sender: "Unknown", content: "New voicemail received", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0808", duration: 18, transcription: "This is a message regarding your recent application. Please contact our team."),
            Communication(id: UUID(), type: .sms, sender: "NAB", content: "NAB: Your credit card payment of $500.00 has been processed successfully.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0404")
        ]

        emails = [
            EmailMessage(id: UUID(), sender: "CBA Business", senderAddress: "noreply@cba.com.au", subject: "Monthly Business Account Statement", snippet: "Your statement for the period ending 28 Feb 2026 is now available. Total credits: $42,500.00, Total debits: $38,200.00...", category: .statement, timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: true, alias: "user@gmail.com", accountId: acc1Id),
            EmailMessage(id: UUID(), sender: "NAB Business", senderAddress: "business@nab.com.au", subject: "Credit Limit Increase Approved", snippet: "Congratulations! Your application for a credit limit increase has been approved. Your new limit is $60,000...", category: .approval, timestamp: cal.date(byAdding: .hour, value: -5, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: true, alias: "business@gmail.com", accountId: acc3Id),
            EmailMessage(id: UUID(), sender: "Australian Taxation Office", senderAddress: "noreply@ato.gov.au", subject: "Tax Return Due Reminder", snippet: "Your individual tax return for the 2025 financial year is due on 31 October 2026. Please lodge your return online...", category: .atoNotice, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com"),
            EmailMessage(id: UUID(), sender: "CBA Trust Services", senderAddress: "trust@cba.com.au", subject: "Trust Account Statement — February 2026", snippet: "Statement for trust account ending 7712. Opening balance: $98,000.00. Closing balance: $93,600.00...", category: .statement, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: true, alias: "user@gmail.com"),
            EmailMessage(id: UUID(), sender: "Macquarie Business", senderAddress: "business@macquarie.com.au", subject: "New Business Credit Card Application", snippet: "Thank you for your application for a Macquarie Business Credit Card. We are currently reviewing your application...", category: .approval, timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "business@gmail.com"),
            EmailMessage(id: UUID(), sender: "Westpac", senderAddress: "noreply@westpac.com.au", subject: "Your Westpac Statement is Ready", snippet: "Your February statement is now available. View it anytime in the Westpac app or Online Banking...", category: .statement, timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com", accountId: acc2Id),
            EmailMessage(id: UUID(), sender: "CBA", senderAddress: "noreply@cba.com.au", subject: "Important: Account Verification Required", snippet: "We need to verify some details on your account. Please log in to NetBank...", category: .general, timestamp: cal.date(byAdding: .day, value: -4, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: false, alias: "user@gmail.com"),
            EmailMessage(id: UUID(), sender: "CreditSavvy", senderAddress: "hello@creditsavvy.com.au", subject: "Your Credit Score Has Changed", snippet: "Hi, your credit score has changed. Your new score is 734. Log in to see what's changed and get tips...", category: .general, timestamp: cal.date(byAdding: .day, value: -5, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com")
        ]

        alerts = [
            NexusAlert(id: UUID(), type: .clearScoreDrop, priority: .critical, title: "ClearScore Dropping", message: "ClearScore dropped to 621 (-24 in 30 days). Utilisation at 67%. Immediate action required.", timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false),
            NexusAlert(id: UUID(), type: .utilisationWarning, priority: .critical, title: "High Utilisation", message: "Utilisation at 67% — well above 25% threshold. Reduce balance immediately.", timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false),
            NexusAlert(id: UUID(), type: .newComm, priority: .warning, title: "Voicemail — ANZ", message: "Voicemail from ANZ. 42s. Transcription available.", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false),
            NexusAlert(id: UUID(), type: .dormantEntity, priority: .warning, title: "Account Dormant", message: "No activity for 45 days. Consider reactivation or archive.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false),
            NexusAlert(id: UUID(), type: .utilisationWarning, priority: .warning, title: "Utilisation Rising", message: "Utilisation now at 22%, approaching 25% threshold.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true),
            NexusAlert(id: UUID(), type: .applicationWindow, priority: .info, title: "Application Window", message: "Excellent standing (ClearScore 867). Ideal time to apply for additional credit.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true),
            NexusAlert(id: UUID(), type: .newComm, priority: .info, title: "Verification Required", message: "CBA requires account verification.", timestamp: cal.date(byAdding: .day, value: -4, to: now)!, isRead: true)
        ]
    }
}
