import SwiftUI

struct CommsView: View {
    let store: NexusStore
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
                    CommRowView(comm: comm)
                }
                .tint(.primary)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search messages...")
        .navigationTitle("Comms")
        .overlay {
            if filteredComms.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "antenna.radiowaves.left.and.right", description: Text("No communications match your filters"))
            }
        }
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
        .sheet(item: $selectedComm) { comm in
            CommDetailSheet(comm: comm)
        }
        .sheet(isPresented: $showCompose) {
            SMSComposeView(store: store)
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterButton(label: "All", type: nil, icon: "tray.fill")
                filterButton(label: "SMS", type: .sms, icon: "message.fill")
                filterButton(label: "Calls", type: .call, icon: "phone.fill")
                filterButton(label: "Voicemail", type: .voicemail, icon: "recordingtape.fill")
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private func filterButton(label: String, type: CommType?, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = type
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedTab == type ? .blue : Color(.tertiarySystemGroupedBackground))
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
                $0.sender.localizedStandardContains(searchText)
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }
}

struct CommDetailSheet: View {
    let comm: Communication
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
                            Text(comm.type.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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

    private var typeColor: Color {
        switch comm.type {
        case .sms: .blue
        case .call: .green
        case .voicemail: .purple
        }
    }
}
