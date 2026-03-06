import Foundation

nonisolated struct TRPCResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let result: TRPCResult<T>
}

nonisolated struct TRPCResult<T: Decodable & Sendable>: Decodable, Sendable {
    let data: TRPCData<T>
}

nonisolated struct TRPCData<T: Decodable & Sendable>: Decodable, Sendable {
    let json: T
}

nonisolated struct DashboardResponse: Codable, Sendable {
    let totalFirepower: Double
    let monthlyBurn: Double
    let activeCount: Int
    let totalCount: Int
    let urgentCount: Int
    let unreadComms: Int
    let unreadEmails: Int
}

nonisolated struct SuccessResponse: Codable, Sendable {
    let success: Bool
}

nonisolated enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case serverError(Int, String)
    case notConfigured

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL: "Unable to connect to server"
        case .serverError(let code, _): "Server error (\(code))"
        case .notConfigured: "API not configured"
        }
    }
}

nonisolated struct SuperJSONInput<T: Encodable & Sendable>: Encodable, Sendable {
    let json: T
}

nonisolated struct IDInput: Codable, Sendable {
    let id: String
}

nonisolated struct EmptyInput: Codable, Sendable {}

nonisolated struct CommFilterInput: Codable, Sendable {
    let entityId: String?
}

nonisolated struct EmailFilterInput: Codable, Sendable {
    let entityId: String?
}

nonisolated struct CreateEntityInput: Codable, Sendable {
    let name: String
    let type: String
    let creditLimit: Double
    let assignedPhone: String
    let assignedEmail: String
    let notes: String?
}

nonisolated struct UpdateEntityInput: Codable, Sendable {
    let id: String
    let name: String?
    let type: String?
    let status: String?
    let healthScore: Int?
    let creditLimit: Double?
    let utilisationPercent: Double?
    let monthlyBurn: Double?
    let assignedPhone: String?
    let assignedEmail: String?
    let clearScore: Int?
    let isFlagged: Bool?
    let notes: String?
}

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

    private func performQuery<T: Decodable & Sendable>(procedure: String, input: (any Encodable)? = nil) async throws -> T {
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

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(httpResponse.statusCode, body)
        }

        let trpcResponse = try decoder.decode(TRPCResponse<T>.self, from: data)
        return trpcResponse.result.data.json
    }

    private func performMutation<T: Decodable & Sendable>(procedure: String, input: any Encodable) async throws -> T {
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

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(httpResponse.statusCode, body)
        }

        let trpcResponse = try decoder.decode(TRPCResponse<T>.self, from: data)
        return trpcResponse.result.data.json
    }

    func fetchEntities() async throws -> [NexusEntity] {
        let dtos: [EntityDTO] = try await performQuery(procedure: "entities.list")
        return dtos.map { $0.toModel() }
    }

    func fetchDashboard() async throws -> DashboardResponse {
        try await performQuery(procedure: "entities.dashboard")
    }

    func createEntity(_ input: CreateEntityInput) async throws -> NexusEntity {
        let dto: EntityDTO = try await performMutation(procedure: "entities.create", input: input)
        return dto.toModel()
    }

    func updateEntity(_ input: UpdateEntityInput) async throws -> NexusEntity {
        let dto: EntityDTO = try await performMutation(procedure: "entities.update", input: input)
        return dto.toModel()
    }

    func archiveEntity(id: String) async throws -> NexusEntity {
        let dto: EntityDTO = try await performMutation(procedure: "entities.archive", input: IDInput(id: id))
        return dto.toModel()
    }

    func toggleEntityFlag(id: String) async throws -> NexusEntity {
        let dto: EntityDTO = try await performMutation(procedure: "entities.toggleFlag", input: IDInput(id: id))
        return dto.toModel()
    }

    func fetchCommunications(entityId: String? = nil) async throws -> [Communication] {
        let dtos: [CommunicationDTO]
        if let entityId {
            dtos = try await performQuery(procedure: "communications.list", input: CommFilterInput(entityId: entityId))
        } else {
            dtos = try await performQuery(procedure: "communications.list")
        }
        return dtos.map { $0.toModel() }
    }

    func markCommRead(id: String) async throws -> Communication {
        let dto: CommunicationDTO = try await performMutation(procedure: "communications.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func fetchEmails(entityId: String? = nil) async throws -> [EmailMessage] {
        let dtos: [EmailDTO]
        if let entityId {
            dtos = try await performQuery(procedure: "emails.list", input: EmailFilterInput(entityId: entityId))
        } else {
            dtos = try await performQuery(procedure: "emails.list")
        }
        return dtos.map { $0.toModel() }
    }

    func markEmailRead(id: String) async throws -> EmailMessage {
        let dto: EmailDTO = try await performMutation(procedure: "emails.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func toggleEmailFlag(id: String) async throws -> EmailMessage {
        let dto: EmailDTO = try await performMutation(procedure: "emails.toggleFlag", input: IDInput(id: id))
        return dto.toModel()
    }

    func fetchAlerts() async throws -> [NexusAlert] {
        let dtos: [AlertDTO] = try await performQuery(procedure: "alerts.list")
        return dtos.map { $0.toModel() }
    }

    func markAlertRead(id: String) async throws -> NexusAlert {
        let dto: AlertDTO = try await performMutation(procedure: "alerts.markRead", input: IDInput(id: id))
        return dto.toModel()
    }

    func markAllAlertsRead() async throws {
        let _: SuccessResponse = try await performMutation(procedure: "alerts.markAllRead", input: EmptyInput())
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
