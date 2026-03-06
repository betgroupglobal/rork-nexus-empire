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
        Task {
            await validateToken(token)
        }
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
        } catch {
            // keep session if offline
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
