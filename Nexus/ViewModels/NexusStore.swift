import Foundation
import SwiftUI

@Observable
@MainActor
class NexusStore {
    var entities: [NexusEntity] = []
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

    @ObservationIgnored @AppStorage("crazytel_api_key") var crazytelAPIKey: String = ""
    @ObservationIgnored @AppStorage("crazytel_enabled") var crazytelEnabled: Bool = false

    private let api = NexusAPIService.shared
    private let ctService = CrazyTelService.shared

    var totalFirepower: Double {
        entities.filter { $0.status != .archived }.reduce(0) { $0 + $1.firepowerAmount }
    }

    var monthlyBurn: Double {
        entities.filter { $0.status != .archived }.reduce(0) { $0 + $1.monthlyBurn }
    }

    var urgentActions: [NexusAlert] {
        alerts.filter { !$0.isRead && $0.priority == .critical }
    }

    var activeEntityCount: Int {
        entities.filter { $0.status == .active }.count
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
    private static let entityEmailLinksKey = "nexus_entity_email_links"

    init() {
        loadEmailAccounts()
        Task {
            await loadData()
            if crazytelEnabled && !crazytelAPIKey.isEmpty {
                await connectCrazyTel()
            }
        }
    }

    func loadData() async {
        guard api.isConfigured else {
            loadSampleData()
            return
        }
        isLoading = true
        lastError = nil
        do {
            async let entitiesTask = api.fetchEntities()
            async let commsTask = api.fetchCommunications()
            async let emailsTask = api.fetchEmails()
            async let alertsTask = api.fetchAlerts()

            let (fetchedEntities, fetchedComms, fetchedEmails, fetchedAlerts) = try await (entitiesTask, commsTask, emailsTask, alertsTask)

            entities = fetchedEntities
            communications = fetchedComms
            emails = fetchedEmails
            alerts = fetchedAlerts
            restoreEntityEmailLinks()
        } catch {
            lastError = error.localizedDescription
            if entities.isEmpty {
                loadSampleData()
            }
        }
        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    func toggleEntityFlag(_ entity: NexusEntity) {
        guard let index = entities.firstIndex(where: { $0.id == entity.id }) else { return }
        entities[index].isFlagged.toggle()
        Task {
            do {
                _ = try await api.toggleEntityFlag(id: entity.id.uuidString.lowercased())
            } catch {
                entities[index].isFlagged.toggle()
            }
        }
    }

    func archiveEntity(_ entity: NexusEntity) {
        guard let index = entities.firstIndex(where: { $0.id == entity.id }) else { return }
        let previousStatus = entities[index].status
        entities[index].status = .archived
        Task {
            do {
                _ = try await api.archiveEntity(id: entity.id.uuidString.lowercased())
            } catch {
                entities[index].status = previousStatus
            }
        }
    }

    func markCommRead(_ comm: Communication) {
        guard let index = communications.firstIndex(where: { $0.id == comm.id }) else { return }
        communications[index].isRead = true
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
        Task {
            do {
                _ = try await api.toggleEmailFlag(id: email.id.uuidString.lowercased())
            } catch {
                emails[index].isFlagged.toggle()
            }
        }
    }

    func markAlertRead(_ alert: NexusAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index].isRead = true
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
        Task {
            try? await api.markAllAlertsRead()
        }
    }

    func commsForEntity(_ entityId: UUID) -> [Communication] {
        communications.filter { $0.entityId == entityId }
    }

    func emailsForEntity(_ entityId: UUID) -> [EmailMessage] {
        emails.filter { $0.entityId == entityId }
    }

    func alertsForEntity(_ entityId: UUID) -> [NexusAlert] {
        alerts.filter { $0.entityId == entityId }
    }

    func addEntity(_ entity: NexusEntity) {
        entities.append(entity)
        saveEntityEmailLinks()
        Task {
            do {
                let input = CreateEntityInput(
                    name: entity.name, type: entity.type.rawValue,
                    creditLimit: entity.creditLimit, assignedPhone: entity.assignedPhone,
                    assignedEmail: entity.assignedEmail, notes: entity.notes
                )
                _ = try await api.createEntity(input)
            } catch { }
        }
    }

    func updateEntity(_ entity: NexusEntity) {
        guard let index = entities.firstIndex(where: { $0.id == entity.id }) else { return }
        entities[index] = entity
        saveEntityEmailLinks()
        Task {
            do {
                let input = UpdateEntityInput(
                    id: entity.id.uuidString.lowercased(),
                    name: entity.name, type: entity.type.rawValue,
                    status: entity.status.rawValue, healthScore: entity.healthScore,
                    creditLimit: entity.creditLimit, utilisationPercent: entity.utilisationPercent,
                    monthlyBurn: entity.monthlyBurn, assignedPhone: entity.assignedPhone,
                    assignedEmail: entity.assignedEmail, clearScore: entity.clearScore,
                    isFlagged: entity.isFlagged, notes: entity.notes
                )
                _ = try await api.updateEntity(input)
            } catch { }
        }
    }

    func linkEmailAccount(_ accountId: UUID, toEntity entityId: UUID) {
        for i in entities.indices where entities[i].emailAccountId == accountId {
            entities[i].emailAccountId = nil
        }
        guard let index = entities.firstIndex(where: { $0.id == entityId }) else { return }
        entities[index].emailAccountId = accountId
        saveEntityEmailLinks()
    }

    func unlinkEmailAccount(fromEntity entityId: UUID) {
        guard let index = entities.firstIndex(where: { $0.id == entityId }) else { return }
        entities[index].emailAccountId = nil
        saveEntityEmailLinks()
    }

    func entityForEmailAccount(_ accountId: UUID) -> NexusEntity? {
        entities.first { $0.emailAccountId == accountId }
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

    func sendSMS(from: String, to: String, message: String, entityId: UUID? = nil, entityName: String? = nil) async {
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
                    entityId: entityId ?? UUID(),
                    entityName: entityName ?? "Unknown",
                    type: .sms,
                    sender: "You",
                    content: message,
                    timestamp: Date(),
                    isRead: true,
                    phoneNumber: to
                )
                communications.insert(comm, at: 0)
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
        for i in entities.indices where entities[i].emailAccountId == account.id {
            entities[i].emailAccountId = nil
        }
        emailAccounts.removeAll { $0.id == account.id }
        for i in emails.indices where emails[i].accountId == account.id {
            emails[i].accountId = nil
        }
        saveEmailAccounts()
        saveEntityEmailLinks()
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

    private func saveEntityEmailLinks() {
        var links: [String: String] = [:]
        for entity in entities {
            if let accountId = entity.emailAccountId {
                links[entity.id.uuidString] = accountId.uuidString
            }
        }
        if let data = try? JSONEncoder().encode(links) {
            UserDefaults.standard.set(data, forKey: Self.entityEmailLinksKey)
        }
    }

    private func restoreEntityEmailLinks() {
        guard let data = UserDefaults.standard.data(forKey: Self.entityEmailLinksKey),
              let links = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        for i in entities.indices {
            if let accountIdString = links[entities[i].id.uuidString],
               let accountId = UUID(uuidString: accountIdString) {
                entities[i].emailAccountId = accountId
            }
        }
    }

    private func loadSampleData() {
        let now = Date()
        let cal = Calendar.current

        let e1Id = UUID()
        let e2Id = UUID()
        let e3Id = UUID()
        let e4Id = UUID()
        let e5Id = UUID()
        let e6Id = UUID()
        let e7Id = UUID()
        let e8Id = UUID()

        let acc1Id = UUID()
        let acc2Id = UUID()
        let acc3Id = UUID()

        emailAccounts = [
            EmailAccount(id: acc1Id, provider: .gmail, emailAddress: "apex.holdings@gmail.com", displayName: "Apex Holdings", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -15, to: now)),
            EmailAccount(id: acc2Id, provider: .outlook, emailAddress: "j.mitchell@outlook.com", displayName: "Jordan Mitchell", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -30, to: now)),
            EmailAccount(id: acc3Id, provider: .gmail, emailAddress: "velocity.ventures@gmail.com", displayName: "Velocity Ventures", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .hour, value: -1, to: now))
        ]
        saveEmailAccounts()

        entities = [
            NexusEntity(id: e1Id, name: "Apex Holdings Pty Ltd", type: .ltd, status: .active, healthScore: 92, creditLimit: 75000, utilisationPercent: 12, monthlyBurn: 45, assignedPhone: "+61 4 5555 0101", assignedEmail: "apex@addy.io", clearScore: 845, lastActivityDate: cal.date(byAdding: .hour, value: -3, to: now)!, isFlagged: false, notes: "Primary vehicle. CBA business account.", createdDate: cal.date(byAdding: .month, value: -14, to: now)!, emailAccountId: acc1Id),
            NexusEntity(id: e2Id, name: "Jordan Mitchell", type: .person, status: .active, healthScore: 87, creditLimit: 45000, utilisationPercent: 8, monthlyBurn: 29, assignedPhone: "+61 4 5555 0202", assignedEmail: "j.mitchell@addy.io", clearScore: 812, lastActivityDate: cal.date(byAdding: .day, value: -1, to: now)!, isFlagged: false, notes: "Clean profile. Westpac personal.", createdDate: cal.date(byAdding: .month, value: -11, to: now)!, emailAccountId: acc2Id),
            NexusEntity(id: e3Id, name: "Pinnacle Trust", type: .trust, status: .active, healthScore: 78, creditLimit: 120000, utilisationPercent: 22, monthlyBurn: 52, assignedPhone: "+61 4 5555 0303", assignedEmail: "pinnacle@addy.io", clearScore: 788, lastActivityDate: cal.date(byAdding: .day, value: -4, to: now)!, isFlagged: true, notes: "High limit. Monitor utilisation closely.", createdDate: cal.date(byAdding: .month, value: -9, to: now)!),
            NexusEntity(id: e4Id, name: "Velocity Ventures Pty Ltd", type: .ltd, status: .active, healthScore: 95, creditLimit: 60000, utilisationPercent: 5, monthlyBurn: 38, assignedPhone: "+61 4 5555 0404", assignedEmail: "velocity@addy.io", clearScore: 867, lastActivityDate: cal.date(byAdding: .hour, value: -8, to: now)!, isFlagged: false, notes: "NAB business. Excellent standing.", createdDate: cal.date(byAdding: .month, value: -7, to: now)!, emailAccountId: acc3Id),
            NexusEntity(id: e5Id, name: "Sarah Chen", type: .person, status: .dormant, healthScore: 55, creditLimit: 30000, utilisationPercent: 3, monthlyBurn: 22, assignedPhone: "+61 4 5555 0505", assignedEmail: "s.chen@addy.io", clearScore: 734, lastActivityDate: cal.date(byAdding: .day, value: -45, to: now)!, isFlagged: false, notes: "Needs reactivation. ANZ personal.", createdDate: cal.date(byAdding: .month, value: -18, to: now)!),
            NexusEntity(id: e6Id, name: "Orion Group Pty Ltd", type: .ltd, status: .active, healthScore: 84, creditLimit: 90000, utilisationPercent: 18, monthlyBurn: 41, assignedPhone: "+61 4 5555 0606", assignedEmail: "orion@addy.io", clearScore: 801, lastActivityDate: cal.date(byAdding: .day, value: -2, to: now)!, isFlagged: false, notes: "Macquarie business. Strong history.", createdDate: cal.date(byAdding: .month, value: -6, to: now)!),
            NexusEntity(id: e7Id, name: "Blake Thompson", type: .person, status: .atRisk, healthScore: 38, creditLimit: 25000, utilisationPercent: 67, monthlyBurn: 35, assignedPhone: "+61 4 5555 0707", assignedEmail: "b.thompson@addy.io", clearScore: 621, lastActivityDate: cal.date(byAdding: .day, value: -12, to: now)!, isFlagged: true, notes: "ClearScore dropping. Reduce utilisation ASAP.", createdDate: cal.date(byAdding: .month, value: -20, to: now)!),
            NexusEntity(id: e8Id, name: "Summit Capital Trust", type: .trust, status: .active, healthScore: 71, creditLimit: 55000, utilisationPercent: 28, monthlyBurn: 50, assignedPhone: "+61 4 5555 0808", assignedEmail: "summit@addy.io", clearScore: 756, lastActivityDate: cal.date(byAdding: .day, value: -6, to: now)!, isFlagged: false, notes: "CBA trust account. Moderate activity.", createdDate: cal.date(byAdding: .month, value: -5, to: now)!)
        ]
        saveEntityEmailLinks()

        communications = [
            Communication(id: UUID(), entityId: e1Id, entityName: "Apex Holdings Pty Ltd", type: .sms, sender: "CBA", content: "Your CBA Business account ending 4521 has a new transaction of $2,450.00.", timestamp: cal.date(byAdding: .hour, value: -1, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0101"),
            Communication(id: UUID(), entityId: e2Id, entityName: "Jordan Mitchell", type: .call, sender: "+61 2 9293 8000", content: "Incoming call from Westpac Sydney", timestamp: cal.date(byAdding: .hour, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0202", duration: 245),
            Communication(id: UUID(), entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: .sms, sender: "NAB", content: "NAB: Your verification code is 847291. Do not share this code.", timestamp: cal.date(byAdding: .minute, value: -25, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0404"),
            Communication(id: UUID(), entityId: e7Id, entityName: "Blake Thompson", type: .voicemail, sender: "ANZ Collections", content: "New voicemail received", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0707", duration: 42, transcription: "Hi, this is ANZ calling regarding your account ending in 8834. We'd like to discuss your current balance. Please call us back at 13 13 14 at your earliest convenience."),
            Communication(id: UUID(), entityId: e3Id, entityName: "Pinnacle Trust", type: .sms, sender: "CBA", content: "CBA: Monthly statement for account ending 7712 is now available in NetBank.", timestamp: cal.date(byAdding: .hour, value: -12, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0303"),
            Communication(id: UUID(), entityId: e6Id, entityName: "Orion Group Pty Ltd", type: .sms, sender: "Macquarie", content: "Macquarie: A direct credit of $15,000.00 has been received into your business account.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0606"),
            Communication(id: UUID(), entityId: e1Id, entityName: "Apex Holdings Pty Ltd", type: .call, sender: "+61 2 9234 0200", content: "Incoming call from CBA Business Centre", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0101", duration: 180),
            Communication(id: UUID(), entityId: e5Id, entityName: "Sarah Chen", type: .sms, sender: "ANZ", content: "ANZ: Your credit score has been updated. Log in to view your latest score.", timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0505"),
            Communication(id: UUID(), entityId: e8Id, entityName: "Summit Capital Trust", type: .voicemail, sender: "Unknown", content: "New voicemail received", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0808", duration: 18, transcription: "This is a message for Summit Capital Trust regarding your recent application. Please contact our team."),
            Communication(id: UUID(), entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: .sms, sender: "NAB", content: "NAB: Your credit card payment of $500.00 has been processed successfully.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0404")
        ]

        emails = [
            EmailMessage(id: UUID(), entityId: e1Id, entityName: "Apex Holdings Pty Ltd", sender: "CBA Business", senderAddress: "noreply@cba.com.au", subject: "Monthly Business Account Statement", snippet: "Your statement for the period ending 28 Feb 2026 is now available. Total credits: $42,500.00, Total debits: $38,200.00...", category: .statement, timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: true, alias: "apex@addy.io", accountId: acc1Id),
            EmailMessage(id: UUID(), entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", sender: "NAB Business", senderAddress: "business@nab.com.au", subject: "Credit Limit Increase Approved", snippet: "Congratulations! Your application for a credit limit increase has been approved. Your new limit is $60,000...", category: .approval, timestamp: cal.date(byAdding: .hour, value: -5, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: true, alias: "velocity@addy.io", accountId: acc3Id),
            EmailMessage(id: UUID(), entityId: e7Id, entityName: "Blake Thompson", sender: "Australian Taxation Office", senderAddress: "noreply@ato.gov.au", subject: "Tax Return Due Reminder", snippet: "Your individual tax return for the 2025 financial year is due on 31 October 2026. Please lodge your return online...", category: .atoNotice, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: false, alias: "b.thompson@addy.io"),
            EmailMessage(id: UUID(), entityId: e3Id, entityName: "Pinnacle Trust", sender: "CBA Trust Services", senderAddress: "trust@cba.com.au", subject: "Trust Account Statement — February 2026", snippet: "Statement for Pinnacle Trust account ending 7712. Opening balance: $98,000.00. Closing balance: $93,600.00...", category: .statement, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: true, alias: "pinnacle@addy.io"),
            EmailMessage(id: UUID(), entityId: e6Id, entityName: "Orion Group Pty Ltd", sender: "Macquarie Business", senderAddress: "business@macquarie.com.au", subject: "New Business Credit Card Application", snippet: "Thank you for your application for a Macquarie Business Credit Card. We are currently reviewing your application...", category: .approval, timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "orion@addy.io"),
            EmailMessage(id: UUID(), entityId: e2Id, entityName: "Jordan Mitchell", sender: "Westpac", senderAddress: "noreply@westpac.com.au", subject: "Your Westpac Statement is Ready", snippet: "Your February statement is now available. View it anytime in the Westpac app or Online Banking...", category: .statement, timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "j.mitchell@addy.io", accountId: acc2Id),
            EmailMessage(id: UUID(), entityId: e8Id, entityName: "Summit Capital Trust", sender: "CBA", senderAddress: "noreply@cba.com.au", subject: "Important: Account Verification Required", snippet: "We need to verify some details on your Summit Capital Trust account. Please log in to NetBank...", category: .general, timestamp: cal.date(byAdding: .day, value: -4, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: false, alias: "summit@addy.io"),
            EmailMessage(id: UUID(), entityId: e5Id, entityName: "Sarah Chen", sender: "CreditSavvy", senderAddress: "hello@creditsavvy.com.au", subject: "Your Credit Score Has Changed", snippet: "Hi Sarah, your credit score has changed. Your new score is 734. Log in to see what's changed and get tips...", category: .general, timestamp: cal.date(byAdding: .day, value: -5, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "s.chen@addy.io")
        ]

        alerts = [
            NexusAlert(id: UUID(), entityId: e7Id, entityName: "Blake Thompson", type: .clearScoreDrop, priority: .critical, title: "ClearScore Dropping", message: "ClearScore dropped to 621 (-24 in 30 days). Utilisation at 67%. Immediate action required.", timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false),
            NexusAlert(id: UUID(), entityId: e7Id, entityName: "Blake Thompson", type: .utilisationWarning, priority: .critical, title: "High Utilisation", message: "Utilisation at 67% — well above 25% threshold. Reduce balance immediately.", timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false),
            NexusAlert(id: UUID(), entityId: nil, entityName: nil, type: .newComm, priority: .warning, title: "Voicemail — ANZ", message: "Voicemail from ANZ Collections on Blake Thompson line. 42s. Transcription available.", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false),
            NexusAlert(id: UUID(), entityId: e5Id, entityName: "Sarah Chen", type: .dormantEntity, priority: .warning, title: "Dormant Entity", message: "Sarah Chen has had no activity for 45 days. Consider reactivation or archive.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false),
            NexusAlert(id: UUID(), entityId: e3Id, entityName: "Pinnacle Trust", type: .utilisationWarning, priority: .warning, title: "Utilisation Rising", message: "Utilisation now at 22%, approaching 25% threshold.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true),
            NexusAlert(id: UUID(), entityId: e4Id, entityName: "Velocity Ventures Pty Ltd", type: .applicationWindow, priority: .info, title: "Application Window", message: "Excellent standing (ClearScore 867). Ideal time to apply for additional credit.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true),
            NexusAlert(id: UUID(), entityId: e8Id, entityName: "Summit Capital Trust", type: .newComm, priority: .info, title: "Verification Required", message: "CBA requires account verification for Summit Capital Trust.", timestamp: cal.date(byAdding: .day, value: -4, to: now)!, isRead: true)
        ]
    }
}
