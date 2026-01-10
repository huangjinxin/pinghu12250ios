//
//  AIStudyService.swift
//  pinghu12250
//
//  AI 学习服务 - 流式对话 API 调用
//  优化：使用 URLSession bytes 真正流式处理，避免主线程阻塞
//

import Foundation
import UIKit

// MARK: - AI 学习服务

class AIStudyService {
    static let shared = AIStudyService()

    private init() {}

    // 当前任务（用于取消）
    private var currentTask: Task<Void, Never>?
    private var currentURLTask: URLSessionDataTask?

    // MARK: - 流式对话（优化版）

    /// 生成会话ID（每个教材+用户组合一个）
    private func generateSessionId(textbookId: String) -> String {
        // 简单的会话ID：使用 textbookId + 当天日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        return "\(textbookId)-\(dateStr)"
    }

    /// 使用 AsyncSequence 的真正流式对话
    func streamChatAsync(
        textbookId: String,
        message: String,
        image: UIImage? = nil,
        page: Int? = nil,
        subject: String = "CHINESE"
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            // 创建任务
            let task = Task {
                do {
                    // 使用流式端点
                    guard let streamURL = URL(string: APIConfig.baseURL + APIConfig.Endpoints.aiChatStream) else {
                        throw AIServiceError.invalidResponse
                    }

                    // 构建请求
                    var request = URLRequest(url: streamURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 120 // AI 响应可能较慢

                    // 添加认证
                    if let token = await MainActor.run(body: { APIService.shared.authToken }) {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    // 生成 sessionId
                    let sessionId = self.generateSessionId(textbookId: textbookId)

                    // 构建请求体（添加 sessionId）
                    var body: [String: Any] = [
                        "textbookId": textbookId,
                        "sessionId": sessionId,
                        "message": message,
                        "subject": subject
                    ]

                    if let page = page {
                        body["context"] = "当前阅读第\(page)页"
                    }

                    // 如果有图片，转为 base64（压缩处理）
                    if let image = image {
                        let compressedImage = Self.compressImage(image, maxWidth: 1024)
                        if let imageData = compressedImage.jpegData(compressionQuality: 0.7) {
                            let base64String = imageData.base64EncodedString()
                            body["imageBase64"] = "data:image/jpeg;base64,\(base64String)"
                        }
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    #if DEBUG
                    print("[AIStudyService] 请求URL: \(streamURL)")
                    print("[AIStudyService] sessionId: \(sessionId)")
                    #endif

                    // 使用 bytes 进行真正的流式读取
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    // 检查响应状态
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }

                    #if DEBUG
                    print("[AIStudyService] 响应状态: \(httpResponse.statusCode)")
                    #endif

                    if httpResponse.statusCode == 401 {
                        throw AIServiceError.unauthorized
                    }

                    if httpResponse.statusCode == 400 {
                        throw AIServiceError.serverError
                    }

                    if httpResponse.statusCode != 200 {
                        throw AIServiceError.serverError
                    }

                    // 用于累积字节（处理多字节UTF-8字符）
                    var byteBuffer = Data()
                    // 用于批量更新的缓冲
                    var chunkBuffer = ""
                    var lastYieldTime = Date()
                    let batchInterval: TimeInterval = 0.05 // 50ms 批量更新
                    // 当前事件类型
                    var currentEvent = ""

                    // 逐字节处理流数据
                    for try await byte in bytes {
                        // 检查是否取消
                        if Task.isCancelled {
                            continuation.finish(throwing: AIServiceError.cancelled)
                            return
                        }

                        byteBuffer.append(byte)

                        // 遇到换行符，处理一行
                        if byte == 0x0A { // '\n'
                            // 将整行字节转换为字符串（正确处理UTF-8多字节字符）
                            guard let lineStr = String(data: byteBuffer, encoding: .utf8) else {
                                byteBuffer.removeAll()
                                continue
                            }
                            byteBuffer.removeAll()

                            let line = lineStr.trimmingCharacters(in: .whitespacesAndNewlines)

                            // 跳过空行
                            if line.isEmpty { continue }

                            // 解析 SSE 事件类型
                            if line.hasPrefix("event: ") {
                                currentEvent = String(line.dropFirst(7))
                                continue
                            }

                            // 解析 SSE 数据
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))

                                // 检查是否完成
                                if currentEvent == "done" || jsonString == "[DONE]" {
                                    // 输出剩余的缓冲内容
                                    if !chunkBuffer.isEmpty {
                                        continuation.yield(chunkBuffer)
                                    }
                                    continuation.finish()
                                    return
                                }

                                // 检查错误
                                if currentEvent == "error" {
                                    if let data = jsonString.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let errorMsg = json["message"] as? String {
                                        #if DEBUG
                                        print("[AIStudyService] 服务器错误: \(errorMsg)")
                                        #endif
                                    }
                                    throw AIServiceError.serverError
                                }

                                // 处理 chunk 事件
                                if currentEvent == "chunk" || currentEvent.isEmpty {
                                    if let data = jsonString.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let content = json["content"] as? String {
                                        chunkBuffer.append(content)

                                        // 批量输出（每 50ms 或遇到标点）
                                        let now = Date()
                                        let shouldYield = now.timeIntervalSince(lastYieldTime) >= batchInterval
                                            || content.contains(where: { "。，！？；：,.!?;:\n".contains($0) })

                                        if shouldYield && !chunkBuffer.isEmpty {
                                            continuation.yield(chunkBuffer)
                                            chunkBuffer = ""
                                            lastYieldTime = now
                                        }
                                    }
                                }

                                // 重置事件类型
                                currentEvent = ""
                            }
                        }
                    }

                    // 输出剩余内容
                    if !chunkBuffer.isEmpty {
                        continuation.yield(chunkBuffer)
                    }
                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish(throwing: AIServiceError.cancelled)
                } catch {
                    #if DEBUG
                    print("[AIStudyService] 错误: \(error)")
                    #endif
                    continuation.finish(throwing: error)
                }
            }

            // 保存任务引用
            self.currentTask = task

            // 设置取消处理
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// 兼容旧版回调式 API
    func streamChat(
        textbookId: String,
        message: String,
        image: UIImage? = nil,
        page: Int? = nil,
        subject: String = "CHINESE",
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // 使用新的异步 API
        currentTask = Task { @MainActor in
            do {
                for try await chunk in streamChatAsync(
                    textbookId: textbookId,
                    message: message,
                    image: image,
                    page: page,
                    subject: subject
                ) {
                    onChunk(chunk)
                }
                onComplete()
            } catch {
                onError(error)
            }
        }
    }

    // MARK: - 取消请求

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        currentURLTask?.cancel()
        currentURLTask = nil
    }

    // MARK: - 图片压缩

    private static func compressImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let size = image.size

        // 如果图片已经足够小，直接返回
        if size.width <= maxWidth {
            return image
        }

        // 计算缩放比例
        let scale = maxWidth / size.width
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - 生成练习题

    func generatePractice(
        textbookId: String,
        page: Int,
        image: UIImage,
        subject: String = "CHINESE"
    ) async throws -> PracticeQuestion {
        // 使用非流式聊天端点
        guard let chatURL = URL(string: APIConfig.baseURL + APIConfig.Endpoints.aiChat) else {
            throw AIServiceError.invalidResponse
        }

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // AI 生成可能需要较长时间

        if let token = await MainActor.run(body: { APIService.shared.authToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 生成 sessionId
        let sessionId = generateSessionId(textbookId: textbookId)

        // 练习生成提示词
        let prompt = """
        【\(subjectName(subject))练习生成】第\(page)页

        请根据当前页面图片内容，生成1道练习题。

        严格按以下JSON格式输出（不要输出其他内容）：
        {
          "type": "choice",
          "stem": "题干文本",
          "options": [{"value": "A", "text": "选项A"}, {"value": "B", "text": "选项B"}, {"value": "C", "text": "选项C"}, {"value": "D", "text": "选项D"}],
          "answer": "B",
          "analysis": "解析文本"
        }

        题目类型可以是：
        - choice: 选择题
        - blank: 填空题（answer为填空答案）
        - judge: 判断题（answer为"对"或"错"）
        """

        // 压缩图片
        let compressedImage = Self.compressImage(image, maxWidth: 1024)
        guard let imageData = compressedImage.jpegData(compressionQuality: 0.7) else {
            throw AIServiceError.imageEncodingFailed
        }

        let base64Image = "data:image/jpeg;base64,\(imageData.base64EncodedString())"

        let body: [String: Any] = [
            "textbookId": textbookId,
            "sessionId": sessionId,
            "message": prompt,
            "imageBase64": base64Image,
            "subject": subject
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("[AIStudyService] 练习生成请求: \(chatURL)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        #if DEBUG
        print("[AIStudyService] 练习生成响应状态: \(httpResponse.statusCode)")
        #endif

        if httpResponse.statusCode == 401 {
            throw AIServiceError.unauthorized
        }

        if httpResponse.statusCode != 200 {
            throw AIServiceError.serverError
        }

        // 解析响应 - 后端返回格式: { success: true, data: { content: "..." } }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        // 尝试从 data.content 或直接 content 获取
        var content: String?
        if let dataObj = json["data"] as? [String: Any] {
            content = dataObj["content"] as? String
        } else {
            content = json["content"] as? String
        }

        guard let responseContent = content else {
            throw AIServiceError.invalidResponse
        }

        // 从内容中提取 JSON
        return try parsePracticeQuestion(from: responseContent)
    }

    private func parsePracticeQuestion(from content: String) throws -> PracticeQuestion {
        // 尝试找到 JSON 部分
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            throw AIServiceError.invalidResponse
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        return try JSONDecoder().decode(PracticeQuestion.self, from: data)
    }

    private func subjectName(_ code: String) -> String {
        switch code {
        case "CHINESE": return "语文"
        case "MATH": return "数学"
        case "ENGLISH": return "英语"
        default: return "学科"
        }
    }
}

// MARK: - 练习题模型

struct PracticeQuestion: Codable, Identifiable {
    var id = UUID()
    let type: QuestionType
    let stem: String
    let options: [QuestionOption]?
    let answer: String
    let analysis: String

    enum QuestionType: String, Codable {
        case choice
        case blank
        case judge
    }

    private enum CodingKeys: String, CodingKey {
        case type, stem, options, answer, analysis
    }
}

struct QuestionOption: Codable, Identifiable {
    var id: String { value }
    let value: String
    let text: String
}

// MARK: - 错误类型

enum AIServiceError: LocalizedError {
    case imageEncodingFailed
    case serverError
    case invalidResponse
    case cancelled
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "图片编码失败"
        case .serverError: return "服务器错误"
        case .invalidResponse: return "响应格式无效"
        case .cancelled: return "请求已取消"
        case .unauthorized: return "登录已过期，请重新登录"
        }
    }
}

// MARK: - API 配置扩展

extension APIConfig {
    static var aiChatURL: URL {
        return URL(string: baseURL + Endpoints.aiChat)!
    }

    static var textbookNoteURL: URL {
        return URL(string: baseURL + Endpoints.textbookNotes)!
    }
}

// MARK: - 笔记服务

class TextbookNoteService {
    static let shared = TextbookNoteService()

    private init() {}

    /// 保存笔记
    func saveNote(
        textbookId: String,
        sourceType: String,
        content: String,
        page: Int? = nil,
        query: String? = nil
    ) async throws -> String {
        var request = URLRequest(url: APIConfig.textbookNoteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let token = await MainActor.run(body: { APIService.shared.authToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "textbookId": textbookId,
            "sourceType": sourceType,
            "content": content
        ]

        if let page = page {
            body["page"] = page
        }

        if let query = query {
            body["query"] = query
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw AIServiceError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let noteId = json["id"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return noteId
    }
}
