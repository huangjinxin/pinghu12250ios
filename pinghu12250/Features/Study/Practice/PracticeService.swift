//
//  PracticeService.swift
//  pinghu12250
//
//  练习生成服务 - AI 生成练习题
//

import Foundation
import UIKit
import Combine

// MARK: - 练习生成服务

class PracticeService {
    static let shared = PracticeService()

    private init() {}

    // MARK: - 生成练习题

    /// 根据页面截图生成练习题
    func generatePractice(
        textbookId: String,
        pageIndex: Int,
        image: UIImage,
        subject: String,
        questionTypes: [QuestionType] = [.choice, .blank, .judge],
        count: Int = 3
    ) async throws -> [PracticeItem] {

        var request = URLRequest(url: APIConfig.aiChatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 构建类型描述
        let typeDescriptions = questionTypes.map { type -> String in
            switch type {
            case .choice:
                return """
                {
                  "type": "choice",
                  "stem": "题干",
                  "options": [{"value": "A", "text": "选项A"}, {"value": "B", "text": "选项B"}, {"value": "C", "text": "选项C"}, {"value": "D", "text": "选项D"}],
                  "answer": "B",
                  "analysis": "解析",
                  "difficulty": 3
                }
                """
            case .blank:
                return """
                {
                  "type": "blank",
                  "stem": "题干（用____表示填空位置）",
                  "blanks": ["答案1", "答案2"],
                  "answer": "答案1、答案2",
                  "analysis": "解析",
                  "difficulty": 3
                }
                """
            case .judge:
                return """
                {
                  "type": "judge",
                  "stem": "判断题题干",
                  "answer": "对",
                  "analysis": "解析",
                  "difficulty": 2
                }
                """
            case .multiChoice:
                return """
                {
                  "type": "multi",
                  "stem": "多选题题干",
                  "options": [{"value": "A", "text": "选项A"}, {"value": "B", "text": "选项B"}, {"value": "C", "text": "选项C"}, {"value": "D", "text": "选项D"}],
                  "answer": "AB",
                  "analysis": "解析",
                  "difficulty": 4
                }
                """
            case .shortAnswer:
                return """
                {
                  "type": "short",
                  "stem": "简答题题干",
                  "answer": "参考答案要点",
                  "analysis": "详细解析",
                  "difficulty": 5
                }
                """
            }
        }.joined(separator: "\n\n或者\n\n")

        // 练习生成提示词
        let prompt = """
        【\(subjectName(subject))练习生成】第\(pageIndex + 1)页

        请根据当前页面图片内容，生成\(count)道练习题。

        严格按以下JSON数组格式输出（不要输出其他内容）：
        [
          \(typeDescriptions)
        ]

        要求：
        1. 题目必须基于图片中的实际内容
        2. 难度分布合理（difficulty: 1-5）
        3. 解析要详细、有教育意义
        4. 选项要有迷惑性，但答案明确
        5. 输出纯JSON数组，不要有其他文字
        """

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw PracticeError.imageEncodingFailed
        }

        let base64Image = "data:image/jpeg;base64,\(imageData.base64EncodedString())"

        let body: [String: Any] = [
            "textbookId": textbookId,
            "message": prompt,
            "imageBase64": base64Image,
            "subject": subject,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60  // AI 生成可能需要较长时间

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PracticeError.serverError("无效响应")
        }

        guard httpResponse.statusCode == 200 else {
            throw PracticeError.serverError("服务器返回 \(httpResponse.statusCode)")
        }

        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            throw PracticeError.invalidResponse
        }

        // 从内容中提取 JSON 数组
        return try parsePracticeItems(from: content, pageIndex: pageIndex)
    }

    // MARK: - 解析练习题

    private func parsePracticeItems(from content: String, pageIndex: Int) throws -> [PracticeItem] {
        // 找到 JSON 数组部分
        guard let jsonStart = content.firstIndex(of: "["),
              let jsonEnd = content.lastIndex(of: "]") else {
            // 尝试找单个对象
            if let objStart = content.firstIndex(of: "{"),
               let objEnd = content.lastIndex(of: "}") {
                let jsonString = String(content[objStart...objEnd])
                if let item = try? parseSingleItem(jsonString, pageIndex: pageIndex) {
                    return [item]
                }
            }
            throw PracticeError.parseError("未找到有效JSON")
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8) else {
            throw PracticeError.parseError("JSON编码失败")
        }

        // 使用安全解码（容错模式，即使部分元素失败也能返回成功的）
        let rawItems = SafeJSONDecoder.shared.decodeArray(
            [RawPracticeItem].self,
            from: data,
            context: "PracticeService.parsePracticeItems"
        )

        if rawItems.isEmpty {
            throw PracticeError.parseError("未能解析出有效题目")
        }

        return rawItems.map { $0.toPracticeItem(pageIndex: pageIndex) }
    }

    private func parseSingleItem(_ jsonString: String, pageIndex: Int) throws -> PracticeItem {
        guard let data = jsonString.data(using: .utf8) else {
            throw PracticeError.parseError("JSON编码失败")
        }

        // 使用安全解码
        guard let rawItem = SafeJSONDecoder.shared.decode(
            RawPracticeItem.self,
            from: data,
            context: "PracticeService.parseSingleItem"
        ) else {
            throw PracticeError.parseError("题目解析失败")
        }

        return rawItem.toPracticeItem(pageIndex: pageIndex)
    }

    // MARK: - 检查答案

    func checkAnswer(question: PracticeItem, userAnswer: String) -> Bool {
        let normalizedUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedCorrectAnswer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        switch question.type {
        case .choice, .multiChoice:
            // 选择题：直接比较
            return normalizedUserAnswer == normalizedCorrectAnswer

        case .judge:
            // 判断题：支持多种输入
            let trueAnswers = ["对", "正确", "√", "是", "TRUE", "T", "YES", "Y"]
            let falseAnswers = ["错", "错误", "×", "否", "FALSE", "F", "NO", "N"]

            let isUserTrue = trueAnswers.contains(normalizedUserAnswer)
            let isUserFalse = falseAnswers.contains(normalizedUserAnswer)
            let isCorrectTrue = trueAnswers.contains(normalizedCorrectAnswer)

            if isUserTrue {
                return isCorrectTrue
            } else if isUserFalse {
                return !isCorrectTrue
            }
            return false

        case .blank:
            // 填空题：检查是否包含所有答案
            if let blanks = question.blanks {
                return blanks.allSatisfy { blank in
                    normalizedUserAnswer.contains(blank.uppercased())
                }
            }
            return normalizedUserAnswer == normalizedCorrectAnswer

        case .shortAnswer:
            // 简答题：检查关键词（简化处理）
            let keywords = normalizedCorrectAnswer.components(separatedBy: CharacterSet(charactersIn: "，,、；;"))
            let matchCount = keywords.filter { !$0.isEmpty && normalizedUserAnswer.contains($0) }.count
            return Double(matchCount) / Double(keywords.count) >= 0.6
        }
    }

    // MARK: - 辅助方法

    private func subjectName(_ code: String) -> String {
        switch code {
        case "CHINESE": return "语文"
        case "MATH": return "数学"
        case "ENGLISH": return "英语"
        case "PHYSICS": return "物理"
        case "CHEMISTRY": return "化学"
        case "BIOLOGY": return "生物"
        case "HISTORY": return "历史"
        case "GEOGRAPHY": return "地理"
        case "POLITICS": return "政治"
        default: return "学科"
        }
    }
}

// MARK: - 原始解析模型

private struct RawPracticeItem: Codable {
    let type: String
    let stem: String
    let options: [RawOption]?
    let blanks: [String]?
    let answer: String
    let analysis: String
    let difficulty: Int?

    func toPracticeItem(pageIndex: Int) -> PracticeItem {
        let questionType: QuestionType
        switch type.lowercased() {
        case "choice": questionType = .choice
        case "multi": questionType = .multiChoice
        case "blank": questionType = .blank
        case "judge": questionType = .judge
        case "short": questionType = .shortAnswer
        default: questionType = .choice
        }

        let optionItems = options?.map { OptionItem(value: $0.value, text: $0.text) }

        return PracticeItem(
            type: questionType,
            stem: stem,
            options: optionItems,
            blanks: blanks,
            answer: answer,
            analysis: analysis,
            difficulty: difficulty ?? 3,
            sourcePageIndex: pageIndex
        )
    }
}

private struct RawOption: Codable {
    let value: String
    let text: String
}

// MARK: - 错误类型

enum PracticeError: LocalizedError {
    case imageEncodingFailed
    case serverError(String)
    case invalidResponse
    case parseError(String)
    case noQuestions

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "图片编码失败"
        case .serverError(let msg): return "服务器错误: \(msg)"
        case .invalidResponse: return "响应格式无效"
        case .parseError(let msg): return "解析错误: \(msg)"
        case .noQuestions: return "未生成有效题目"
        }
    }
}
