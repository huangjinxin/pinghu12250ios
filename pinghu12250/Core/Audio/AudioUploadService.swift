//
//  AudioUploadService.swift
//  pinghu12250
//
//  音频上传服务 - 上传录音到服务器
//

import Foundation

// MARK: - 上传响应

struct AudioUploadResponse: Decodable {
    let url: String
}

// MARK: - 音频上传服务

class AudioUploadService {
    static let shared = AudioUploadService()

    private init() {}

    /// 上传音频文件
    func uploadAudio(fileURL: URL, progress: ((Double) -> Void)? = nil) async throws -> String {
        let serverURL = APIConfig.uploadURL

        // 读取文件数据
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        // 确定 MIME 类型
        let mimeType: String
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "m4a": mimeType = "audio/mp4"
        case "mp3": mimeType = "audio/mpeg"
        case "wav": mimeType = "audio/wav"
        case "aac": mimeType = "audio/aac"
        case "ogg": mimeType = "audio/ogg"
        default: mimeType = "audio/mpeg"
        }

        // 创建 multipart/form-data 请求
        let boundary = UUID().uuidString
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 添加认证 token
        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 构建请求体
        var body = Data()

        // 添加文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // 使用 URLSession 上传
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UploadError.serverError(statusCode: httpResponse.statusCode)
        }

        // 解析响应
        let uploadResponse = try JSONDecoder().decode(AudioUploadResponse.self, from: data)
        return uploadResponse.url
    }

    /// 批量上传音频文件
    func uploadAudios(fileURLs: [URL], progress: ((Int, Int) -> Void)? = nil) async throws -> [String] {
        var uploadedURLs: [String] = []

        for (index, fileURL) in fileURLs.enumerated() {
            progress?(index + 1, fileURLs.count)

            let url = try await uploadAudio(fileURL: fileURL)
            uploadedURLs.append(url)
        }

        return uploadedURLs
    }
}

// MARK: - 上传错误

enum UploadError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .serverError(let statusCode):
            return "服务器错误 (\(statusCode))"
        case .fileNotFound:
            return "文件未找到"
        }
    }
}

// MARK: - API 配置扩展

extension APIConfig {
    static var uploadURL: URL {
        return URL(string: baseURL + Endpoints.upload)!
    }
}
