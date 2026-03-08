import Foundation

@MainActor
class NexusAPIService {
    static let shared = NexusAPIService()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenKey = "auth_token"

    private init() {
        let configURL = Config.EXPO_PUBLIC_RORK_API_BASE_URL
        baseURL = configURL.isEmpty ? "" : configURL + "/api/trpc"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    private var authToken: String? {
        KeychainService.load(key: tokenKey)
    }

    private func buildQueryURL(procedure: String, input: (any Encodable)? = nil) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        var urlString = "\(baseURL)/\(procedure)"
        if let input {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(SuperJSONInput(json: AnyEncodable(input))),
               let jsonString = String(data: data, encoding: .utf8) {
                let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jsonString
                urlString += "?input=\(encoded)"
            }
        }
        return URL(string: urlString)
    }

    func performQuery<T: Decodable & Sendable>(procedure: String, input: (any Encodable)? = nil) async throws -> T {
        guard let url = buildQueryURL(procedure: procedure, input: input) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        try Self.checkHTTPError(data: data, response: response, decoder: decoder)
        let trpcResponse = try decoder.decode(TRPCResponse<T>.self, from: data)
        return trpcResponse.result.data.json
    }

    func performMutation<T: Decodable & Sendable>(procedure: String, input: any Encodable) async throws -> T {
        guard !baseURL.isEmpty else { throw APIError.invalidURL }
        guard let url = URL(string: "\(baseURL)/\(procedure)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(SuperJSONInput(json: AnyEncodable(input)))

        let (data, response) = try await session.data(for: request)
        try Self.checkHTTPError(data: data, response: response, decoder: decoder)
        let trpcResponse = try decoder.decode(TRPCResponse<T>.self, from: data)
        return trpcResponse.result.data.json
    }

    private static func checkHTTPError(data: Data, response: URLResponse, decoder: JSONDecoder) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let body = String(data: data, encoding: .utf8) ?? ""
        let isHTML = body.contains("<html") || body.contains("<!DOCTYPE") || body.contains("<HTML")
        if isHTML {
            throw APIError.serverError(http.statusCode, "Server returned an unexpected response. Please try again.")
        }
        guard http.statusCode >= 400 else { return }
        if let trpcError = try? decoder.decode(TRPCErrorResponse.self, from: data) {
            let message = trpcError.error.message ?? trpcError.error.data?.message ?? "Server error"
            throw APIError.serverError(http.statusCode, message)
        }
        throw APIError.serverError(http.statusCode, "Server error (\(http.statusCode)). Please try again.")
    }

    func markCommRead(id: String) async throws -> Communication {
        let dto: CommunicationDTO = try await performMutation(procedure: "communications.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func markEmailRead(id: String) async throws -> EmailMessage {
        let dto: EmailDTO = try await performMutation(procedure: "emails.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func toggleEmailFlag(id: String) async throws -> EmailMessage {
        let dto: EmailDTO = try await performMutation(procedure: "emails.toggleFlag", input: IDInput(id: id))
        return dto.toModel()
    }

    func markAlertRead(id: String) async throws -> NexusAlert {
        let dto: AlertDTO = try await performMutation(procedure: "alerts.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func markAllAlertsRead() async throws {
        let _: SuccessResponse = try await performMutation(procedure: "alerts.markAllRead", input: EmptyInput())
    }

    func fetchSubjects() async throws -> [Subject] {
        let dtos: [EntityDTO] = try await performQuery(procedure: "entities.list")
        return dtos.map { $0.toModel() }
    }

    func fetchDashboard() async throws -> DashboardResponse {
        try await performQuery(procedure: "entities.dashboard")
    }

    func createSubject(name: String, type: SubjectType, creditLimit: Double, assignedPhone: String, assignedEmail: String, notes: String?) async throws -> Subject {
        let input = CreateEntityInput(
            name: name,
            type: type.rawValue,
            creditLimit: creditLimit,
            assignedPhone: assignedPhone,
            assignedEmail: assignedEmail,
            notes: notes
        )
        let dto: EntityDTO = try await performMutation(procedure: "entities.create", input: input)
        return dto.toModel()
    }

    func updateSubject(_ input: UpdateEntityInput) async throws -> Subject {
        let dto: EntityDTO = try await performMutation(procedure: "entities.update", input: input)
        return dto.toModel()
    }

    func archiveSubject(id: String) async throws -> Subject {
        let dto: EntityDTO = try await performMutation(procedure: "entities.archive", input: IDInput(id: id))
        return dto.toModel()
    }

    func toggleSubjectFlag(id: String) async throws -> Subject {
        let dto: EntityDTO = try await performMutation(procedure: "entities.toggleFlag", input: IDInput(id: id))
        return dto.toModel()
    }

    func fetchSubjectById(id: String) async throws -> Subject {
        let dto: EntityDTO = try await performQuery(procedure: "entities.getById", input: IDInput(id: id))
        return dto.toModel()
    }

    func fetchCommunications(entityId: String? = nil, type: CommType? = nil) async throws -> [Communication] {
        if entityId != nil || type != nil {
            let input = CommFilterInput(entityId: entityId, type: type?.rawValue)
            let dtos: [CommunicationDTO] = try await performQuery(procedure: "communications.list", input: input)
            return dtos.map { $0.toModel() }
        }
        let dtos: [CommunicationDTO] = try await performQuery(procedure: "communications.list")
        return dtos.map { $0.toModel() }
    }

    func createCommunication(entityId: String, entityName: String, type: CommType, sender: String, content: String, phoneNumber: String, duration: Double? = nil, transcription: String? = nil) async throws -> Communication {
        let input = CreateCommInput(
            entityId: entityId,
            entityName: entityName,
            type: type.rawValue,
            sender: sender,
            content: content,
            phoneNumber: phoneNumber,
            duration: duration,
            transcription: transcription
        )
        let dto: CommunicationDTO = try await performMutation(procedure: "communications.create", input: input)
        return dto.toModel()
    }

    func fetchEmails(entityId: String? = nil, category: String? = nil) async throws -> [EmailMessage] {
        if entityId != nil || category != nil {
            let input = EmailFilterInput(entityId: entityId, category: category)
            let dtos: [EmailDTO] = try await performQuery(procedure: "emails.list", input: input)
            return dtos.map { $0.toModel() }
        }
        let dtos: [EmailDTO] = try await performQuery(procedure: "emails.list")
        return dtos.map { $0.toModel() }
    }

    func syncMailbox() async throws -> SyncMailboxResponse {
        return try await performMutation(procedure: "emails.syncMailbox", input: EmptyInput())
    }

    func fetchAlerts(type: String? = nil) async throws -> [NexusAlert] {
        if let type {
            let input = AlertFilterInput(type: type)
            let dtos: [AlertDTO] = try await performQuery(procedure: "alerts.list", input: input)
            return dtos.map { $0.toModel() }
        }
        let dtos: [AlertDTO] = try await performQuery(procedure: "alerts.list")
        return dtos.map { $0.toModel() }
    }

    func checkHealth() async throws -> BackendHealthResponse {
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        let apiBase = baseURL.replacingOccurrences(of: "/api/trpc", with: "/api")
        guard let url = URL(string: apiBase) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Backend unreachable")
        }
        return try decoder.decode(BackendHealthResponse.self, from: data)
    }
}

nonisolated struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init(_ value: any Encodable & Sendable) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    init(_ value: any Encodable) {
        let box = value
        _encode = { encoder in
            try box.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
