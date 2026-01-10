//
//  PracticeModels.swift
//  pinghu12250
//
//  练习题数据模型
//

import Foundation
import SwiftUI

// MARK: - 题目类型

enum QuestionType: String, Codable, CaseIterable {
    case choice = "choice"      // 单选题
    case multiChoice = "multi"  // 多选题
    case blank = "blank"        // 填空题
    case judge = "judge"        // 判断题
    case shortAnswer = "short"  // 简答题

    var displayName: String {
        switch self {
        case .choice: return "单选题"
        case .multiChoice: return "多选题"
        case .blank: return "填空题"
        case .judge: return "判断题"
        case .shortAnswer: return "简答题"
        }
    }

    var icon: String {
        switch self {
        case .choice: return "circle.fill"
        case .multiChoice: return "checkmark.square.fill"
        case .blank: return "rectangle.and.pencil.and.ellipsis"
        case .judge: return "hand.thumbsup.fill"
        case .shortAnswer: return "text.alignleft"
        }
    }

    var color: Color {
        switch self {
        case .choice: return .blue
        case .multiChoice: return .purple
        case .blank: return .orange
        case .judge: return .green
        case .shortAnswer: return .pink
        }
    }
}

// MARK: - 练习题

struct PracticeItem: Identifiable, Codable {
    let id: UUID
    let type: QuestionType
    let stem: String              // 题干
    let options: [OptionItem]?    // 选项（选择题）
    let blanks: [String]?         // 填空答案（多个空）
    let answer: String            // 答案
    let analysis: String          // 解析
    let difficulty: Int           // 难度 1-5
    let tags: [String]?           // 标签
    let sourcePageIndex: Int?     // 来源页码
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: QuestionType,
        stem: String,
        options: [OptionItem]? = nil,
        blanks: [String]? = nil,
        answer: String,
        analysis: String,
        difficulty: Int = 3,
        tags: [String]? = nil,
        sourcePageIndex: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.stem = stem
        self.options = options
        self.blanks = blanks
        self.answer = answer
        self.analysis = analysis
        self.difficulty = difficulty
        self.tags = tags
        self.sourcePageIndex = sourcePageIndex
        self.createdAt = createdAt
    }
}

// MARK: - 选项

struct OptionItem: Identifiable, Codable {
    var id: String { value }
    let value: String   // A, B, C, D
    let text: String    // 选项内容

    static let letters = ["A", "B", "C", "D", "E", "F"]
}

// MARK: - 用户答案

struct UserAnswer: Identifiable, Codable {
    let id: UUID
    let questionId: UUID
    let answer: String           // 用户答案
    let isCorrect: Bool
    let timeTaken: TimeInterval  // 答题用时（秒）
    let submittedAt: Date

    init(questionId: UUID, answer: String, isCorrect: Bool, timeTaken: TimeInterval) {
        self.id = UUID()
        self.questionId = questionId
        self.answer = answer
        self.isCorrect = isCorrect
        self.timeTaken = timeTaken
        self.submittedAt = Date()
    }
}

// MARK: - 练习会话

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let textbookId: String
    let pageIndex: Int?
    var questions: [PracticeItem]
    var answers: [UserAnswer]
    let startedAt: Date
    var completedAt: Date?

    var isCompleted: Bool {
        answers.count == questions.count
    }

    var correctCount: Int {
        answers.filter { $0.isCorrect }.count
    }

    var accuracy: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(correctCount) / Double(answers.count)
    }

    var totalTime: TimeInterval {
        answers.reduce(0) { $0 + $1.timeTaken }
    }

    init(textbookId: String, pageIndex: Int? = nil) {
        self.id = UUID()
        self.textbookId = textbookId
        self.pageIndex = pageIndex
        self.questions = []
        self.answers = []
        self.startedAt = Date()
        self.completedAt = nil
    }
}

// MARK: - 练习状态

enum PracticeState: Equatable {
    case idle                    // 空闲
    case generating              // 生成题目中
    case ready                   // 准备就绪
    case answering(Int)          // 答题中（当前题目索引）
    case showingResult(Bool)     // 显示答案（是否正确）
    case completed               // 已完成
    case error(String)           // 错误

    static func == (lhs: PracticeState, rhs: PracticeState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.generating, .generating): return true
        case (.ready, .ready): return true
        case (.answering(let l), .answering(let r)): return l == r
        case (.showingResult(let l), .showingResult(let r)): return l == r
        case (.completed, .completed): return true
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - 练习设置

struct PracticeSettings: Codable {
    var questionCount: Int = 5           // 题目数量
    var includeChoiceQuestions: Bool = true
    var includeBlankQuestions: Bool = true
    var includeJudgeQuestions: Bool = true
    var showTimer: Bool = true           // 显示计时器
    var autoNext: Bool = false           // 自动下一题
    var autoNextDelay: TimeInterval = 2  // 自动下一题延迟

    static let `default` = PracticeSettings()
}

// MARK: - 练习历史记录

struct PracticeRecord: Identifiable, Codable {
    let id: UUID
    let textbookId: String
    let textbookTitle: String
    let pageIndex: Int?
    let questionCount: Int
    let correctCount: Int
    let accuracy: Double
    let totalTime: TimeInterval
    let completedAt: Date

    init(from session: PracticeSession, textbookTitle: String) {
        self.id = session.id
        self.textbookId = session.textbookId
        self.textbookTitle = textbookTitle
        self.pageIndex = session.pageIndex
        self.questionCount = session.questions.count
        self.correctCount = session.correctCount
        self.accuracy = session.accuracy
        self.totalTime = session.totalTime
        self.completedAt = session.completedAt ?? Date()
    }
}

// 注意: TimeInterval.formattedDuration 和 Double.percentageString
// 已移至 Core/Extensions/Number+Extensions.swift
