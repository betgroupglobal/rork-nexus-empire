import SwiftUI

struct SettingsView: View {
    let store: NexusStore
    @Bindable var authVM: AuthViewModel
    @State private var showAddEntity: Bool = false
    @State private var showLogoutConfirm: Bool = false
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.06, green: 0.10, blue: 0.20), Color(red: 0.10, green: 0.16, blue: 0.32)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)

                        Image(systemName: "shield.checkered")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nexus")
                            .font(.title3.bold())
                        Text("v1.0.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Integrations") {
                NavigationLink {
                    CrazyTelSettingsView(store: store)
                } label: {
                    HStack(spacing: 12) {
                        IntegrationIcon(icon: "phone.fill", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CrazyTel")
                                .font(.subheadline)
                            Text(ctStatusLabel)
                                .font(.caption)
                                .foregroundStyle(ctStatusColor)
                        }
                    }
                }

                NavigationLink {
                    EmailIntegrationView(store: store)
                } label: {
                    HStack(spacing: 12) {
                        IntegrationIcon(icon: "envelope.fill", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email")
                                .font(.subheadline)
                            Text(emailStatusLabel)
                                .font(.caption)
                                .foregroundStyle(store.emailConnected ? .green : .secondary)
                        }
                    }
                }
            }

            Section("Identities") {
                Button {
                    showAddEntity = true
                } label: {
                    Label("Add New Identity", systemImage: "plus.circle")
                }

                NavigationLink {
                    ArchivedEntitiesView(store: store)
                } label: {
                    Label("Archived Identities", systemImage: "archivebox")
                }

                LabeledContent("Active", value: "\(store.activeEntityCount)")
                LabeledContent("Total", value: "\(store.entities.count)")
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }

            Section("Alert Thresholds") {
                LabeledContent("Utilisation", value: "25%")
                LabeledContent("Dormancy", value: "30 days")
                LabeledContent("ClearScore", value: "< 650")
            }

            if let user = authVM.currentUser {
                Section("Account") {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.6), .blue.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.subheadline.weight(.medium))
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Data") {
                Button {
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authVM.logout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showAddEntity) {
            AddEntitySheet(store: store)
        }
    }

    private var ctStatusLabel: String {
        switch store.ctConnectionStatus {
        case .connected: "Connected \(store.ctDIDs.count > 0 ? "(\(store.ctDIDs.count) DIDs)" : "")"
        case .connecting: "Connecting..."
        case .error: "Connection error"
        case .disconnected: "Not connected"
        }
    }

    private var ctStatusColor: Color {
        switch store.ctConnectionStatus {
        case .connected: .green
        case .connecting: .orange
        case .error: .red
        case .disconnected: .secondary
        }
    }

    private var emailStatusLabel: String {
        let count = store.emailAccounts.count
        guard count > 0 else { return "No accounts" }
        return "\(count) account\(count == 1 ? "" : "s") connected"
    }
}

struct IntegrationIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }
}

struct CrazyTelSettingsView: View {
    let store: NexusStore
    @AppStorage("crazytel_api_key") private var apiKey: String = ""
    @AppStorage("crazytel_enabled") private var enabled: Bool = false
    @State private var showingKey: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var showDIDDetail: CTDIDNumber?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.8), Color.green.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "phone.connection.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CrazyTel Softphone")
                            .font(.headline)
                        Text("SIP-based VoIP integration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Enable Integration", isOn: $enabled)
                    .onChange(of: enabled) { _, newValue in
                        if newValue && !apiKey.isEmpty {
                            Task { await store.connectCrazyTel() }
                        } else if !newValue {
                            store.disconnectCrazyTel()
                        }
                    }
            } header: {
                Text("Connection")
            } footer: {
                Text("Enter your API key from the CrazyTel customer portal.")
            }

            if enabled {
                Section("API Key") {
                    HStack {
                        if showingKey {
                            TextField("x-crazytel-api-key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.subheadline, design: .monospaced))
                        } else {
                            SecureField("x-crazytel-api-key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        Button {
                            showingKey.toggle()
                        } label: {
                            Image(systemName: showingKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        isTestingConnection = true
                        store.crazytelAPIKey = apiKey
                        Task {
                            await store.connectCrazyTel()
                            isTestingConnection = false
                        }
                    } label: {
                        HStack {
                            if isTestingConnection || store.ctIsLoading {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Connecting...")
                                    .font(.subheadline)
                            } else {
                                Label("Test Connection", systemImage: "bolt.fill")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isTestingConnection)
                }

                connectionStatusSection

                if store.ctConnectionStatus == .connected {
                    accountSection
                    didInventorySection
                    routingSection
                }
            }
        }
        .navigationTitle("CrazyTel")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refreshCrazyTel()
        }
        .sheet(item: $showDIDDetail) { did in
            DIDDetailSheet(did: did, store: store)
        }
    }

    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                Spacer()
                if store.ctConnectionStatus == .connected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            if let error = store.ctError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Status")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let balance = store.ctBalance {
                HStack {
                    Label("Balance", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                    Spacer()
                    Text(balance, format: .currency(code: "AUD"))
                        .font(.subheadline.bold())
                        .foregroundStyle(balance > 50 ? .green : (balance > 10 ? .orange : .red))
                }
            }

            HStack {
                Label("Active DIDs", systemImage: "number")
                    .font(.subheadline)
                Spacer()
                Text("\(store.ctDIDs.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var didInventorySection: some View {
        Section {
            if store.ctDIDs.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "phone.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No DIDs found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Purchase DIDs from the CrazyTel portal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                ForEach(store.ctDIDs) { did in
                    Button {
                        showDIDDetail = did
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(did.formattedNumber)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if let desc = did.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if let entity = matchedEntity(for: did) {
                                Text(entity.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                }
            }
        } header: {
            HStack {
                Text("DID Inventory")
                Spacer()
                Button {
                    Task { await store.fetchCrazyTelDIDs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        }
    }

    private var routingSection: some View {
        Section {
            LabeledContent("SMS Forwarding", value: "All DIDs → Nexus")
            LabeledContent("Call Forwarding", value: "All DIDs → Nexus")
            LabeledContent("Voicemail", value: "Transcribe + Store")
        } header: {
            Text("Routing")
        } footer: {
            Text("All inbound SMS, calls, and voicemails are routed through the CrazyTel API into your unified inbox. Each is auto-tagged to the matching entity.")
        }
    }

    private var statusColor: Color {
        switch store.ctConnectionStatus {
        case .connected: .green
        case .connecting: .orange
        case .error: .red
        case .disconnected: .secondary
        }
    }

    private var statusText: String {
        switch store.ctConnectionStatus {
        case .connected: "Connected"
        case .connecting: "Connecting..."
        case .error: "Connection Failed"
        case .disconnected: "Disconnected"
        }
    }

    private func matchedEntity(for did: CTDIDNumber) -> NexusEntity? {
        store.entities.first { entity in
            let cleaned = entity.assignedPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            let didCleaned = did.did_number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return !cleaned.isEmpty && !didCleaned.isEmpty && (cleaned.hasSuffix(didCleaned.suffix(8)) || didCleaned.hasSuffix(cleaned.suffix(8)))
        }
    }
}

struct DIDDetailSheet: View {
    let did: CTDIDNumber
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Number") {
                    LabeledContent("DID", value: did.formattedNumber)
                    if let route = did.primary_route {
                        LabeledContent("Route", value: route)
                    }
                    if let dest = did.primary_destination {
                        LabeledContent("Destination", value: dest)
                    }
                    if let status = did.status {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(status.capitalized)
                                .foregroundStyle(status.lowercased() == "active" ? .green : .orange)
                        }
                    }
                }

                if let desc = did.description, !desc.isEmpty {
                    Section("Description") {
                        Text(desc)
                            .font(.subheadline)
                    }
                }

                if let entity = matchedEntity {
                    Section("Linked Identity") {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.blue.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: entity.type.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entity.name)
                                    .font(.subheadline.weight(.medium))
                                Text(entity.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section {
                        Label("Not linked to any identity", systemImage: "link.badge.plus")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Assign this number to an identity to auto-tag incoming communications.")
                    }
                }
            }
            .navigationTitle("DID Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var matchedEntity: NexusEntity? {
        store.entities.first { entity in
            let cleaned = entity.assignedPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            let didCleaned = did.did_number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return !cleaned.isEmpty && !didCleaned.isEmpty && (cleaned.hasSuffix(didCleaned.suffix(8)) || didCleaned.hasSuffix(cleaned.suffix(8)))
        }
    }
}

struct EmailIntegrationView: View {
    let store: NexusStore
    @State private var showAddAccount: Bool = false
    @State private var editingAccount: EmailAccount?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Email Accounts", systemImage: "envelope.badge.fill")
                        .font(.headline)
                    Text("Sign in to email accounts and link them to identities. Each identity gets its own dedicated email inbox.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                if store.emailAccounts.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.open")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No accounts connected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Sign in with Gmail, Outlook, Yahoo, or IMAP")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(store.emailAccounts) { account in
                        Button {
                            editingAccount = account
                        } label: {
                            EmailAccountRow(account: account, store: store)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.removeEmailAccount(account)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Accounts (\(store.emailAccounts.count))")
                    Spacer()
                    Button {
                        showAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                    }
                }
            }

            if !store.emailAccounts.isEmpty {
                Section("Account Links") {
                    ForEach(store.emailAccounts) { account in
                        HStack(spacing: 10) {
                            Image(systemName: account.provider.icon)
                                .font(.caption)
                                .foregroundStyle(account.provider.color)
                                .frame(width: 20)
                            Text(account.emailAddress)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            if let entity = store.entityForEmailAccount(account.id) {
                                Text(entity.name)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                            } else {
                                Text("Unlinked")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section {
                    LabeledContent("Signed In", value: "\(store.loggedInAccountCount)")
                    LabeledContent("Unread Emails", value: "\(store.unreadEmailCount)")
                    if let lastSync = store.emailAccounts.compactMap({ $0.lastSyncDate }).max() {
                        LabeledContent("Last Sync") {
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Overview")
                }
            }
        }
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAccount) {
            AddEmailAccountSheet(store: store)
        }
        .sheet(item: $editingAccount) { account in
            EmailAccountDetailSheet(account: account, store: store)
        }
    }
}

struct EmailAccountRow: View {
    let account: EmailAccount
    let store: NexusStore

    var body: some View {
        HStack(spacing: 12) {
            IntegrationIcon(icon: account.provider.icon, color: account.provider.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(account.emailAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let entity = store.entityForEmailAccount(account.id) {
                Text(entity.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }

            let unread = store.unreadCountForAccount(account.id)
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.red)
                    .clipShape(Capsule())
            }

            statusIndicator
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch account.loginStatus {
        case .loggedIn: .green
        case .loggedOut: .secondary
        case .error: .red
        case .authenticating: .orange
        }
    }
}

struct EmailAccountDetailSheet: View {
    let account: EmailAccount
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var showPassword: Bool = false
    @State private var showRemoveConfirm: Bool = false
    @State private var selectedEntityId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [account.provider.color.opacity(0.8), account.provider.color.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            Image(systemName: account.provider.icon)
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.headline)
                            Text(account.emailAddress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Linked Identity") {
                    Picker("Identity", selection: $selectedEntityId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.entities.filter { $0.status != .archived }) { entity in
                            HStack {
                                Image(systemName: entity.type.icon)
                                Text(entity.name)
                            }
                            .tag(Optional(entity.id))
                        }
                    }
                    .onChange(of: selectedEntityId) { _, newValue in
                        if let entityId = newValue {
                            store.linkEmailAccount(account.id, toEntity: entityId)
                        } else {
                            if let current = store.entityForEmailAccount(account.id) {
                                store.unlinkEmailAccount(fromEntity: current.id)
                            }
                        }
                    }
                }

                Section {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(account.loginStatus.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(statusColor)
                        Spacer()
                        if account.loginStatus == .loggedIn {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if let error = account.loginError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let syncDate = account.lastSyncDate {
                        LabeledContent("Last Sync") {
                            Text(syncDate, style: .relative)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Status")
                }

                if account.loginStatus != .loggedIn {
                    Section {
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(.subheadline, design: .monospaced))
                            } else {
                                SecureField(account.provider.requiresAppPassword ? "App Password" : "Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .font(.system(.subheadline, design: .monospaced))
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            isLoggingIn = true
                            store.loginEmailAccount(account, password: password)
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                isLoggingIn = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isLoggingIn {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Signing in...")
                                        .font(.subheadline)
                                } else {
                                    Label("Sign In", systemImage: "arrow.right.circle.fill")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .disabled(password.isEmpty || isLoggingIn)
                    } header: {
                        Text("Credentials")
                    } footer: {
                        if account.provider.requiresAppPassword {
                            Text(account.provider.appPasswordHelp)
                        }
                    }
                } else {
                    Section {
                        Button {
                            store.logoutEmailAccount(account)
                            dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Server Settings") {
                    LabeledContent("IMAP", value: account.imapHost)
                    LabeledContent("IMAP Port", value: "\(account.imapPort)")
                    LabeledContent("SMTP", value: account.smtpHost)
                    LabeledContent("SMTP Port", value: "\(account.smtpPort)")
                    LabeledContent("SSL", value: account.useSSL ? "Enabled" : "Disabled")
                }

                Section {
                    Button(role: .destructive) {
                        showRemoveConfirm = true
                    } label: {
                        Label("Remove Account", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove Account", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    store.removeEmailAccount(account)
                    dismiss()
                }
            } message: {
                Text("This will remove \(account.emailAddress) and delete saved credentials.")
            }
            .onAppear {
                selectedEntityId = store.entityForEmailAccount(account.id)?.id
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var statusColor: Color {
        switch account.loginStatus {
        case .loggedIn: .green
        case .loggedOut: .secondary
        case .error: .red
        case .authenticating: .orange
        }
    }
}

struct AddEmailAccountSheet: View {
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: EmailProvider = .gmail
    @State private var emailAddress: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var imapHost: String = ""
    @State private var imapPort: String = "993"
    @State private var smtpHost: String = ""
    @State private var smtpPort: String = "587"
    @State private var showPassword: Bool = false
    @State private var isLoggingIn: Bool = false
    @State private var currentStep: Int = 0
    @State private var selectedEntityId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                if currentStep == 0 {
                    providerSection
                } else {
                    credentialsSection
                }
            }
            .navigationTitle(currentStep == 0 ? "Add Account" : selectedProvider.subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep == 0 {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Back") {
                            withAnimation(.snappy) { currentStep = 0 }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if currentStep == 1 {
                        Button {
                            signIn()
                        } label: {
                            if isLoggingIn {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .disabled(!canSignIn || isLoggingIn)
                    }
                }
            }
        }
    }

    private var providerSection: some View {
        Section {
            ForEach(EmailProvider.allCases) { provider in
                Button {
                    selectedProvider = provider
                    imapHost = provider.defaultIMAPHost
                    imapPort = "\(provider.defaultIMAPPort)"
                    smtpHost = provider.defaultSMTPHost
                    smtpPort = "\(provider.defaultSMTPPort)"
                    withAnimation(.snappy) { currentStep = 1 }
                } label: {
                    HStack(spacing: 14) {
                        IntegrationIcon(icon: provider.icon, color: provider.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.subtitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(provider == .imap ? "Custom IMAP server" : provider.defaultIMAPHost)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Choose Provider")
        } footer: {
            Text("Select your email provider to sign in. Credentials are stored securely in your device Keychain.")
        }
    }

    private var credentialsSection: some View {
        Group {
            Section {
                HStack(spacing: 12) {
                    IntegrationIcon(icon: selectedProvider.icon, color: selectedProvider.color)
                    Text(selectedProvider.subtitle)
                        .font(.subheadline.weight(.medium))
                }
            }

            Section {
                TextField("Email Address", text: $emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()

                HStack {
                    if showPassword {
                        TextField(selectedProvider.requiresAppPassword ? "App Password" : "Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.subheadline, design: .monospaced))
                    } else {
                        SecureField(selectedProvider.requiresAppPassword ? "App Password" : "Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Display Name (optional)", text: $displayName)
            } header: {
                Text("Sign In")
            } footer: {
                if selectedProvider.requiresAppPassword {
                    Text(selectedProvider.appPasswordHelp)
                }
            }

            Section("Link to Identity") {
                Picker("Identity", selection: $selectedEntityId) {
                    Text("Link later").tag(UUID?.none)
                    ForEach(store.entities.filter { $0.status != .archived && $0.emailAccountId == nil }) { entity in
                        HStack {
                            Image(systemName: entity.type.icon)
                            Text(entity.name)
                        }
                        .tag(Optional(entity.id))
                    }
                }
            }

            if selectedProvider == .imap {
                Section("Server Settings") {
                    TextField("IMAP Host", text: $imapHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("IMAP Port", text: $imapPort)
                        .keyboardType(.numberPad)
                    TextField("SMTP Host", text: $smtpHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("SMTP Port", text: $smtpPort)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var canSignIn: Bool {
        let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !pass.isEmpty else { return false }
        if selectedProvider == .imap {
            return !imapHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func signIn() {
        isLoggingIn = true
        let account = EmailAccount(
            provider: selectedProvider,
            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            loginStatus: .authenticating,
            imapHost: imapHost,
            imapPort: Int(imapPort) ?? 993,
            smtpHost: smtpHost,
            smtpPort: Int(smtpPort) ?? 587
        )
        store.addAndLoginEmailAccount(account, password: password.trimmingCharacters(in: .whitespacesAndNewlines))

        if let entityId = selectedEntityId {
            store.linkEmailAccount(account.id, toEntity: entityId)
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isLoggingIn = false
            dismiss()
        }
    }
}

struct ArchivedEntitiesView: View {
    let store: NexusStore

    private var archivedEntities: [NexusEntity] {
        store.entities.filter { $0.status == .archived }
    }

    var body: some View {
        List {
            ForEach(archivedEntities) { entity in
                EntityRowView(entity: entity)
            }
        }
        .navigationTitle("Archived")
        .overlay {
            if archivedEntities.isEmpty {
                ContentUnavailableView("No Archived Identities", systemImage: "archivebox", description: Text("Archived identities will appear here"))
            }
        }
    }
}

struct AddEntitySheet: View {
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var type: EntityType = .ltd
    @State private var creditLimit: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""
    @State private var selectedEmailAccountId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Identity Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(EntityType.allCases) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    TextField("Credit Limit (AUD)", text: $creditLimit)
                        .keyboardType(.decimalPad)
                }

                Section("Contact") {
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email Alias", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                if !store.emailAccounts.isEmpty {
                    Section("Link Email Account") {
                        Picker("Account", selection: $selectedEmailAccountId) {
                            Text("None").tag(UUID?.none)
                            ForEach(store.emailAccounts.filter { store.entityForEmailAccount($0.id) == nil }) { account in
                                HStack {
                                    Image(systemName: account.provider.icon)
                                    Text(account.emailAddress)
                                }
                                .tag(Optional(account.id))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entity = NexusEntity(
                            id: UUID(),
                            name: name,
                            type: type,
                            status: .active,
                            healthScore: 75,
                            creditLimit: Double(creditLimit) ?? 0,
                            utilisationPercent: 0,
                            monthlyBurn: 25,
                            assignedPhone: phone,
                            assignedEmail: email,
                            clearScore: 750,
                            lastActivityDate: Date(),
                            isFlagged: false,
                            notes: notes,
                            createdDate: Date(),
                            emailAccountId: selectedEmailAccountId
                        )
                        store.addEntity(entity)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
