import SwiftUI

struct SubjectDetailView: View {
    let subject: Subject
    let store: NexusStore
    @Environment(\.isVoidTheme) private var isVoidTheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                personalInfoSection
                applicationsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(isVoidTheme ? Color.black : Color(.systemGroupedBackground))
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            CreditScoreGauge(score: subject.creditScore, size: 72, lineWidth: 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: subject.type.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(subject.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(subject.name)
                    .font(.title3.bold())

                HStack(spacing: 8) {
                    statusBadge

                    if subject.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text("\(subject.activeApplicationCount) active application\(subject.activeApplicationCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var statusBadge: some View {
        let color: Color = {
            switch subject.status {
            case .active: .green
            case .pending: .orange
            case .atRisk: .red
            case .archived: .secondary
            }
        }()
        return Text(subject.status.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Personal Information", systemImage: "person.text.rectangle")
                .font(.subheadline.bold())
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                infoRow(label: "Name", value: subject.name)
                Divider().padding(.leading, 100)
                if !subject.dateOfBirth.isEmpty {
                    infoRow(label: "DOB", value: subject.dateOfBirth)
                    Divider().padding(.leading, 100)
                }
                infoRow(label: "Address", value: subject.address.isEmpty ? "—" : subject.address)
                Divider().padding(.leading, 100)
                infoRow(label: "ID", value: subject.idNumber.isEmpty ? "—" : subject.idNumber)
                Divider().padding(.leading, 100)
                infoRow(label: "Phone", value: subject.assignedPhone)
                Divider().padding(.leading, 100)
                infoRow(label: "Email", value: subject.assignedEmail)
            }
            .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Credit Applications", systemImage: "doc.text.magnifyingglass")
                .font(.subheadline.bold())
                .padding(.bottom, 2)

            if subject.applications.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No applications")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(subject.applications) { app in
                        applicationRow(app)

                        if app.id != subject.applications.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(isVoidTheme ? Color(.systemGray6).opacity(0.12) : Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func applicationRow(_ app: CreditApplication) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.bank)
                        .font(.subheadline.bold())
                    Text(app.product)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                appStatusBadge(app.status)
            }

            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                        Capsule()
                            .fill(appProgressColor(app.progressPercent))
                            .frame(width: geo.size.width * CGFloat(app.progressPercent) / 100)
                    }
                }
                .frame(height: 6)

                Text("\(app.progressPercent)%")
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(appProgressColor(app.progressPercent))
                    .frame(width: 36, alignment: .trailing)
            }

            HStack(spacing: 16) {
                detailLabel("Submitted", value: app.submittedDate.formatted(date: .abbreviated, time: .omitted))
                detailLabel("Updated", value: app.lastUpdateDate.formatted(date: .abbreviated, time: .omitted))
                if app.isActive {
                    detailLabel("Days", value: "\(app.daysActive)")
                }
            }

            if !app.nextAction.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(app.nextAction)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }

            if !app.documents.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(app.documents)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }

    private func appStatusBadge(_ status: ApplicationStatus) -> some View {
        let color: Color = {
            switch status {
            case .submitted: .blue
            case .inReview: .orange
            case .approved: .green
            case .declined: .red
            case .documentsNeeded: .purple
            case .stalled: .red
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 9))
            Text(status.rawValue)
                .font(.caption2.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func appProgressColor(_ percent: Int) -> Color {
        if percent >= 80 { return .green }
        if percent >= 50 { return .blue }
        if percent > 0 { return .orange }
        return .red
    }

    private func detailLabel(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
