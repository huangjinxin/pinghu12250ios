//
//  TextbookModels.swift
//  pinghu12250
//
//  教材相关数据模型
//
//  注意: AnyCodable 类型已移至 Core/Models/AnyCodable.swift
//

import Foundation
import SwiftUI

// MARK: - 内容类型枚举

enum TextbookContentType: String, Codable {
    case pdf = "pdf"
    case epub = "epub"
}

// MARK: - EPUB 章节

struct EPUBChapter: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let order: Int
    let href: String?
}

// MARK: - EPUB 元数据

struct EPUBMetadata: Codable {
    let chapters: [EPUBChapter]?
    let tocHref: String?
}

// MARK: - 教材

struct Textbook: Codable, Identifiable {
    let id: String
    let subject: String
    let grade: Int
    let semester: String
    let version: String
    let title: String
    let pdfUrl: String?
    let coverImage: String?  // 后端字段名为 coverImage
    let totalPages: Int?
    let pdfSize: Int?        // PDF 文件大小（字节）
    let status: String?
    let isHidden: Bool?
    let createdBy: String?   // 后端字段名为 createdBy
    let createdAt: String?
    let updatedAt: String?
    // 兼容旧模型的可选字段
    let publisher: String?
    let description: String?
    let isPublic: Bool?
    let viewCount: Int?
    // 关联数据（可选）
    let units: [TextbookUnit]?
    // EPUB 支持（新增）
    let contentType: String?     // "pdf" | "epub"
    let epubUrl: String?         // EPUB 文件路径
    let epubMetadata: EPUBMetadata?  // EPUB 元数据（章节目录等）

    // CodingKeys 用于字段映射
    enum CodingKeys: String, CodingKey {
        case id, subject, grade, semester, version, title
        case pdfUrl, coverImage, totalPages, pdfSize, status
        case isHidden, createdBy, createdAt, updatedAt
        case publisher, description, isPublic, viewCount
        case units
        case contentType, epubUrl, epubMetadata
    }

    init(id: String, subject: String, grade: Int, semester: String, version: String, title: String, pdfUrl: String? = nil, coverImage: String? = nil, totalPages: Int? = nil, pdfSize: Int? = nil, status: String? = nil, isHidden: Bool? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String? = nil, publisher: String? = nil, description: String? = nil, isPublic: Bool? = nil, viewCount: Int? = nil, units: [TextbookUnit]? = nil, contentType: String? = nil, epubUrl: String? = nil, epubMetadata: EPUBMetadata? = nil) {
        self.id = id
        self.subject = subject
        self.grade = grade
        self.semester = semester
        self.version = version
        self.title = title
        self.pdfUrl = pdfUrl
        self.coverImage = coverImage
        self.totalPages = totalPages
        self.pdfSize = pdfSize
        self.status = status
        self.isHidden = isHidden
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publisher = publisher
        self.description = description
        self.isPublic = isPublic
        self.viewCount = viewCount
        self.units = units
        self.contentType = contentType
        self.epubUrl = epubUrl
        self.epubMetadata = epubMetadata
    }

    var displayTitle: String {
        title.isEmpty ? "\(subject)\(grade)年级\(semester)" : title
    }

    var fullTitle: String {
        "\(gradeName) \(semester) \(title)"
    }

    var subjectName: String {
        subject
    }

    var gradeName: String {
        switch grade {
        case 1...6: return "\(grade)年级"
        case 7: return "初一"
        case 8: return "初二"
        case 9: return "初三"
        case 10: return "高一"
        case 11: return "高二"
        case 12: return "高三"
        default: return "\(grade)年级"
        }
    }

    var subjectIcon: String {
        switch subject {
        case "语文": return "语"
        case "数学": return "数"
        case "英语": return "英"
        case "科学": return "科"
        case "道德与法治": return "德"
        case "音乐": return "音"
        case "美术": return "美"
        case "体育": return "体"
        default: return String(subject.prefix(1))
        }
    }

    var subjectColor: Color {
        switch subject {
        case "语文": return .red
        case "数学": return .cyan
        case "英语": return .blue
        case "科学": return .green
        case "道德与法治": return .orange
        case "音乐": return .pink
        case "美术": return .purple
        case "体育": return .yellow
        default: return .gray
        }
    }

    var hasPdf: Bool {
        pdfUrl != nil && !(pdfUrl?.isEmpty ?? true)
    }

    var formattedPdfSize: String? {
        guard let size = pdfSize, size > 0 else { return nil }
        let mb = Double(size) / 1024.0 / 1024.0
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            let kb = Double(size) / 1024.0
            return String(format: "%.0f KB", kb)
        }
    }

    var coverImageURL: URL? {
        guard let coverImage = coverImage, !coverImage.isEmpty else { return nil }
        // 支持 base64 data URL
        if coverImage.hasPrefix("data:") {
            return URL(string: coverImage)
        }
        if coverImage.hasPrefix("http") {
            return URL(string: coverImage)
        }
        return URL(string: APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + coverImage)
    }

    var pdfFullURL: URL? {
        guard let pdfUrl = pdfUrl else { return nil }
        if pdfUrl.hasPrefix("http") {
            return URL(string: pdfUrl)
        }
        return URL(string: APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + pdfUrl)
    }

    // MARK: - EPUB 相关属性

    /// 是否为 EPUB 类型
    var isEpub: Bool {
        contentType == "epub"
    }

    /// 是否有 EPUB 文件
    var hasEpub: Bool {
        epubUrl != nil && !(epubUrl?.isEmpty ?? true)
    }

    /// EPUB 章节列表
    var chapters: [EPUBChapter] {
        epubMetadata?.chapters ?? []
    }

    /// EPUB 完整 URL
    var epubFullURL: URL? {
        guard let epubUrl = epubUrl else { return nil }
        if epubUrl.hasPrefix("http") {
            return URL(string: epubUrl)
        }
        return URL(string: APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + epubUrl)
    }

    // MARK: - 工厂方法（用于 Preview 和测试）

    /// 创建占位符教材（用于 Preview 和测试，参数顺序兼容旧代码）
    static func placeholder(
        id: String = "preview",
        title: String = "示例教材",
        subject: String = "语文",
        grade: Int = 3,
        semester: String = "上",
        version: String = "人教版",
        status: String? = nil
    ) -> Textbook {
        Textbook(
            id: id,
            subject: subject,
            grade: grade,
            semester: semester,
            version: version,
            title: title,
            status: status
        )
    }
}

struct TextbooksResponse: Decodable {
    let textbooks: [Textbook]
    let pagination: PaginationInfo?
}

struct TextbookDetailResponse: Decodable {
    let textbook: Textbook
}

// MARK: - 单元和课程

struct TextbookUnit: Codable, Identifiable {
    let id: String
    let textbookId: String
    let unitNumber: Int
    let title: String
    let theme: String?
    let pageStart: Int?
    let pageEnd: Int?
    let sortOrder: Int?
    let lessons: [TextbookLesson]?
}

struct TextbookLesson: Codable, Identifiable {
    let id: String
    let unitId: String?  // 后端 public API 不返回此字段，改为可选
    let lessonNumber: Int
    let title: String
    let pageStart: Int?
    let pageEnd: Int?
    let htmlContent: String?
    let status: String?
    let inputById: String?
    let createdAt: String?
    let updatedAt: String?
}

struct TextbookTocResponse: Decodable {
    let units: [TextbookUnit]
}

struct TextbookLessonResponse: Decodable {
    let lesson: TextbookLesson
}

// MARK: - 收藏

struct TextbookFavorite: Codable, Identifiable {
    let id: String
    let userId: String
    let textbookId: String
    let createdAt: String?
    let textbook: Textbook?
}

struct TextbookFavoritesResponse: Decodable {
    let favorites: [TextbookFavorite]
}

// MARK: - 文本范围（EPUB 定位用）

struct TextRangeData: Codable, Equatable {
    let startOffset: Int
    let endOffset: Int
}

// MARK: - 阅读笔记

struct ReadingNote: Codable, Identifiable {
    let id: String
    let userId: String
    let textbookId: String?
    let sessionId: String?
    let sourceType: String  // dict, search, explain, practice, highlight, user_note, ai_quote, exercise, solving
    let query: String?
    let content: AnyCodable?    // 可能是 JSON 对象或字符串
    let snippet: String?
    let page: Int?
    let isFavorite: Bool?       // 是否收藏
    let favoriteAt: String?     // 收藏时间
    let createdAt: String?
    let updatedAt: String?
    let textbook: Textbook?
    // EPUB 定位字段（新增）
    let chapterId: String?      // EPUB 章节标识
    let paragraphId: String?    // 段落 DOM ID
    let textRange: TextRangeData?  // 文本范围

    // 获取 content 的字符串表示
    var contentString: String? {
        guard let content = content else { return nil }
        if let str = content.value as? String {
            return str
        }
        // 如果是字典或其他类型，转为 JSON 字符串
        if let dict = content.value as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return nil
    }

    var typeLabel: String {
        switch sourceType {
        case "dict": return "查字"
        case "search": return "搜索"
        case "explain", "ai_analysis": return "AI分析"
        case "ai_quote": return "AI对话"
        case "user_note": return "笔记"
        case "pdf_selection", "highlight": return "摘录"
        case "practice": return "练习"
        case "exercise": return "习题"
        case "solving": return "解题"
        default: return "笔记"
        }
    }

    var typeColor: Color {
        switch sourceType {
        case "dict": return .orange
        case "search": return .blue
        case "explain", "ai_analysis", "ai_quote": return .green
        case "user_note": return .orange
        case "practice", "exercise", "solving": return .purple
        case "pdf_selection", "highlight": return .yellow
        default: return .gray
        }
    }

    var typeIcon: String {
        switch sourceType {
        case "dict": return "character.book.closed"
        case "search": return "magnifyingglass"
        case "explain", "ai_analysis": return "brain"
        case "ai_quote": return "bubble.left.and.bubble.right"
        case "user_note": return "pencil"
        case "pdf_selection", "highlight": return "highlighter"
        case "practice", "exercise": return "list.clipboard"
        case "solving": return "lightbulb"
        default: return "note.text"
        }
    }

    /// 从 content 中提取 imageUrl
    var imageUrl: String? {
        guard let content = content,
              let dict = content.value as? [String: Any] else {
            return nil
        }
        return dict["imageUrl"] as? String
    }

    /// 将 createdAt 字符串转换为 Date
    var createdAtDate: Date? {
        guard let createdAt = createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
    }
}

// MARK: - ReadingNote 扩展：本地创建便捷方法

extension ReadingNote {
    /// 本地创建笔记的便捷初始化方法
    init(id: String, type: String, content: String, snippet: String?, page: Int?, createdAt: Date?, imageUrl: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.userId = ""
        self.textbookId = nil
        self.sessionId = nil
        self.sourceType = type == "image" ? "user_note" : type
        self.query = nil

        // 构建 content 字典
        var contentDict: [String: Any] = ["text": content]
        if let imageUrl = imageUrl {
            contentDict["imageUrl"] = imageUrl
        }
        self.content = AnyCodable(contentDict)

        self.snippet = snippet
        self.page = page
        self.isFavorite = isFavorite
        self.favoriteAt = nil

        // 格式化日期
        if let date = createdAt {
            let formatter = ISO8601DateFormatter()
            self.createdAt = formatter.string(from: date)
        } else {
            self.createdAt = nil
        }

        self.updatedAt = nil
        self.textbook = nil

        // EPUB 定位字段（本地创建时不使用）
        self.chapterId = nil
        self.paragraphId = nil
        self.textRange = nil
    }
}

struct ReadingNotesResponse: Decodable {
    let notes: [ReadingNote]
    let pagination: PaginationInfo?
}

// 后端实际返回格式: { success: true, data: { notes: [], pagination: {} } }
struct ReadingNotesAPIResponse: Decodable {
    let success: Bool?
    let data: ReadingNotesData?
    let notes: [ReadingNote]?  // 兼容直接返回
    let pagination: PaginationInfo?  // 兼容直接返回

    struct ReadingNotesData: Decodable {
        let notes: [ReadingNote]
        let pagination: PaginationInfo?
    }

    // 提取笔记数组
    var allNotes: [ReadingNote] {
        data?.notes ?? notes ?? []
    }

    // 提取分页信息
    var paginationInfo: PaginationInfo? {
        data?.pagination ?? pagination
    }
}

struct ReadingNoteDetailResponse: Decodable {
    let note: ReadingNote
}

struct CreateReadingNoteRequest: Encodable {
    let textbookId: String?
    let sessionId: String?
    let sourceType: String
    let query: String?
    let content: String?
    let snippet: String?
    let page: Int?
}

struct UpdateReadingNoteRequest: Encodable {
    let query: String?
    let content: String?
    let snippet: String?
}

// 笔记收藏响应
struct NoteFavoriteResponse: Decodable {
    let success: Bool?
    let data: NoteFavoriteData?

    struct NoteFavoriteData: Decodable {
        let id: String
        let isFavorite: Bool
        let favoriteAt: String?
    }
}

// MARK: - 筛选选项

struct TextbookOptionItem: Decodable {
    let label: String
    let value: String

    // 支持 value 为 Int 的情况（年级）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        // value 可能是 String 或 Int
        if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .value) {
            value = String(intValue)
        } else {
            value = ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case label, value
    }
}

struct TextbookOptions: Decodable {
    let subjects: [TextbookOptionItem]?
    let grades: [TextbookOptionItem]?
    let semesters: [TextbookOptionItem]?
    let versions: [TextbookOptionItem]?

    init(subjects: [TextbookOptionItem]? = nil, grades: [TextbookOptionItem]? = nil, semesters: [TextbookOptionItem]? = nil, versions: [TextbookOptionItem]? = nil) {
        self.subjects = subjects
        self.grades = grades
        self.semesters = semesters
        self.versions = versions
    }

    // 便捷属性：提取值数组
    var subjectValues: [String] {
        subjects?.map { $0.value } ?? []
    }
    var gradeValues: [Int] {
        grades?.compactMap { Int($0.value) } ?? []
    }
    var semesterValues: [String] {
        semesters?.map { $0.value } ?? []
    }
    var versionValues: [String] {
        versions?.map { $0.value } ?? []
    }
}

// 兼容 API 直接返回（不带 options 包装）
struct TextbookOptionsResponse: Decodable {
    let subjects: [TextbookOptionItem]?
    let grades: [TextbookOptionItem]?
    let semesters: [TextbookOptionItem]?
    let versions: [TextbookOptionItem]?

    var options: TextbookOptions {
        TextbookOptions(subjects: subjects, grades: grades, semesters: semesters, versions: versions)
    }
}

// MARK: - 离线缓存

struct CachedTextbook: Codable, Identifiable {
    let id: String
    let textbook: Textbook
    let pdfLocalPath: String?
    let lastSyncAt: Date
    let downloadProgress: Double
    let isFullyDownloaded: Bool
}

// MARK: - 阅读进度

struct ReadingProgress: Codable {
    let textbookId: String
    let currentPage: Int
    let totalPages: Int
    let lastReadAt: Date

    var progressPercent: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages) * 100
    }
}

// MARK: - TextbookService 兼容的响应类型

struct TextbookListResponse: Decodable {
    let textbooks: [Textbook]
    let pagination: TextbookPagination?
    let filterOptions: FilterOptions?

    // 兼容属性
    var total: Int { pagination?.total ?? 0 }
    var page: Int { pagination?.page ?? 1 }
    var pageSize: Int { pagination?.limit ?? 20 }
    var totalPages: Int { pagination?.totalPages ?? 1 }

    struct FilterOptions: Decodable {
        let subjects: [String]?
        let grades: [Int]?
    }
}

struct TextbookPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}
