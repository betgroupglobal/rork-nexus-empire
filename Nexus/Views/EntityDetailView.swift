import SwiftUI

nonisolated enum DetailTab: String, CaseIterable, Identifiable, Sendable {
    case details = "Details"
    case emails = "Emails"
    case comms = "Comms"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .details: "person.text.rectangle"
        case .emails: "envelope"
        case .comms: "message"
        }
    }
}

struct EntityDetailView: View {
    let store: NexusStore
    let entity: NexusEntity
    @State private var selectedTab: DetailTab = .details
    @State private var appeared: Bool = false
    @State private var selectedComm: Communication?
    @State private var selectedEmail: EmailMessage?
    @State private var showEditEntity: Bool = false

    private var liveEntity: NexusEntity {
        store.entities.first(where: { $0.id == entity.id }) ?? entity
    }

    private var linkedEmail: EmailAccount? {
        guard let accountId = liveEntity.emailAccountId else { return nil }
        return store.emailAccounts.first { $0.id == accountId }
    }

    private var entityEmails: [EmailMessage] {
        store.emailsForEntity(entity.id).sorted { $0.timestamp > $1.timestamp }
    }

    private var entityComms: [Communication] {
        store.commsForEntity(entity.id).sorted { $0.timestamp > $1.timestamp }
    }

    private var statusColor: Color {
        switch liveEntity.status {
        case .active: .green
        case .dormant: .yellow
        case .atRisk: .red
        case .archived: .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            profileHeader

            tabPicker

            TabView(selection: $selectedTab) {
                detailsContent
                    .tag(DetailTab.details)
                emailsContent
                    .tag(DetailTab.emails)
                commsContent
                    .tag(DetailTab.comms)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(liveEntity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        store.toggleEntityFlag(liveEntity)
                    } label: {
                        Label(
                            liveEntity.isFlagged ? "Remove Flag" : "Flag",
                            systemImage: liveEntity.isFlagged ? "flag.slash" : "flag.fill"
                        )
                    }
                    Button {
                        showEditEntity = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.archiveEntity(liveEntity)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedComm) { comm in
            CommDetailSheet(comm: comm)
        }
        .sheet(item: $selectedEmail) { email in
            EmailDetailSheet(email: email)
        }
        .sheet(isPresented: $showEditEntity) {
            EditEntitySheet(store: store, entity: liveEntity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                HealthRingView(score: liveEntity.healthScore, size: 56, lineWidth: 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Label(liveEntity.type.rawValue, systemImage: liveEntity.type.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 3) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                            Text(liveEntity.status.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(statusColor)
                        }

                        if liveEntity.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(liveEntity.firepowerAmount, format: .currency(code: "AUD").precision(.fractionLength(0)))
                        .font(.title3.bold())

                    if let email = linkedEmail {
                        HStack(spacing: 4) {
                            Image(systemName: email.provider.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(email.provider.color)
                            Text(email.emailAddress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.caption2)
                            Text(tab.rawValue)
                                .font(.subheadline.weight(.medium))
                            if tab == .emails {
                                let count = entityEmails.filter { !$0.isRead }.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            if tab == .comms {
                                let count = entityComms.filter { !$0.isRead }.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : .clear)
                            .frame(height: 2)
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var detailsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                creditCard
                contactCard
                alertsCard
                if !liveEntity.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }

    private var creditCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Credit Limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(liveEntity.creditLimit, format: .currency(code: "AUD").precision(.fractionLength(0)))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ClearScore")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(liveEntity.clearScore)")
                        .font(.headline)
                        .foregroundStyle(liveEntity.clearScore >= 700 ? .green : (liveEntity.clearScore >= 500 ? .orange : .red))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Utilisation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(liveEntity.utilisationPercent, specifier: "%.0f")%")
                        .font(.caption.bold())
                        .foregroundStyle(liveEntity.utilisationPercent > 25 ? .red : .green)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(height: 6)
                        Capsule()
                            .fill(liveEntity.utilisationPercent > 25 ? .red : .green)
                            .frame(width: geo.size.width * min(liveEntity.utilisationPercent / 100, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            HStack {
                Label("Burn/mo", systemImage: "flame")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(liveEntity.monthlyBurn, format: .currency(code: "AUD").precision(.fractionLength(0)))
                    .font(.caption.bold())
            }

            HStack {
                Label("Last Active", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(liveEntity.lastActivityDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            if !liveEntity.assignedPhone.isEmpty {
                contactRow(icon: "phone.fill", label: liveEntity.assignedPhone, color: .green)
            }
            if !liveEntity.assignedPhone.isEmpty && !liveEntity.assignedEmail.isEmpty {
                Divider().padding(.leading, 40)
            }
            if !liveEntity.assignedEmail.isEmpty {
                contactRow(icon: "envelope.fill", label: liveEntity.assignedEmail, color: .blue)
            }
            if let email = linkedEmail {
                Divider().padding(.leading, 40)
                HStack(spacing: 12) {
                    Image(systemName: email.provider.icon)
                        .font(.caption)
                        .foregroundStyle(email.provider.color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(email.displayName)
                            .font(.subheadline)
                        Text(email.provider.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Circle()
                        .fill(email.loginStatus == .loggedIn ? .green : .secondary)
                        .frame(width: 7, height: 7)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func contactRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var alertsCard: some View {
        let entityAlerts = store.alertsForEntity(entity.id).sorted { $0.timestamp > $1.timestamp }
        return Group {
            if !entityAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Alerts")
                            .font(.subheadline.bold())
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(entityAlerts.prefix(3))) { alert in
                            HStack(spacing: 10) {
                                Image(systemName: alert.type.icon)
                                    .font(.caption)
                                    .foregroundStyle(alert.priority == .critical ? .red : .orange)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alert.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                    Text(alert.message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(alert.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)

                            if alert.id != entityAlerts.prefix(3).last?.id {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.subheadline.bold())

            Text(liveEntity.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var emailsContent: some View {
        Group {
            if entityEmails.isEmpty {
                ContentUnavailableView("No Emails", systemImage: "envelope.open", description: Text("No emails linked to this identity"))
            } else {
                List {
                    ForEach(entityEmails) { email in
                        Button {
                            store.markEmailRead(email)
                            selectedEmail = email
                        } label: {
                            EntityEmailRow(email: email)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .leading) {
                            Button {
                                store.toggleEmailFlag(email)
                            } label: {
                                Label(email.isFlagged ? "Unflag" : "Flag", systemImage: "flag.fill")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var commsContent: some View {
        Group {
            if entityComms.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "message", description: Text("No SMS, calls, or voicemails for this identity"))
            } else {
                List {
                    ForEach(entityComms) { comm in
                        Button {
                            store.markCommRead(comm)
                            selectedComm = comm
                        } label: {
                            CommRowView(comm: comm)
                        }
                        .tint(.primary)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct EntityEmailRow: View {
    let email: EmailMessage

    private var categoryColor: Color {
        switch email.category {
        case .statement: .blue
        case .approval: .green
        case .atoNotice: .orange
        case .general: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: email.category.icon)
                    .font(.caption)
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(email.sender)
                        .font(.subheadline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .lineLimit(1)
                    Spacer()
                    if email.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(email.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(email.subject)
                    .font(.caption)
                    .fontWeight(email.isRead ? .regular : .medium)
                    .lineLimit(1)

                Text(email.snippet)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !email.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 2)
    }
}

struct EditEntitySheet: View {
    let store: NexusStore
    let entity: NexusEntity
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
                    TextField("Entity Name", text: $name)
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

                Section("Linked Email Account") {
                    Picker("Account", selection: $selectedEmailAccountId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.emailAccounts) { account in
                            HStack {
                                Image(systemName: account.provider.icon)
                                Text(account.emailAddress)
                            }
                            .tag(Optional(account.id))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = entity
                        updated.name = name
                        updated.type = type
                        updated.creditLimit = Double(creditLimit) ?? entity.creditLimit
                        updated.assignedPhone = phone
                        updated.assignedEmail = email
                        updated.notes = notes
                        updated.emailAccountId = selectedEmailAccountId
                        store.updateEntity(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = entity.name
                type = entity.type
                creditLimit = String(format: "%.0f", entity.creditLimit)
                phone = entity.assignedPhone
                email = entity.assignedEmail
                notes = entity.notes
                selectedEmailAccountId = entity.emailAccountId
            }
        }
    }
}
