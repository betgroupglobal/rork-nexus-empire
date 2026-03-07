import SwiftUI

nonisolated enum InboxFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case sms = "SMS"
    case calls = "Calls"
    case voicemail = "Voicemail"
    case email = "Email"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "tray"
        case .sms: "message"
        case .calls: "phone"
        case .voicemail: "recordingtape"
        case .email: "envelope"
        }
    }
}

struct UnifiedInboxView: View {
    let store: NexusStore
    @State private var filter: InboxFilter = .all
    @State private var searchText: String = ""
    @State private var selectedComm: Communication?
    @State private var selectedEmail: EmailMessage?
    @State private var showCompose: Bool = false

    var body: some View {
        List {
            filterStrip
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(unifiedItems) { item in
                Button {
                    switch item.kind {
                    case .comm(let comm):
                        store.markCommRead(comm)
                        selectedComm = comm
                    case .email(let email):
                        store.markEmailRead(email)
                        selectedEmail = email
                    }
                } label: {
                    InboxItemRow(item: item)
                }
                .tint(.primary)
                .swipeActions(edge: .leading) {
                    if case .email(let email) = item.kind {
                        Button {
                            store.toggleEmailFlag(email)
                        } label: {
                            Label(email.isFlagged ? "Unflag" : "Flag", systemImage: "flag.fill")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if case .email(let email) = item.kind {
                        Button(role: .destructive) {
                            withAnimation { store.deleteEmail(email) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            withAnimation { store.archiveEmail(email) }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.purple)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search inbox...")
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.ctConnectionStatus == .connected {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .overlay {
            if unifiedItems.isEmpty {
                ContentUnavailableView("Nothing Here", systemImage: "tray", description: Text("No messages match your filters"))
            }
        }
        .sheet(item: $selectedComm) { comm in
            CommDetailSheet(comm: comm)
        }
        .sheet(item: $selectedEmail) { email in
            EmailDetailSheet(email: email, store: store)
        }
        .sheet(isPresented: $showCompose) {
            SMSComposeView(store: store)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(InboxFilter.allCases) { f in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = f }
                    } label: {
                        Label(f.rawValue, systemImage: f.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(filter == f ? .blue : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(filter == f ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var unifiedItems: [InboxItem] {
        var items: [InboxItem] = []

        let showComms = filter == .all || filter == .sms || filter == .calls || filter == .voicemail

        if showComms {
            for comm in store.communications {
                let matchesType: Bool = {
                    switch filter {
                    case .sms: comm.type == .sms
                    case .calls: comm.type == .call
                    case .voicemail: comm.type == .voicemail
                    case .all: true
                    default: false
                    }
                }()
                guard matchesType else { continue }
                items.append(InboxItem(id: comm.id, timestamp: comm.timestamp, isRead: comm.isRead, kind: .comm(comm)))
            }
        }

        if filter == .all || filter == .email {
            for email in store.emails {
                items.append(InboxItem(id: email.id, timestamp: email.timestamp, isRead: email.isRead, kind: .email(email)))
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                switch item.kind {
                case .comm(let c):
                    return c.content.localizedStandardContains(searchText) ||
                           c.sender.localizedStandardContains(searchText)
                case .email(let e):
                    return e.subject.localizedStandardContains(searchText) ||
                           e.sender.localizedStandardContains(searchText)
                }
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }
}

struct InboxItem: Identifiable {
    let id: UUID
    let timestamp: Date
    let isRead: Bool
    let kind: InboxItemKind
}

enum InboxItemKind {
    case comm(Communication)
    case email(EmailMessage)
}

struct InboxItemRow: View {
    let item: InboxItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(item.isRead ? .regular : .semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(item.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !item.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        switch item.kind {
        case .comm(let c): c.sender
        case .email(let e): e.sender
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .comm(let c): c.content
        case .email(let e): e.subject
        }
    }

    private var iconName: String {
        switch item.kind {
        case .comm(let c): c.type.icon
        case .email: "envelope"
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .comm(let c):
            switch c.type {
            case .sms: .blue
            case .call: .green
            case .voicemail: .purple
            }
        case .email: .teal
        }
    }
}
