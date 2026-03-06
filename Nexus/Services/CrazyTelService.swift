import Foundation

@MainActor
class CrazyTelService {
    static let shared = CrazyTelService()

    private let baseURL = "https://www.crazytel.io/api/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    private func request<T: Decodable & Sendable>(
        method: String = "GET",
        path: String,
        apiKey: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard !apiKey.isEmpty else { throw CTError.notConfigured }
        guard let url = URL(string: "\(baseURL)\(path)") else { throw CTError.invalidResponse }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "accept")
        req.setValue(apiKey, forHTTPHeaderField: "x-crazytel-api-key")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: req)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299: break
            case 401: throw CTError.unauthorized
            case 429: throw CTError.rateLimited
            default:
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw CTError.serverError(http.statusCode, msg)
            }
        }

        return try decoder.decode(T.self, from: data)
    }

    func fetchBalance(apiKey: String) async throws -> CTBalanceResponse {
        try await request(path: "/balance/", apiKey: apiKey)
    }

    func fetchOwnedDIDs(apiKey: String) async throws -> [CTDIDNumber] {
        do {
            let response: CTDIDListResponse = try await request(path: "/phone-numbers/", apiKey: apiKey)
            return response.numbers
        } catch {
            let array: [CTDIDNumber] = try await request(path: "/phone-numbers/", apiKey: apiKey)
            return array
        }
    }

    func fetchAvailableNumbers(apiKey: String) async throws -> [CTAvailableNumber] {
        let response: CTAvailableNumbersResponse = try await request(path: "/phone-numbers/available-numbers/", apiKey: apiKey)
        return response.numbers
    }

    func fetchAddresses(apiKey: String) async throws -> [CTAddress] {
        let response: CTAddressResponse = try await request(path: "/phone-numbers/addresses/", apiKey: apiKey)
        return response.items
    }

    func fetchOwners(apiKey: String) async throws -> [CTOwner] {
        let response: CTOwnerResponse = try await request(path: "/phone-numbers/owners/", apiKey: apiKey)
        return response.items
    }

    func purchaseDID(apiKey: String, request purchaseReq: CTPurchaseRequest) async throws -> CTPurchaseResponse {
        try await request(method: "POST", path: "/phone-numbers/purchase", apiKey: apiKey, body: purchaseReq)
    }

    func testConnection(apiKey: String) async throws -> Bool {
        let _: CTBalanceResponse = try await request(path: "/balance/", apiKey: apiKey)
        return true
    }
}
