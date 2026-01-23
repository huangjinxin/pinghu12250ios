//
//  WritingService.swift
//  pinghu12250
//
//  书写功能API服务
//

import Foundation
import UIKit

@MainActor
class WritingService {
    static let shared = WritingService()
    private let api = APIService.shared

    private init() {}

    // MARK: - 字体管理

    /// 获取字体列表
    func getFonts() async throws -> [UserFont] {
        let response: FontListResponse = try await api.get(APIConfig.Endpoints.fonts)
        guard response.success, let data = response.data else {
            throw APIError.serverError(0, response.error ?? "获取字体失败")
        }
        return data
    }

    /// 上传字体
    func uploadFont(data: Data, filename: String, name: String) async throws -> UserFont {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.fonts) else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = api.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        // 字体文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: font/ttf\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        // 字体名称
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(FontResponse.self, from: responseData)

        guard response.success, let font = response.data else {
            throw APIError.serverError(0, response.error ?? "上传字体失败")
        }
        return font
    }

    /// 设置默认字体
    func setDefaultFont(id: String) async throws {
        let _: FontResponse = try await api.put("\(APIConfig.Endpoints.fontDefault)/\(id)/default", body: EmptyBody())
    }

    /// 删除字体
    func deleteFont(id: String) async throws {
        let _: FontResponse = try await api.delete("\(APIConfig.Endpoints.fontDetail)/\(id)")
    }

    // MARK: - 书写作品

    /// 获取全部作品（公开）
    func getWorks(page: Int = 1, pageSize: Int = 20, sort: String = "latest") async throws -> (items: [CalligraphyWork], total: Int, totalPages: Int) {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "sort", value: sort)
        ]
        let response: CalligraphyListResponse = try await api.get(APIConfig.Endpoints.calligraphy, queryItems: queryItems)
        guard response.success, let data = response.data else {
            throw APIError.serverError(0, response.error ?? "获取作品失败")
        }
        return (data.works, data.total, data.totalPages)
    }

    /// 获取我的作品
    func getMyWorks(page: Int = 1, pageSize: Int = 20) async throws -> (items: [CalligraphyWork], total: Int) {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(pageSize)")
        ]
        let response: CalligraphyListResponse = try await api.get(APIConfig.Endpoints.calligraphyMy, queryItems: queryItems)
        guard response.success, let data = response.data else {
            throw APIError.serverError(0, response.error ?? "获取作品失败")
        }
        return (data.works, data.total)
    }

    /// 获取作品详情
    func getWork(id: String) async throws -> CalligraphyWork {
        let response: CalligraphyResponse = try await api.get("\(APIConfig.Endpoints.calligraphyDetail)/\(id)")
        guard response.success, let work = response.data else {
            throw APIError.serverError(0, response.error ?? "获取作品详情失败")
        }
        return work
    }

    /// 创建作品
    func createWork(content: String, fontId: String?, imagePath: String?, strokeData: String?) async throws -> CalligraphyWork {
        let body = CreateCalligraphyRequest(content: content, fontId: fontId, imagePath: imagePath, strokeData: strokeData)
        let response: CalligraphyResponse = try await api.post(APIConfig.Endpoints.calligraphy, body: body)
        guard response.success, let work = response.data else {
            throw APIError.serverError(0, response.error ?? "创建作品失败")
        }
        return work
    }

    /// 删除作品
    func deleteWork(id: String) async throws {
        let _: CalligraphyResponse = try await api.delete("\(APIConfig.Endpoints.calligraphyDetail)/\(id)")
    }

    /// 点赞/取消点赞
    func toggleLike(id: String) async throws -> (liked: Bool, count: Int) {
        let response: LikeResponse = try await api.post("\(APIConfig.Endpoints.calligraphyLike)/\(id)/like")
        guard response.success, let data = response.data else {
            throw APIError.serverError(0, response.error ?? "操作失败")
        }
        return (data.liked, data.likeCount)
    }
}

// MARK: - 辅助类型

private struct EmptyBody: Encodable {}
