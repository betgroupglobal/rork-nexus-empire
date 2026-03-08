import Foundation

@MainActor
class CrazyTelService {
    static let shared = CrazyTelService()

    private init() {}

    func fetchBalance(apiKey: String) async throws -> CTBalanceResponse {
        struct Input: Encodable { let apiKey: String }
        return try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchBalance", input: Input(apiKey: apiKey))
    }

    func fetchOwnedDIDs(apiKey: String) async throws -> [CTDIDNumber] {
        struct Input: Encodable { let apiKey: String }
        do {
            let response: CTDIDListResponse = try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchOwnedDIDs", input: Input(apiKey: apiKey))
            return response.numbers
        } catch {
            let array: [CTDIDNumber] = try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchOwnedDIDs", input: Input(apiKey: apiKey))
            return array
        }
    }

    func fetchAvailableNumbers(apiKey: String) async throws -> [CTAvailableNumber] {
        struct Input: Encodable { let apiKey: String }
        let response: CTAvailableNumbersResponse = try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchAvailableNumbers", input: Input(apiKey: apiKey))
        return response.numbers
    }

    func fetchAddresses(apiKey: String) async throws -> [CTAddress] {
        struct Input: Encodable { let apiKey: String }
        let response: CTAddressResponse = try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchAddresses", input: Input(apiKey: apiKey))
        return response.items
    }

    func fetchOwners(apiKey: String) async throws -> [CTOwner] {
        struct Input: Encodable { let apiKey: String }
        let response: CTOwnerResponse = try await NexusAPIService.shared.performQuery(procedure: "crazytel.fetchOwners", input: Input(apiKey: apiKey))
        return response.items
    }

    func purchaseDID(apiKey: String, request purchaseReq: CTPurchaseRequest) async throws -> CTPurchaseResponse {
        struct Input: Encodable {
            let apiKey: String
            let number: String
            let addressId: String
            let ownerId: String
        }
        let input = Input(apiKey: apiKey, number: purchaseReq.did_number, addressId: purchaseReq.address_id, ownerId: purchaseReq.person_id)
        return try await NexusAPIService.shared.performMutation(procedure: "crazytel.purchaseDID", input: input)
    }

    func testConnection(apiKey: String) async throws -> Bool {
        struct Input: Encodable { let apiKey: String }
        let res: CTSimpleResponse = try await NexusAPIService.shared.performMutation(procedure: "crazytel.testConnection", input: Input(apiKey: apiKey))
        return res.success
    }

    func sendSMS(apiKey: String, from: String, to: String, message: String) async throws -> CTSMSSendResponse {
        struct Input: Encodable {
            let apiKey: String
            let from: String
            let to: String
            let message: String
        }
        return try await NexusAPIService.shared.performMutation(procedure: "crazytel.sendSMS", input: Input(apiKey: apiKey, from: from, to: to, message: message))
    }
}

nonisolated struct CTSimpleResponse: Codable, Sendable {
    let success: Bool
}
