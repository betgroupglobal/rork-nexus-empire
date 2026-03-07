import SwiftUI

nonisolated enum SubjectFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case active = "Active"
    case pending = "Pending"
    case atRisk = "At Risk"
    case highProgress = "High Progress"

    var id: String { rawValue }
}

struct SubjectDatabaseView: View {
    let store: NexusStore
    @Environment(\.isVoidTheme) private var isVoidTheme
    @State private var searchText: String = ""
    @State private var selectedFilter: SubjectFilter = .all
    @State private var selectedSubject: Subject?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                filterStrip
                    .padding(.top, 4)

                if filteredSubjects.isEmpty {
                    ContentUnavailableView("No Subjects", systemImage: "person.crop.circle.badge.questionmark", description: Text("No subjects match your search"))
                        .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredSubjects) { subject in
                            SubjectCard(subject: subject, isVoidTheme: isVoidTheme)
                                .contentShape(.rect)
                                .onTapGesture {
                                    selectedSubject = subject
                                }
                                .contextMenu {
                                    Button {
                                        store.toggleSubjectFlag(subject)
                                    } label: {
                                        Label(subject.isFlagged ? "Unflag" : "Flag", systemImage: subject.isFlagged ? "flag.slash" : "flag.fill")
                                    }
                                    Button(role: .destructive) {
                                        store.archiveSubject(subject)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(isVoidTheme ? Color.black : Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search by name, bank, or progress...")
        .navigationTitle("Subjects")
        .navigationDestination(item: $selectedSubject) { subject in
            SubjectDetailView(subject: subject, store: store)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SubjectFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.blue : (isVoidTheme ? Color.white.opacity(0.08) : Color(.tertiarySystemGroupedBackground)))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selectedFilter)
    }

    private var filteredSubjects: [Subject] {
        var result = store.subjects

        switch selectedFilter {
        case .all: break
        case .active: result = result.filter { $0.status == .active }
        case .pending: result = result.filter { $0.status == .pending }
        case .atRisk: result = result.filter { $0.status == .atRisk }
        case .highProgress: result = result.filter { $0.overallProgress >= 70 }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.banksApplied.contains { $0.localizedStandardContains(searchText) } ||
                "\($0.overallProgress)".contains(searchText)
            }
        }

        return result.sorted { $0.lastActivityDate > $1.lastActivityDate }
    }
}

struct SubjectCard: View {
    let subject: Subject
    let isVoidTheme: Bool

    private var statusColor: Color {
        switch subject.status {
        case .active: .green
        case .pending: .orange
        case .atRisk: .red
        case .archived: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            CreditScoreGauge(score: subject.creditScore, size: 52, lineWidth: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(subject.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if subject.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Text(subject.status.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 4) {
                    Image(systemName: subject.type.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(subject.banksApplied.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    progressBar

                    Text(subject.lastActivityDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    Label(subject.assignedPhone, systemImage: "phone.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Label(subject.assignedEmail, systemImage: "envelope.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(subject.overallProgress) / 100)
                }
            }
            .frame(height: 5)

            Text("\(subject.overallProgress)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(progressColor)
        }
        .frame(maxWidth: 120)
    }

    private var progressColor: Color {
        if subject.overallProgress >= 80 { return .green }
        if subject.overallProgress >= 50 { return .blue }
        return .orange
    }
}
