import SwiftUI

struct SMSComposeView: View {
    let store: NexusStore
    var prefillTo: String = ""
    var prefillFrom: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var toNumber: String = ""
    @State private var messageText: String = ""
    @State private var selectedFromDID: String = ""
    @State private var showSuccessBanner: Bool = false

    private var canSend: Bool {
        !toNumber.isEmpty && !messageText.isEmpty && !selectedFromDID.isEmpty && !store.smsSending
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        fromSection
                        toSection
                        messageSection
                    }
                    .padding(16)
                }

                sendBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                toNumber = prefillTo
                if !prefillFrom.isEmpty {
                    selectedFromDID = prefillFrom
                } else if let first = store.ctDIDs.first {
                    selectedFromDID = first.did_number
                }
            }
            .onChange(of: store.smsSuccess) { _, newValue in
                if newValue {
                    showSuccessBanner = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        dismiss()
                    }
                }
            }
            .overlay {
                if showSuccessBanner {
                    successOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sensoryFeedback(.success, trigger: showSuccessBanner)
        }
    }

    private var fromSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("From", systemImage: "phone.arrow.up.right")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if store.ctDIDs.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No DID numbers available. Purchase a number in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            } else {
                Menu {
                    ForEach(store.ctDIDs) { did in
                        Button {
                            selectedFromDID = did.did_number
                        } label: {
                            HStack {
                                Text(did.formattedNumber)
                                if did.did_number == selectedFromDID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "sim")
                            .foregroundStyle(.green)
                        Text(formattedSelected)
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .tint(.primary)
            }
        }
    }

    private var toSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("To", systemImage: "phone.arrow.down.left")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.blue)
                TextField("04XX XXX XXX", text: $toNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Message", systemImage: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(messageText.count)/160")
                    .font(.caption2)
                    .foregroundStyle(messageText.count > 160 ? Color.red : Color(.tertiaryLabel))
            }

            TextField("Type your message...", text: $messageText, axis: .vertical)
                .lineLimit(4...8)
                .font(.body)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))

            if let error = store.smsError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var sendBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if store.smsSending {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Sending...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await store.sendSMS(
                            from: selectedFromDID,
                            to: normalizedTo,
                            message: messageText
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(canSend ? .blue : Color(.tertiarySystemFill))
                    .foregroundStyle(canSend ? .white : .secondary)
                    .clipShape(Capsule())
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private var successOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("SMS Sent Successfully")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var formattedSelected: String {
        store.ctDIDs.first(where: { $0.did_number == selectedFromDID })?.formattedNumber ?? selectedFromDID
    }

    private var normalizedTo: String {
        var num = toNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if num.hasPrefix("04") {
            num = "61" + num.dropFirst(1)
        } else if num.hasPrefix("+61") {
            num = String(num.dropFirst(1))
        }
        return num
    }
}
