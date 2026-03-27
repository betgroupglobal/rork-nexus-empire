import SwiftUI

struct CommsView: View {
    let store: NexusStore
    @Environment(\.isVoidTheme) private var isVoidTheme
    @State private var selectedTab: CommType? = nil
    @State private var searchText: String = ""
    @State private var selectedComm: Communication?
    @State private var showCompose: Bool = false

    var body: some View {
        List {
            filterSection
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredComms) { comm in
                Button {
                    store.markCommRead(comm)
                    selectedComm = comm
                } label: {
                    CommRowView(comm: comm, store: store)
                }
                .tint(.primary)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search messages...")
        .navigationTitle("Comms Citadel")
        .overlay {
            if filteredComms.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "antenna.radiowaves.left.and.right", description: Text("No communications match your filters"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.ctConnectionStatus == .connected {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(item: $selectedComm) { comm in
            CommDetailSheet(comm: comm, store: store)
        }
        .sheet(isPresented: $showCompose) {
            SMSComposeView(store: store)
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil, icon: "tray.fill", count: store.communications.count)
                filterChip(label: "SMS", type: .sms, icon: "message.fill", count: store.communications.filter { $0.type == .sms }.count)
                filterChip(label: "Calls", type: .call, icon: "phone.fill", count: store.communications.filter { $0.type == .call }.count)
                filterChip(label: "Voicemail", type: .voicemail, icon: "recordingtape.fill", count: store.communications.filter { $0.type == .voicemail }.count)
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private func filterChip(label: String, type: CommType?, icon: String, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = type
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.subheadline)
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(selectedTab == type ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == type ? .blue : (isVoidTheme ? Color.white.opacity(0.08) : Color(.tertiarySystemGroupedBackground)))
            .foregroundStyle(selectedTab == type ? .white : .primary)
            .clipShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private var filteredComms: [Communication] {
        var result = store.communications
        if let tab = selectedTab {
            result = result.filter { $0.type == tab }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.content.localizedStandardContains(searchText) ||
                $0.sender.localizedStandardContains(searchText) ||
                ($0.subjectName?.localizedStandardContains(searchText) ?? false)
            }
        }
        return result.sorted { $0.timestamp > $1.timestamp }
    }
}

struct CommDetailSheet: View {
    let comm: Communication
    let store: NexusStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(typeColor.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: comm.type.icon)
                                .font(.title3)
                                .foregroundStyle(typeColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(comm.sender)
                                .font(.title3.bold())

                            HStack(spacing: 6) {
                                Text(comm.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let name = comm.subjectName {
                                    subjectBadge(name)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(comm.phoneNumber, systemImage: "phone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label(comm.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let duration = comm.duration {
                            Label("\(Int(duration / 60))m \(Int(duration) % 60)s", systemImage: "timer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                        Text(comm.content)
                            .font(.body)
                    }

                    if let transcription = comm.transcription {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Voicemail Transcription", systemImage: "text.quote")
                                .font(.headline)

                            if let duration = comm.duration {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    ProgressView(value: 0.0)
                                        .tint(.blue)
                                    Text("\(Int(duration))s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(transcription)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Message Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func subjectBadge(_ name: String) -> some View {
        let subject = store.subjects.first { $0.name.localizedStandardContains(name) || name.localizedStandardContains($0.name) }
        let color: Color = {
            guard let s = subject else { return .secondary }
            if s.creditScore >= 80 { return .green }
            if s.creditScore >= 50 { return .yellow }
            return .red
        }()
        return Text(name)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var typeColor: Color {
        switch comm.type {
        case .sms: .blue
        case .call: .green
        case .voicemail: .purple
        }
    }
}
