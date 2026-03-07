import Foundation
import SwiftUI

@Observable
@MainActor
class AuthViewModel {
    var isAuthenticated: Bool = false
    var currentUser: AuthUser?
    var isLoading: Bool = false
    var errorMessage: String?

    private let authService = AuthService.shared
    private let tokenKey = "auth_token"
    private let userKey = "auth_user"
    private let tokenExpiryKey = "auth_token_expiry"

    var authToken: String? {
        KeychainService.load(key: tokenKey)
    }

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        guard let token = KeychainService.load(key: tokenKey) else { return }

        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }

        if isTokenExpired {
            handleExpiredToken()
            return
        }

        Task {
            await validateToken(token)
        }
    }

    private var isTokenExpired: Bool {
        guard let token = KeychainService.load(key: tokenKey) else { return true }
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let bodyData = Data(base64Encoded: padBase64(String(parts[1]))),
              let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let exp = body["exp"] as? TimeInterval else {
            return false
        }
        return Date().timeIntervalSince1970 >= exp
    }

    private var tokenExpiresWithinHours: Bool {
        guard let token = KeychainService.load(key: tokenKey) else { return true }
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let bodyData = Data(base64Encoded: padBase64(String(parts[1]))),
              let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let exp = body["exp"] as? TimeInterval else {
            return false
        }
        let hoursRemaining = (exp - Date().timeIntervalSince1970) / 3600
        return hoursRemaining < 12
    }

    private func padBase64(_ string: String) -> String {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return s
    }

    private func handleExpiredToken() {
        KeychainService.delete(key: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        currentUser = nil
        isAuthenticated = false
        errorMessage = "Session expired. Please sign in again."
    }

    private func validateToken(_ token: String) async {
        guard authService.isConfigured else {
            if currentUser != nil { isAuthenticated = true }
            return
        }
        do {
            let user = try await authService.fetchMe(token: token)
            currentUser = user
            isAuthenticated = true
            cacheUser(user)

            if tokenExpiresWithinHours {
                await refreshSession()
            }
        } catch let error as APIError {
            if case .serverError(let code, _) = error, code == 401 {
                handleExpiredToken()
            }
        } catch {
            if currentUser != nil { isAuthenticated = true }
        }
    }

    private func refreshSession() async {
        guard authService.isConfigured else { return }
        guard let token = KeychainService.load(key: tokenKey) else { return }
        do {
            let refreshedUser = try await authService.fetchMe(token: token)
            currentUser = refreshedUser
            cacheUser(refreshedUser)
        } catch {
            // keep current session if refresh fails
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await authService.login(email: email, password: password)
            KeychainService.save(key: tokenKey, value: response.token)
            currentUser = response.user
            cacheUser(response.user)
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                errorMessage = "Server is taking too long. Please try again."
            case .notConnectedToInternet:
                errorMessage = "No internet connection."
            case .cannotConnectToHost, .cannotFindHost:
                errorMessage = "Cannot reach the server. Please try again later."
            default:
                errorMessage = "Connection error. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await authService.register(email: email, password: password, name: name)
            KeychainService.save(key: tokenKey, value: response.token)
            currentUser = response.user
            cacheUser(response.user)
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                errorMessage = "Server is taking too long. Please try again."
            case .notConnectedToInternet:
                errorMessage = "No internet connection."
            case .cannotConnectToHost, .cannotFindHost:
                errorMessage = "Cannot reach the server. Please try again later."
            default:
                errorMessage = "Connection error. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loginDemo() {
        let demoUser = AuthUser(id: "demo-user", email: "demo@nexus.local", name: "Demo User")
        currentUser = demoUser
        cacheUser(demoUser)
        KeychainService.save(key: tokenKey, value: "demo-token")
        isAuthenticated = true
    }

    func logout() {
        KeychainService.delete(key: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        currentUser = nil
        isAuthenticated = false
    }

    private func cacheUser(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}
