//
//  APIService.swift
//  pinghu12250
//
//  网络请求服务 - 统一处理 API 调用
//

import Foundation
import Combine

/// API 错误类型
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .noData:
            return "服务器未返回数据"
        case .decodingError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "服务器错误(\(code)): \(message)"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .unknown:
            return "未知错误"
        }
    }
}

/// API 响应包装
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: String?
    let message: String?
}

/// 网络请求服务
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()

    private let session: URLSession
    private let longTimeoutSession: URLSession  // 用于AI分析等长时间请求
    @Published var isLoading = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData  // 禁用缓存，确保获取最新数据
        config.urlCache = nil  // 不使用 URL 缓存
        self.session = URLSession(configuration: config)

        // 长超时 session 用于 AI 分析
        let longConfig = URLSessionConfiguration.default
        longConfig.timeoutIntervalForRequest = APIConfig.aiAnalysisTimeout
        longConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        longConfig.urlCache = nil
        self.longTimeoutSession = URLSession(configuration: longConfig)
    }

    // MARK: - Token 管理

    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    var isAuthenticated: Bool {
        authToken != nil
    }

    func clearToken() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }

    // MARK: - 通用请求方法

    /// GET 请求
    func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        return try await request(endpoint, method: "GET", queryItems: queryItems)
    }

    /// POST 请求
    func post<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        return try await request(endpoint, method: "POST", body: body)
    }

    /// POST 请求（无请求体）
    func post<T: Decodable>(_ endpoint: String) async throws -> T {
        return try await request(endpoint, method: "POST")
    }

    /// POST 请求（长超时，用于AI分析等）
    func postWithLongTimeout<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        return try await request(endpoint, method: "POST", body: body, useLongTimeout: true)
    }

    /// PUT 请求
    func put<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        return try await request(endpoint, method: "PUT", body: body)
    }

    /// DELETE 请求
    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        return try await request(endpoint, method: "DELETE")
    }

    /// DELETE 请求（带请求体）
    func delete<T: Decodable, B: Encodable>(_ endpoint: String, body: B) async throws -> T {
        return try await request(endpoint, method: "DELETE", body: body)
    }

    // MARK: - 核心请求实现

    private func request<T: Decodable>(
        _ endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        useLongTimeout: Bool = false
    ) async throws -> T {
        // 构建 URL
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        // ⚠️ 重要：只有当 queryItems 不为空时才设置
        // 否则会清空 URL 字符串中已有的 query 参数
        if let queryItems = queryItems, !queryItems.isEmpty {
            // 合并已有的 query items 和新传入的 query items
            var existingItems = components.queryItems ?? []
            existingItems.append(contentsOf: queryItems)
            components.queryItems = existingItems
        }
        // 如果 queryItems 为 nil 或空，保留 URL 字符串中原有的 query

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        #if DEBUG
        print("🌐 API Request: \(method) \(url.absoluteString)")
        #endif

        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加认证头
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 添加请求体
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        // 发送请求（选择合适的 session）
        isLoading = true
        defer { isLoading = false }

        let activeSession = useLongTimeout ? longTimeoutSession : session

        do {
            let (data, response) = try await activeSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }

            // 检查 401 未授权
            if httpResponse.statusCode == 401 {
                clearToken()
                throw APIError.unauthorized
            }

            // 检查其他错误状态码
            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
                throw APIError.serverError(httpResponse.statusCode, "请求失败")
            }

            // 解析响应
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - 文件下载

    /// 下载文件
    func downloadFile(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "下载失败")
        }

        return data
    }

    // MARK: - 文件上传

    /// 上传图片
    func uploadImage(_ imageData: Data, filename: String = "image.jpg") async throws -> UploadResponse {
        return try await uploadFile(imageData, filename: filename, mimeType: "image/jpeg", fieldName: "file")
    }

    /// 上传音频
    func uploadAudio(_ audioData: Data, filename: String) async throws -> UploadResponse {
        let mimeType: String
        if filename.hasSuffix(".mp3") {
            mimeType = "audio/mpeg"
        } else if filename.hasSuffix(".m4a") {
            mimeType = "audio/mp4"
        } else if filename.hasSuffix(".wav") {
            mimeType = "audio/wav"
        } else {
            mimeType = "audio/mpeg"
        }
        return try await uploadFile(audioData, filename: filename, mimeType: mimeType, fieldName: "file")
    }

    /// 通用文件上传方法
    private func uploadFile(_ fileData: Data, filename: String, mimeType: String, fieldName: String) async throws -> UploadResponse {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.upload) else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // 添加文件字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }

            if httpResponse.statusCode == 401 {
                clearToken()
                throw APIError.unauthorized
            }

            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
                throw APIError.serverError(httpResponse.statusCode, "上传失败")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(UploadResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}
