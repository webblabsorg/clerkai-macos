import Foundation
import Combine
import AuthenticationServices

/// Service for handling authentication
final class AuthService: NSObject {
    static let shared = AuthService()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    
    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() {
        guard keychain.exists(key: "authToken") else {
            isAuthenticated = false
            currentUser = nil
            return
        }
        
        Task {
            do {
                let user: User = try await apiClient.request(endpoint: "auth/me")
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    AppState.shared.currentUser = user
                    AppState.shared.isAuthenticated = true
                    AppState.shared.subscriptionTier = user.subscriptionTier
                }
            } catch {
                await MainActor.run {
                    self.signOut()
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> User {
        let request = SignInRequest(email: email, password: password)
        let response: AuthResponse = try await apiClient.request(
            endpoint: "auth/login",
            method: .post,
            body: request
        )
        
        apiClient.setAuthToken(response.token)
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
            AppState.shared.currentUser = response.user
            AppState.shared.isAuthenticated = true
            AppState.shared.subscriptionTier = response.user.subscriptionTier
        }
        
        return response.user
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, name: String?) async throws -> User {
        let request = SignUpRequest(email: email, password: password, name: name)
        let response: AuthResponse = try await apiClient.request(
            endpoint: "auth/register",
            method: .post,
            body: request
        )
        
        apiClient.setAuthToken(response.token)
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
            AppState.shared.currentUser = response.user
            AppState.shared.isAuthenticated = true
        }
        
        return response.user
    }
    
    // MARK: - OAuth
    
    func signInWithGoogle() async throws -> User {
        // TODO: Implement Google OAuth
        throw AuthError.notImplemented
    }
    
    func signInWithMicrosoft() async throws -> User {
        // TODO: Implement Microsoft OAuth
        throw AuthError.notImplemented
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        apiClient.clearAuthToken()
        currentUser = nil
        isAuthenticated = false
        AppState.shared.currentUser = nil
        AppState.shared.isAuthenticated = false
        AppState.shared.subscriptionTier = .free
    }
    
    // MARK: - Password Reset
    
    func requestPasswordReset(email: String) async throws {
        let request = PasswordResetRequest(email: email)
        let _: EmptyResponse = try await apiClient.request(
            endpoint: "auth/forgot-password",
            method: .post,
            body: request
        )
    }
    
    // MARK: - Refresh Token
    
    func refreshToken() async throws {
        let response: TokenRefreshResponse = try await apiClient.request(
            endpoint: "auth/refresh",
            method: .post
        )
        
        apiClient.setAuthToken(response.token)
    }
}

// MARK: - Request/Response Models

struct SignInRequest: Encodable {
    let email: String
    let password: String
}

struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let name: String?
}

struct PasswordResetRequest: Encodable {
    let email: String
}

struct AuthResponse: Decodable {
    let user: User
    let token: String
}

struct TokenRefreshResponse: Decodable {
    let token: String
}

struct EmptyResponse: Decodable {}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case invalidEmail
    case weakPassword
    case notImplemented
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .notImplemented:
            return "This feature is not yet available"
        case .networkError:
            return "Network error. Please try again."
        }
    }
}
