import Foundation

nonisolated struct CTBalanceResponse: Codable, Sendable {
    let account_code: String
    let balance: Double
}

nonisolated struct CTDIDNumber: Codable, Sendable, Identifiable {
    let did_number: String
    let description: String?
    let primary_route: String?
    let primary_destination: String?
    let status: String?

    var id: String { did_number }

    var formattedNumber: String {
        let cleaned = did_number.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if cleaned.hasPrefix("61") && cleaned.count >= 11 {
            let idx4 = cleaned.index(cleaned.startIndex, offsetBy: 4)
            let idx7 = cleaned.index(cleaned.startIndex, offsetBy: 7)
            return "+\(cleaned[cleaned.startIndex..<idx4]) \(cleaned[idx4..<idx7]) \(cleaned[idx7...])"
        }
        return did_number
    }
}

nonisolated struct CTAvailableNumbersResponse: Codable, Sendable {
    let available_numbers: [CTAvailableNumber]?
    let results: [CTAvailableNumber]?

    var numbers: [CTAvailableNumber] {
        available_numbers ?? results ?? []
    }
}

nonisolated struct CTAvailableNumber: Codable, Sendable, Identifiable {
    let did_number: String
    let monthly_cost: Double?
    let setup_cost: Double?
    let area_code: String?
    let city: String?
    let state: String?

    var id: String { did_number }
}

nonisolated struct CTDIDListResponse: Codable, Sendable {
    let results: [CTDIDNumber]?
    let dids: [CTDIDNumber]?

    var numbers: [CTDIDNumber] {
        results ?? dids ?? []
    }
}

nonisolated struct CTAddressResponse: Codable, Sendable {
    let addresses: [CTAddress]?
    let results: [CTAddress]?

    var items: [CTAddress] {
        addresses ?? results ?? []
    }
}

nonisolated struct CTAddress: Codable, Sendable, Identifiable {
    let id: String
    let address: String?
    let street: String?
    let city: String?
    let state: String?

    var displayName: String {
        if let address { return address }
        return [street, city, state].compactMap { $0 }.joined(separator: ", ")
    }
}

nonisolated struct CTPurchaseRequest: Codable, Sendable {
    let did_number: String
    let address_id: String
    let person_id: String
    let primary_route: String
    let primary_destination: String
    let description: String
}

nonisolated struct CTPurchaseResponse: Codable, Sendable {
    let message: String?
}

nonisolated struct CTOwnerResponse: Codable, Sendable {
    let owners: [CTOwner]?
    let results: [CTOwner]?

    var items: [CTOwner] {
        owners ?? results ?? []
    }
}

nonisolated struct CTOwner: Codable, Sendable, Identifiable {
    let id: String
    let name: String?
    let first_name: String?
    let last_name: String?

    var displayName: String {
        if let name { return name }
        return [first_name, last_name].compactMap { $0 }.joined(separator: " ")
    }
}

nonisolated enum CTConnectionStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

nonisolated enum CTError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(Int, String)

    nonisolated var errorDescription: String? {
        switch self {
        case .notConfigured: "CrazyTel API key not configured"
        case .invalidResponse: "Invalid response from CrazyTel"
        case .unauthorized: "Invalid API key"
        case .rateLimited: "Rate limit exceeded. Try again shortly."
        case .serverError(let code, let msg): "CrazyTel error \(code): \(msg)"
        }
    }
}
