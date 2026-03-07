import Foundation

nonisolated struct AuthResponse: Codable, Sendable {
    let token: String
    let user: AuthUser
}

nonisolated struct AuthUser: Codable, Sendable {
    let id: String
    let email: String
    let name: String
}

nonisolated struct LoginInput: Codable, Sendable {
    let email: String
    let password: String
}

nonisolated struct RegisterInput: Codable, Sendable {
    let email: String
    let password: String
    let name: String
}

@MainActor
class AuthService {
    static let shared = AuthService()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let configURL = Config.EXPO_PUBLIC_RORK_API_BASE_URL
        baseURL = configURL.isEmpty ? "" : configURL + "/api/trpc"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    var isConfigured: Bool { !baseURL.isEmpty }

    func login(email: String, password: String) async throws -> AuthResponse {
        guard isConfigured else { throw APIError.notConfigured }
        let input = LoginInput(email: email, password: password)
        return try await performMutationWithRetry(procedure: "auth.login", input: input)
    }

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        guard isConfigured else { throw APIError.notConfigured }
        let input = RegisterInput(email: email, password: password, name: name)
        return try await performMutationWithRetry(procedure: "auth.register", input: input)
    }

    func fetchMe(token: String) async throws -> AuthUser {
        guard isConfigured else { throw APIError.notConfigured }
        guard let url = URL(string: "\(baseURL)/auth.me") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try checkHTTPError(data: data, response: response)
        let trpc = try decoder.decode(TRPCResponse<AuthUser>.self, from: data)
        return trpc.result.data.json
    }

    private func performMutationWithRetry<T: Decodable & Sendable>(procedure: String, input: any Encodable, retries: Int = 2) async throws -> T {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                let result: T = try await performMutation(procedure: procedure, input: input)
                return result
            } catch let error as URLError where (error.code == .timedOut || error.code == .networkConnectionLost) && attempt < retries {
                lastError = error
                try? await Task.sleep(for: .seconds(Double(attempt + 1)))
                continue
            } catch {
                throw error
            }
        }
        throw lastError ?? APIError.serverError(0, "Request failed after retries")
    }

    private func performMutation<T: Decodable & Sendable>(procedure: String, input: any Encodable) async throws -> T {
        guard !baseURL.isEmpty else { throw APIError.notConfigured }
        guard let url = URL(string: "\(baseURL)/\(procedure)") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(SuperJSONInput(json: AnyEncodable(input)))

        let (data, response) = try await session.data(for: request)
        try checkHTTPError(data: data, response: response)

        do {
            let trpc = try decoder.decode(TRPCResponse<T>.self, from: data)
            return trpc.result.data.json
        } catch {
            throw APIError.serverError(0, "Server returned an unexpected response. Please try again.")
        }
    }

    private func checkHTTPError(data: Data, response: URLResponse) throws {
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
}
