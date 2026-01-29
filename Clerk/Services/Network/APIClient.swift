import Foundation
import Combine

/// Main API client for communicating with the Clerk backend
final class APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        #if DEBUG
        self.baseURL = URL(string: "http://localhost:3000/api")!
        #else
        self.baseURL = URL(string: "https://api.clerk.legal")!
        #endif
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        loadAuthToken()
    }
    
    // MARK: - Auth Token Management
    
    private func loadAuthToken() {
        authToken = KeychainManager.shared.get(key: "authToken")
    }
    
    func setAuthToken(_ token: String) {
        authToken = token
        KeychainManager.shared.save(key: "authToken", value: token)
    }
    
    func clearAuthToken() {
        authToken = nil
        KeychainManager.shared.delete(key: "authToken")
    }
    
    // MARK: - Request Building
    
    private func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return request
    }
    
    // MARK: - Request Execution
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
            
        case 401:
            clearAuthToken()
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        case 429:
            throw APIError.rateLimited
            
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
            
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Streaming Request
    
    func streamRequest(
        endpoint: String,
        method: HTTPMethod = .post,
        body: Encodable? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let maxRetries = 2
                var attempt = 0
                var backoff: UInt64 = 500_000_000 // 0.5s
 
                while attempt <= maxRetries {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
 
                    do {
                        var request = try buildRequest(endpoint: endpoint, method: method, body: body)
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
 
                        let (bytes, response) = try await session.bytes(for: request)
 
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw APIError.invalidResponse
                        }
 
                        guard (200...299).contains(httpResponse.statusCode) else {
                            throw APIError.httpError(httpResponse.statusCode)
                        }
 
                        var buffer = Data()
                        buffer.reserveCapacity(8 * 1024)
 
                        for try await byte in bytes {
                            if Task.isCancelled {
                                continuation.finish()
                                return
                            }
 
                            buffer.append(byte)
 
                            // SSE events are delimited by a blank line (\n\n).
                            while let range = buffer.range(of: Data([0x0A, 0x0A])) {
                                let eventData = buffer.subdata(in: 0..<range.lowerBound)
                                buffer.removeSubrange(0..<range.upperBound)
 
                                if let eventString = String(data: eventData, encoding: .utf8) {
                                    let payload = Self.parseSSEData(from: eventString)
                                    if payload == "[DONE]" {
                                        continuation.finish()
                                        return
                                    }
                                    if !payload.isEmpty {
                                        continuation.yield(payload)
                                    }
                                }
                            }
                        }
 
                        continuation.finish()
                        return
                    } catch {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
 
                        if attempt < maxRetries {
                            attempt += 1
                            try? await Task.sleep(nanoseconds: backoff)
                            backoff = min(backoff * 2, 4_000_000_000) // cap at 4s
                            continue
                        }
 
                        continuation.finish(throwing: error)
                        return
                    }
                }
            }
        }
    }
}

// MARK: - SSE Parsing

private extension APIClient {
    static func parseSSEData(from event: String) -> String {
        // Supports multi-line data fields:
        // data: chunk1
        // data: chunk2
        //
        // -> yields "chunk1\nchunk2"
        let normalized = event.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
 
        var dataLines: [String] = []
        for line in lines {
            if line.hasPrefix("data:") {
                let value = line.dropFirst(5)
                let trimmed = value.hasPrefix(" ") ? value.dropFirst() : value
                dataLines.append(String(trimmed))
            }
        }
 
        return dataLines.joined(separator: "\n")
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (\(code))"
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
