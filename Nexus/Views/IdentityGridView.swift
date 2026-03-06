import SwiftUI

struct IdentityGridView: View {
    let store: NexusStore
    @State private var searchText: String = ""
    @State private var showAddEntity: Bool = false
    @State private var appeared: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeader

                if !store.urgentActions.isEmpty {
                    urgentBanner
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(filteredEntities.enumerated()), id: \.element.id) { index, entity in
                        NavigationLink(value: entity) {
                            IdentityTileView(entity: entity, store: store)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.4).delay(Double(index) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search identities...")
        .navigationTitle("Identities")
        .navigationDestination(for: NexusEntity.self) { entity in
            EntityDetailView(store: store, entity: entity)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddEntity = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntity) {
            AddEntitySheet(store: store)
        }
        .refreshable {
            await store.refreshData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Firepower")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text(store.totalFirepower, format: .currency(code: "AUD").precision(.fractionLength(0)))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                miniStat(value: "\(store.activeEntityCount)", label: "Active")
                Divider().frame(height: 24).background(.white.opacity(0.2))
                miniStat(value: store.monthlyBurn.formatted(.currency(code: "AUD").precision(.fractionLength(0))), label: "Burn/mo")
                Divider().frame(height: 24).background(.white.opacity(0.2))
                miniStat(value: "\(store.unreadCommsCount + store.unreadEmailCount)", label: "Unread")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.10, blue: 0.20), Color(red: 0.10, green: 0.16, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.5), value: appeared)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var urgentBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
            Text("\(store.urgentActions.count) urgent action\(store.urgentActions.count == 1 ? "" : "s")")
                .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var filteredEntities: [NexusEntity] {
        var result = store.entities.filter { $0.status != .archived }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.type.rawValue.localizedStandardContains(searchText) ||
                $0.assignedEmail.localizedStandardContains(searchText)
            }
        }
        return result.sorted { $0.healthScore > $1.healthScore }
    }
}
