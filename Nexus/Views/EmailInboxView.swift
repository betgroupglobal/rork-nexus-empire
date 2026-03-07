import SwiftUI

struct EmailInboxView: View {
    let store: NexusStore
    @State private var selectedCategory: EmailCategory? = nil
    @State private var selectedAccountId: UUID? = nil
    @State private var searchText: String = ""
    @State private var selectedEmail: EmailMessage?

    var body: some View {
        List {
            if !store.emailAccounts.isEmpty {
                accountStrip
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            filterSection
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredEmails) { email in
                Button {
                    store.markEmailRead(email)
                    selectedEmail = email
                } label: {
                    EmailRowView(email: email, accountName: accountName(for: email))
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search emails...")
        .navigationTitle("Email Inbox")
        .overlay {
            if filteredEmails.isEmpty {
                ContentUnavailableView("No Emails", systemImage: "envelope.open", description: Text("No emails match your filters"))
            }
        }
        .sheet(item: $selectedEmail) { email in
            EmailDetailSheet(email: email, accountName: accountName(for: email), store: store)
        }
    }

    private var accountStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                accountChip(label: "All Accounts", accountId: nil, icon: "tray.2", color: .blue)
                ForEach(store.emailAccounts) { account in
                    accountChip(
                        label: account.displayName,
                        accountId: account.id,
                        icon: account.provider.icon,
                        color: account.provider.color,
                        badge: store.unreadCountForAccount(account.id)
                    )
                }
            }
            .padding(.vertical, 6)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private func accountChip(label: String, accountId: UUID?, icon: String, color: Color, badge: Int = 0) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedAccountId = accountId }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                if badge > 0 && selectedAccountId != accountId {
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selectedAccountId == accountId ? color : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(selectedAccountId == accountId ? .white : .primary)
            .clipShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: selectedAccountId)
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryButton(label: "All", category: nil)
                ForEach(EmailCategory.allCases) { cat in
                    categoryButton(label: cat.rawValue, category: cat)
                }
            }
            .padding(.vertical, 4)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private func categoryButton(label: String, category: EmailCategory?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? .teal : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(selectedCategory == category ? .white : .primary)
                .clipShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }

    private var filteredEmails: [EmailMessage] {
        var result = store.emails

        if let accountId = selectedAccountId {
            result = result.filter { $0.accountId == accountId }
        }

        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.subject.localizedStandardContains(searchText) ||
                $0.sender.localizedStandardContains(searchText) ||
                $0.snippet.localizedStandardContains(searchText)
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }

    private func accountName(for email: EmailMessage) -> String? {
        guard let accountId = email.accountId else { return nil }
        return store.emailAccounts.first { $0.id == accountId }?.displayName
    }
}

struct EmailDetailSheet: View {
    let email: EmailMessage
    var accountName: String? = nil
    var store: NexusStore?
    @Environment(\.dismiss) private var dismiss
    @State private var showArchiveConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(email.subject)
                            .font(.title3.bold())

                        HStack {
                            Text(email.sender)
                                .font(.subheadline.bold())
                            Text("<\(email.senderAddress)>")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text(email.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.teal.opacity(0.1))
                                .foregroundStyle(.teal)
                                .clipShape(Capsule())

                            if email.containsDollarAmount {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.green)
                            }

                            if email.isFlagged {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(.orange)
                            }
                        }

                        HStack(spacing: 12) {
                            Label(email.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label(email.alias, systemImage: "at")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let accountName {
                            Label(accountName, systemImage: "person.crop.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    actionBar

                    Divider()

                    Text(email.snippet)
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Archive Email", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
                Button("Archive") {
                    store?.archiveEmail(email)
                    dismiss()
                }
            } message: {
                Text("Move this email to the archive?")
            }
            .confirmationDialog("Delete Email", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store?.deleteEmail(email)
                    dismiss()
                }
            } message: {
                Text("Permanently delete this email?")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton(icon: "arrowshape.turn.up.left.fill", label: "Reply", color: .blue) {}
            actionButton(icon: "arrowshape.turn.up.right.fill", label: "Forward", color: .blue) {}
            actionButton(icon: "flag.fill", label: email.isFlagged ? "Unflag" : "Flag", color: .orange) {
                store?.toggleEmailFlag(email)
            }
            actionButton(icon: "archivebox.fill", label: "Archive", color: .purple) {
                showArchiveConfirm = true
            }
            actionButton(icon: "trash.fill", label: "Delete", color: .red) {
                showDeleteConfirm = true
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
