import Foundation
import SwiftUI

nonisolated enum DataMode: String, Sendable {
    case live
    case demo
}

nonisolated enum BackendStatus: Sendable {
    case unknown
    case checking
    case connected(String?)
    case unreachable(String)
}

@Observable
@MainActor
class NexusStore {
    var subjects: [Subject] = []
    var communications: [Communication] = []
    var emails: [EmailMessage] = []
    var alerts: [NexusAlert] = []
    var isLoading: Bool = false
    var lastError: String?
    var dataMode: DataMode = .demo
    var backendStatus: BackendStatus = .unknown

    var dashboardData: DashboardResponse?

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

    var currentApplicationsTotal: Int {
        subjects.flatMap(\.applications).filter(\.isActive).count
    }

    var longestActiveApp: (subject: Subject, application: CreditApplication)? {
        var longest: (Subject, CreditApplication)?
        for subject in subjects {
            for app in subject.applications where app.isActive {
                if let current = longest {
                    if app.submittedDate < current.1.submittedDate {
                        longest = (subject, app)
                    }
                } else {
                    longest = (subject, app)
                }
            }
        }
        return longest
    }

    var unreadCommsCount: Int {
        communications.filter { !$0.isRead }.count
    }

    var unreadEmailCount: Int {
        emails.filter { !$0.isRead }.count
    }

    var urgentActions: [NexusAlert] {
        alerts.filter { !$0.isRead && $0.priority == .critical }
    }

    var warningActions: [NexusAlert] {
        alerts.filter { !$0.isRead && $0.priority == .warning }
    }

    var criticalCount: Int {
        alerts.filter { !$0.isRead && $0.priority == .critical }.count
    }

    var warningCount: Int {
        alerts.filter { !$0.isRead && $0.priority == .warning }.count
    }

    var clearCount: Int {
        let unread = alerts.filter { !$0.isRead }
        return unread.isEmpty ? 1 : unread.filter { $0.priority == .info }.count
    }

    var activeComms24h: Int {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        return communications.filter { $0.timestamp > cutoff }.count
    }

    var totalUnreadMessages: Int {
        unreadCommsCount + unreadEmailCount
    }

    var emailConnected: Bool {
        !emailAccounts.isEmpty
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
        if let cached = CacheService.loadCommunications(), !cached.isEmpty {
            communications = cached
        }
        if let cached = CacheService.loadEmails(), !cached.isEmpty {
            emails = cached
        }
        if let cached = CacheService.loadAlerts(), !cached.isEmpty {
            alerts = cached
        }
        if let cached = CacheService.loadSubjects(), !cached.isEmpty {
            subjects = cached
        }
    }

    private func persistToCache() {
        CacheService.saveCommunications(communications)
        CacheService.saveEmails(emails)
        CacheService.saveAlerts(alerts)
        CacheService.saveSubjects(subjects)
        CacheService.updateLastFetch()
        updateWidgetData()
    }

    func updateWidgetData() {
        let shared = UserDefaults(suiteName: "group.app.rork.nexus.shared")
        shared?.set(currentApplicationsTotal, forKey: "currentApplicationsTotal")
        shared?.set(urgentActions.count + warningActions.count, forKey: "urgentCount")
        shared?.set(subjects.count, forKey: "totalSubjects")

        if let longest = longestActiveApp {
            shared?.set(longest.subject.name, forKey: "longestActiveSubject")
            shared?.set(longest.application.bank, forKey: "longestActiveBank")
            shared?.set(longest.application.daysActive, forKey: "longestActiveDays")
        }

        let urgentData = (urgentActions + warningActions).prefix(3).map { [$0.title, $0.subjectName ?? ""] }
        if let data = try? JSONEncoder().encode(urgentData) {
            shared?.set(data, forKey: "urgentActions")
        }
    }

    func checkBackendHealth() async {
        backendStatus = .checking
        do {
            let health = try await api.checkHealth()
            backendStatus = .connected(health.version)
        } catch {
            backendStatus = .unreachable(error.localizedDescription)
        }
    }

    func loadData() async {
        guard api.isConfigured else {
            dataMode = .demo
            backendStatus = .unreachable("API not configured")
            if subjects.isEmpty {
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
            async let subjectsTask = api.fetchSubjects()
            async let dashboardTask = api.fetchDashboard()

            let (fetchedComms, fetchedEmails, fetchedAlerts, fetchedSubjects, fetchedDashboard) = try await (commsTask, emailsTask, alertsTask, subjectsTask, dashboardTask)

            communications = fetchedComms
            emails = fetchedEmails
            alerts = fetchedAlerts
            subjects = fetchedSubjects
            dashboardData = fetchedDashboard
            dataMode = .live
            backendStatus = .connected(nil)
            persistToCache()
        } catch {
            lastError = error.localizedDescription
            dataMode = .demo
            backendStatus = .unreachable(error.localizedDescription)
            if subjects.isEmpty {
                loadSampleData()
                persistToCache()
            }
        }
        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    func syncMailbox() async {
        guard dataMode == .live else { return }
        do {
            let _ = try await api.syncMailbox()
            await loadData() // Refresh everything after a sync
        } catch {
            print("Failed to sync mailbox: \(error)")
        }
    }

    func markCommRead(_ comm: Communication) {
        guard let index = communications.firstIndex(where: { $0.id == comm.id }) else { return }
        communications[index].isRead = true
        persistToCache()
        guard dataMode == .live else { return }
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
        guard dataMode == .live else { return }
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
        guard dataMode == .live else { return }
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
        guard dataMode == .live else { return }
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
        guard dataMode == .live else { return }
        Task {
            try? await api.markAllAlertsRead()
        }
    }

    func toggleSubjectFlag(_ subject: Subject) {
        guard let index = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[index].isFlagged.toggle()
        persistToCache()
        guard dataMode == .live else { return }
        Task {
            do {
                _ = try await api.toggleSubjectFlag(id: subject.id)
            } catch {
                guard let idx = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
                subjects[idx].isFlagged.toggle()
                persistToCache()
            }
        }
    }

    func archiveSubject(_ subject: Subject) {
        guard let index = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        let previousStatus = subjects[index].status
        subjects[index].status = .archived
        persistToCache()
        guard dataMode == .live else { return }
        Task {
            do {
                _ = try await api.archiveSubject(id: subject.id)
            } catch {
                guard let idx = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
                subjects[idx].status = previousStatus
                persistToCache()
            }
        }
    }

    func createSubject(name: String, type: SubjectType, creditLimit: Double, assignedPhone: String, assignedEmail: String, notes: String?) async throws {
        if dataMode == .live {
            let created = try await api.createSubject(
                name: name,
                type: type,
                creditLimit: creditLimit,
                assignedPhone: assignedPhone,
                assignedEmail: assignedEmail,
                notes: notes
            )
            subjects.insert(created, at: 0)
        } else {
            let newSubject = Subject(
                id: UUID().uuidString,
                name: name,
                type: type,
                status: .active,
                creditScore: 75,
                assignedPhone: assignedPhone,
                assignedEmail: assignedEmail,
                lastActivityDate: Date(),
                isFlagged: false,
                notes: notes ?? "",
                createdDate: Date(),
                dateOfBirth: "",
                address: "",
                idNumber: "",
                applications: []
            )
            subjects.insert(newSubject, at: 0)
        }
        persistToCache()
    }

    func updateSubject(id: String, name: String? = nil, type: SubjectType? = nil, status: SubjectStatus? = nil, creditScore: Int? = nil, assignedPhone: String? = nil, assignedEmail: String? = nil, notes: String? = nil, isFlagged: Bool? = nil) async throws {
        guard let index = subjects.firstIndex(where: { $0.id == id }) else { return }
        if dataMode == .live {
            let input = UpdateEntityInput(
                id: id,
                name: name,
                type: type?.rawValue,
                status: status?.rawValue,
                healthScore: creditScore,
                creditLimit: nil,
                utilisationPercent: nil,
                monthlyBurn: nil,
                assignedPhone: assignedPhone,
                assignedEmail: assignedEmail,
                clearScore: nil,
                isFlagged: isFlagged,
                notes: notes
            )
            let updated = try await api.updateSubject(input)
            subjects[index] = Subject(
                id: updated.id,
                name: updated.name,
                type: updated.type,
                status: updated.status,
                creditScore: updated.creditScore,
                assignedPhone: updated.assignedPhone,
                assignedEmail: updated.assignedEmail,
                lastActivityDate: updated.lastActivityDate,
                isFlagged: updated.isFlagged,
                notes: updated.notes,
                createdDate: updated.createdDate,
                dateOfBirth: subjects[index].dateOfBirth,
                address: subjects[index].address,
                idNumber: subjects[index].idNumber,
                applications: subjects[index].applications
            )
        } else {
            if let name { subjects[index].name = name }
            if let type { subjects[index].type = type }
            if let status { subjects[index].status = status }
            if let creditScore { subjects[index].creditScore = creditScore }
            if let assignedPhone { subjects[index].assignedPhone = assignedPhone }
            if let assignedEmail { subjects[index].assignedEmail = assignedEmail }
            if let notes { subjects[index].notes = notes }
            if let isFlagged { subjects[index].isFlagged = isFlagged }
            subjects[index].lastActivityDate = Date()
        }
        persistToCache()
    }

    func refreshSubjectFromBackend(_ id: String) async {
        guard dataMode == .live else { return }
        do {
            let refreshed = try await api.fetchSubjectById(id: id)
            guard let index = subjects.firstIndex(where: { $0.id == id }) else { return }
            subjects[index] = Subject(
                id: refreshed.id,
                name: refreshed.name,
                type: refreshed.type,
                status: refreshed.status,
                creditScore: refreshed.creditScore,
                assignedPhone: refreshed.assignedPhone,
                assignedEmail: refreshed.assignedEmail,
                lastActivityDate: refreshed.lastActivityDate,
                isFlagged: refreshed.isFlagged,
                notes: refreshed.notes,
                createdDate: refreshed.createdDate,
                dateOfBirth: subjects[index].dateOfBirth,
                address: subjects[index].address,
                idNumber: subjects[index].idNumber,
                applications: subjects[index].applications
            )
            persistToCache()
        } catch { }
    }

    func fetchCommsForSubject(_ subjectId: String) async -> [Communication] {
        guard dataMode == .live else {
            return communications.filter { $0.subjectId == subjectId }
        }
        do {
            return try await api.fetchCommunications(entityId: subjectId)
        } catch {
            return communications.filter { $0.subjectId == subjectId }
        }
    }

    func fetchEmailsForSubject(_ subjectId: String) async -> [EmailMessage] {
        guard dataMode == .live else {
            return emails.filter { $0.subjectId == subjectId }
        }
        do {
            return try await api.fetchEmails(entityId: subjectId)
        } catch {
            return emails.filter { $0.subjectId == subjectId }
        }
    }

    func fetchAlertsByType(_ type: String) async -> [NexusAlert] {
        guard dataMode == .live else {
            return alerts.filter { $0.type.rawValue == type }
        }
        do {
            return try await api.fetchAlerts(type: type)
        } catch {
            return alerts.filter { $0.type.rawValue == type }
        }
    }

    func subjectForId(_ id: String) -> Subject? {
        subjects.first { $0.id == id }
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

    func emailsForAccount(_ accountId: UUID) -> [EmailMessage] {
        emails.filter { $0.accountId == accountId }
    }

    func unreadCountForAccount(_ accountId: UUID) -> Int {
        emails.filter { $0.accountId == accountId && !$0.isRead }.count
    }

    func findRelatedSubject(for alert: NexusAlert) -> Subject? {
        if let sid = alert.subjectId { return subjectForId(sid) }
        let name = alert.subjectName ?? alert.title
        return subjects.first { name.localizedStandardContains($0.name) }
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

        let s1Id = UUID().uuidString
        let s2Id = UUID().uuidString
        let s3Id = UUID().uuidString
        let s4Id = UUID().uuidString
        let s5Id = UUID().uuidString
        let s6Id = UUID().uuidString
        let s7Id = UUID().uuidString
        let s8Id = UUID().uuidString

        subjects = [
            Subject(id: s1Id, name: "Apex Holdings Pty Ltd", type: .ltd, status: .active, creditScore: 85, assignedPhone: "+61 4 5555 0101", assignedEmail: "apex@addy.io", lastActivityDate: cal.date(byAdding: .hour, value: -3, to: now)!, isFlagged: false, notes: "Primary vehicle. CBA business account.", createdDate: cal.date(byAdding: .month, value: -14, to: now)!, dateOfBirth: "", address: "Level 12, 100 Collins St, Melbourne VIC 3000", idNumber: "ACN 612 345 678", applications: [
                CreditApplication(id: UUID(), bank: "CBA", product: "Business Credit Card", status: .inReview, progressPercent: 65, submittedDate: cal.date(byAdding: .day, value: -30, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -2, to: now)!, nextAction: "Await bank decision", documents: "ID, Financials"),
                CreditApplication(id: UUID(), bank: "NAB", product: "Business Loan", status: .submitted, progressPercent: 25, submittedDate: cal.date(byAdding: .day, value: -12, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -12, to: now)!, nextAction: "Submit financials", documents: "Application form"),
                CreditApplication(id: UUID(), bank: "Westpac", product: "Overdraft", status: .approved, progressPercent: 100, submittedDate: cal.date(byAdding: .day, value: -90, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -45, to: now)!, nextAction: "Complete", documents: "All submitted"),
            ]),
            Subject(id: s2Id, name: "Jordan Mitchell", type: .person, status: .active, creditScore: 72, assignedPhone: "+61 4 5555 0202", assignedEmail: "j.mitchell@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -1, to: now)!, isFlagged: false, notes: "Clean profile. Westpac personal.", createdDate: cal.date(byAdding: .month, value: -11, to: now)!, dateOfBirth: "15/03/1988", address: "42 George Street, Sydney NSW 2000", idNumber: "DL NSW 12345678", applications: [
                CreditApplication(id: UUID(), bank: "Westpac", product: "Personal Loan", status: .inReview, progressPercent: 80, submittedDate: cal.date(byAdding: .day, value: -45, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -3, to: now)!, nextAction: "Employment verification", documents: "ID, Payslips, Bank Statements"),
                CreditApplication(id: UUID(), bank: "ANZ", product: "Credit Card", status: .approved, progressPercent: 100, submittedDate: cal.date(byAdding: .day, value: -60, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -30, to: now)!, nextAction: "Complete", documents: "All submitted"),
            ]),
            Subject(id: s3Id, name: "Pinnacle Trust", type: .trust, status: .active, creditScore: 68, assignedPhone: "+61 4 5555 0303", assignedEmail: "pinnacle@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -4, to: now)!, isFlagged: true, notes: "High limit. Monitor utilisation closely.", createdDate: cal.date(byAdding: .month, value: -9, to: now)!, dateOfBirth: "", address: "Suite 8, 200 Adelaide Terrace, Perth WA 6000", idNumber: "ABN 98 765 432 10", applications: [
                CreditApplication(id: UUID(), bank: "CBA", product: "Trust Facility", status: .documentsNeeded, progressPercent: 40, submittedDate: cal.date(byAdding: .day, value: -35, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -4, to: now)!, nextAction: "Upload trust deed", documents: "ID, Trust Deed (pending)"),
                CreditApplication(id: UUID(), bank: "Macquarie", product: "Line of Credit", status: .stalled, progressPercent: 55, submittedDate: cal.date(byAdding: .day, value: -48, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -20, to: now)!, nextAction: "Contact bank", documents: "Financials, ABN"),
            ]),
            Subject(id: s4Id, name: "Velocity Ventures Pty Ltd", type: .ltd, status: .active, creditScore: 91, assignedPhone: "+61 4 5555 0404", assignedEmail: "velocity@addy.io", lastActivityDate: cal.date(byAdding: .hour, value: -8, to: now)!, isFlagged: false, notes: "NAB business. Excellent standing.", createdDate: cal.date(byAdding: .month, value: -7, to: now)!, dateOfBirth: "", address: "3/88 Flinders Lane, Melbourne VIC 3000", idNumber: "ACN 789 012 345", applications: [
                CreditApplication(id: UUID(), bank: "NAB", product: "Business Credit Card", status: .inReview, progressPercent: 70, submittedDate: cal.date(byAdding: .day, value: -18, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -5, to: now)!, nextAction: "Await approval", documents: "Financials, ID"),
                CreditApplication(id: UUID(), bank: "CBA", product: "Business Loan", status: .submitted, progressPercent: 15, submittedDate: cal.date(byAdding: .day, value: -8, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -8, to: now)!, nextAction: "Initial review", documents: "Application form"),
            ]),
            Subject(id: s5Id, name: "Sarah Chen", type: .person, status: .pending, creditScore: 45, assignedPhone: "+61 4 5555 0505", assignedEmail: "s.chen@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -52, to: now)!, isFlagged: false, notes: "Needs reactivation. ANZ personal.", createdDate: cal.date(byAdding: .month, value: -18, to: now)!, dateOfBirth: "22/07/1992", address: "15 Queen Street, Brisbane QLD 4000", idNumber: "DL QLD 87654321", applications: [
                CreditApplication(id: UUID(), bank: "ANZ", product: "Personal Loan", status: .stalled, progressPercent: 30, submittedDate: cal.date(byAdding: .day, value: -52, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -40, to: now)!, nextAction: "Follow up with bank", documents: "ID, Payslips"),
            ]),
            Subject(id: s6Id, name: "Orion Group Pty Ltd", type: .ltd, status: .active, creditScore: 83, assignedPhone: "+61 4 5555 0606", assignedEmail: "orion@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -2, to: now)!, isFlagged: false, notes: "Macquarie business. Strong history.", createdDate: cal.date(byAdding: .month, value: -6, to: now)!, dateOfBirth: "", address: "Level 5, 1 Eagle Street, Brisbane QLD 4000", idNumber: "ACN 456 789 012", applications: [
                CreditApplication(id: UUID(), bank: "Macquarie", product: "Business Loan", status: .inReview, progressPercent: 85, submittedDate: cal.date(byAdding: .day, value: -22, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -2, to: now)!, nextAction: "Final assessment", documents: "All submitted"),
                CreditApplication(id: UUID(), bank: "Westpac", product: "Credit Card", status: .approved, progressPercent: 100, submittedDate: cal.date(byAdding: .day, value: -40, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -15, to: now)!, nextAction: "Complete", documents: "All submitted"),
            ]),
            Subject(id: s7Id, name: "Blake Thompson", type: .person, status: .atRisk, creditScore: 32, assignedPhone: "+61 4 5555 0707", assignedEmail: "b.thompson@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -12, to: now)!, isFlagged: true, notes: "Score dropping. Reduce utilisation ASAP.", createdDate: cal.date(byAdding: .month, value: -20, to: now)!, dateOfBirth: "09/11/1985", address: "7 Hay Street, Perth WA 6000", idNumber: "DL WA 11223344", applications: [
                CreditApplication(id: UUID(), bank: "CBA", product: "Personal Loan", status: .documentsNeeded, progressPercent: 20, submittedDate: cal.date(byAdding: .day, value: -28, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -12, to: now)!, nextAction: "Provide updated payslips", documents: "ID (pending payslips)"),
                CreditApplication(id: UUID(), bank: "ANZ", product: "Credit Card", status: .declined, progressPercent: 0, submittedDate: cal.date(byAdding: .day, value: -35, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -25, to: now)!, nextAction: "N/A — Declined", documents: "All submitted"),
            ]),
            Subject(id: s8Id, name: "Summit Capital Trust", type: .trust, status: .active, creditScore: 75, assignedPhone: "+61 4 5555 0808", assignedEmail: "summit@addy.io", lastActivityDate: cal.date(byAdding: .day, value: -6, to: now)!, isFlagged: false, notes: "CBA trust account. Moderate activity.", createdDate: cal.date(byAdding: .month, value: -5, to: now)!, dateOfBirth: "", address: "22 Pirie Street, Adelaide SA 5000", idNumber: "ABN 11 222 333 44", applications: [
                CreditApplication(id: UUID(), bank: "CBA", product: "Trust Overdraft", status: .inReview, progressPercent: 60, submittedDate: cal.date(byAdding: .day, value: -20, to: now)!, lastUpdateDate: cal.date(byAdding: .day, value: -6, to: now)!, nextAction: "Trustee verification", documents: "Trust deed, ID"),
            ]),
        ]

        let acc1Id = UUID()
        let acc2Id = UUID()
        let acc3Id = UUID()

        emailAccounts = [
            EmailAccount(id: acc1Id, provider: .gmail, emailAddress: "user@gmail.com", displayName: "Personal Gmail", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -15, to: now)),
            EmailAccount(id: acc2Id, provider: .outlook, emailAddress: "user@outlook.com", displayName: "Work Outlook", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .minute, value: -30, to: now)),
            EmailAccount(id: acc3Id, provider: .gmail, emailAddress: "business@gmail.com", displayName: "Business Gmail", isConnected: true, loginStatus: .loggedIn, lastSyncDate: cal.date(byAdding: .hour, value: -1, to: now)),
        ]
        saveEmailAccounts()

        communications = [
            Communication(id: UUID(), type: .sms, sender: "CBA", content: "Your CBA account ending 4521 has a new transaction of $2,450.00.", timestamp: cal.date(byAdding: .hour, value: -1, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0101", subjectId: s1Id, subjectName: "Apex Holdings"),
            Communication(id: UUID(), type: .call, sender: "+61 2 9293 8000", content: "Incoming call from Westpac Sydney", timestamp: cal.date(byAdding: .hour, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0202", duration: 245, subjectId: s2Id, subjectName: "Jordan Mitchell"),
            Communication(id: UUID(), type: .sms, sender: "NAB", content: "NAB: Your verification code is 847291. Do not share this code.", timestamp: cal.date(byAdding: .minute, value: -25, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0404", subjectId: s4Id, subjectName: "Velocity Ventures"),
            Communication(id: UUID(), type: .voicemail, sender: "ANZ", content: "New voicemail received", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0707", duration: 42, transcription: "Hi, this is ANZ calling regarding your account ending in 8834. We'd like to discuss your current balance. Please call us back at 13 13 14 at your earliest convenience.", subjectId: s7Id, subjectName: "Blake Thompson"),
            Communication(id: UUID(), type: .sms, sender: "CBA", content: "CBA: Monthly statement for trust account ending 7712 is now available in NetBank.", timestamp: cal.date(byAdding: .hour, value: -12, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0303", subjectId: s3Id, subjectName: "Pinnacle Trust"),
            Communication(id: UUID(), type: .sms, sender: "Macquarie", content: "Macquarie: A direct credit of $15,000.00 has been received into your business account.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0606", subjectId: s6Id, subjectName: "Orion Group"),
            Communication(id: UUID(), type: .call, sender: "+61 2 9234 0200", content: "Incoming call from CBA Business Centre", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0101", duration: 180, subjectId: s1Id, subjectName: "Apex Holdings"),
            Communication(id: UUID(), type: .sms, sender: "ANZ", content: "ANZ: Your credit score has been updated. Log in to view your latest score.", timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0505", subjectId: s5Id, subjectName: "Sarah Chen"),
            Communication(id: UUID(), type: .voicemail, sender: "Unknown", content: "New voicemail received", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: false, phoneNumber: "+61 4 5555 0808", duration: 18, transcription: "This is a message regarding your recent application. Please contact our team.", subjectId: s8Id, subjectName: "Summit Capital"),
            Communication(id: UUID(), type: .sms, sender: "NAB", content: "NAB: Your credit card payment of $500.00 has been processed successfully.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, phoneNumber: "+61 4 5555 0404", subjectId: s4Id, subjectName: "Velocity Ventures"),
        ]

        emails = [
            EmailMessage(id: UUID(), sender: "CBA Business", senderAddress: "noreply@cba.com.au", subject: "Monthly Business Account Statement", snippet: "Your statement for the period ending 28 Feb 2026 is now available. Total credits: $42,500.00...", category: .statement, timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: true, alias: "user@gmail.com", accountId: acc1Id, subjectId: s1Id, subjectName: "Apex Holdings"),
            EmailMessage(id: UUID(), sender: "NAB Business", senderAddress: "business@nab.com.au", subject: "Credit Limit Increase Approved", snippet: "Congratulations! Your application for a credit limit increase has been approved. Your new limit is $60,000...", category: .approval, timestamp: cal.date(byAdding: .hour, value: -5, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: true, alias: "business@gmail.com", accountId: acc3Id, subjectId: s4Id, subjectName: "Velocity Ventures"),
            EmailMessage(id: UUID(), sender: "Inland Revenue", senderAddress: "noreply@ird.govt.nz", subject: "Tax Return Due Reminder", snippet: "Your individual tax return for the 2025 financial year is due on 31 October 2026...", category: .ird, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com"),
            EmailMessage(id: UUID(), sender: "CBA Trust Services", senderAddress: "trust@cba.com.au", subject: "Trust Account Statement — February 2026", snippet: "Statement for trust account ending 7712. Opening balance: $98,000.00. Closing balance: $93,600.00...", category: .statement, timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: true, alias: "user@gmail.com", subjectId: s3Id, subjectName: "Pinnacle Trust"),
            EmailMessage(id: UUID(), sender: "Macquarie Business", senderAddress: "business@macquarie.com.au", subject: "Loan Application Update", snippet: "Thank you for your business loan application. We are currently in the final assessment phase...", category: .bankNotice, timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "business@gmail.com", subjectId: s6Id, subjectName: "Orion Group"),
            EmailMessage(id: UUID(), sender: "Westpac", senderAddress: "noreply@westpac.com.au", subject: "Your Westpac Statement is Ready", snippet: "Your February statement is now available. View it anytime in the Westpac app...", category: .statement, timestamp: cal.date(byAdding: .day, value: -3, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com", accountId: acc2Id, subjectId: s2Id, subjectName: "Jordan Mitchell"),
            EmailMessage(id: UUID(), sender: "CBA", senderAddress: "noreply@cba.com.au", subject: "Important: Account Verification Required", snippet: "We need to verify some details on your account. Please log in to NetBank...", category: .bankNotice, timestamp: cal.date(byAdding: .day, value: -4, to: now)!, isRead: false, isFlagged: true, containsDollarAmount: false, alias: "user@gmail.com", subjectId: s7Id, subjectName: "Blake Thompson"),
            EmailMessage(id: UUID(), sender: "CreditSavvy", senderAddress: "hello@creditsavvy.com.au", subject: "Your Credit Score Has Changed", snippet: "Hi, your credit score has changed. Your new score is 32. Log in to see what's changed...", category: .general, timestamp: cal.date(byAdding: .day, value: -5, to: now)!, isRead: true, isFlagged: false, containsDollarAmount: false, alias: "user@outlook.com", subjectId: s7Id, subjectName: "Blake Thompson"),
        ]

        alerts = [
            NexusAlert(id: UUID(), type: .stalledApplication, priority: .critical, title: "Application Stalled — 52 Days", message: "Sarah Chen's ANZ Personal Loan has been stalled for 52 days. Immediate follow-up required.", timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false, subjectId: s5Id, subjectName: "Sarah Chen"),
            NexusAlert(id: UUID(), type: .scoreDrop, priority: .critical, title: "Score Drop — 32", message: "Blake Thompson's credit score dropped to 32. Application at risk of decline.", timestamp: cal.date(byAdding: .hour, value: -3, to: now)!, isRead: false, subjectId: s7Id, subjectName: "Blake Thompson"),
            NexusAlert(id: UUID(), type: .verificationBlock, priority: .warning, title: "Verification Required", message: "Pinnacle Trust — CBA requires trust deed upload to proceed with facility application.", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false, subjectId: s3Id, subjectName: "Pinnacle Trust"),
            NexusAlert(id: UUID(), type: .stalledApplication, priority: .warning, title: "Macquarie LoC Stalled", message: "Pinnacle Trust's Macquarie Line of Credit has not progressed in 20 days.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: false, subjectId: s3Id, subjectName: "Pinnacle Trust"),
            NexusAlert(id: UUID(), type: .scoreDrop, priority: .warning, title: "Score Declining", message: "Sarah Chen's score at 45 — trending down. Consider pausing new applications.", timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true, subjectId: s5Id, subjectName: "Sarah Chen"),
            NexusAlert(id: UUID(), type: .newComm, priority: .info, title: "Voicemail — ANZ", message: "Voicemail from ANZ for Blake Thompson. 42s. Transcription available.", timestamp: cal.date(byAdding: .hour, value: -6, to: now)!, isRead: false, subjectId: s7Id, subjectName: "Blake Thompson"),
            NexusAlert(id: UUID(), type: .utilisationSpike, priority: .info, title: "Application Window", message: "Velocity Ventures (score 91) — ideal window for additional credit applications.", timestamp: cal.date(byAdding: .day, value: -2, to: now)!, isRead: true, subjectId: s4Id, subjectName: "Velocity Ventures"),
        ]
    }
}
