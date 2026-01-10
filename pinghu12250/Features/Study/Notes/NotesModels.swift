//
//  NotesModels.swift
//  pinghu12250
//
//  笔记数据模型
//

import Foundation
import SwiftUI
import Combine

// MARK: - 笔记模型

struct StudyNote: Identifiable, Codable {
    let id: UUID
    var textbookId: String
    var pageIndex: Int?
    var title: String
    var content: String
    var type: StudyNoteType
    var tags: [String]
    var color: StudyNoteColor
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var attachments: [NoteAttachment]
    var isResolved: Bool  // 用于疑问类型笔记的已解决状态

    init(
        id: UUID = UUID(),
        textbookId: String,
        pageIndex: Int? = nil,
        title: String = "",
        content: String,
        type: StudyNoteType = .text,
        tags: [String] = [],
        color: StudyNoteColor = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        attachments: [NoteAttachment] = [],
        isResolved: Bool = false
    ) {
        self.id = id
        self.textbookId = textbookId
        self.pageIndex = pageIndex
        self.title = title
        self.content = content
        self.type = type
        self.tags = tags
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.attachments = attachments
        self.isResolved = isResolved
    }

    // 生成标题（如果为空则从内容提取）
    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        let truncated = String(firstLine.prefix(20))
        return truncated.isEmpty ? "无标题笔记" : truncated + (firstLine.count > 20 ? "..." : "")
    }
}

// MARK: - 笔记类型

enum StudyNoteType: String, Codable, CaseIterable {
    case text = "text"           // 文字笔记
    case highlight = "highlight" // 划线/高亮
    case summary = "summary"     // 总结归纳
    case question = "question"   // 疑问/待解决
    case aiResponse = "ai"       // AI 回复保存
    case handwriting = "handwriting" // 手写笔记 (PencilKit)

    var displayName: String {
        switch self {
        case .text: return "笔记"
        case .highlight: return "划线"
        case .summary: return "总结"
        case .question: return "疑问"
        case .aiResponse: return "AI回复"
        case .handwriting: return "手写"
        }
    }

    var icon: String {
        switch self {
        case .text: return "note.text"
        case .highlight: return "highlighter"
        case .summary: return "doc.text.magnifyingglass"
        case .question: return "questionmark.circle"
        case .aiResponse: return "sparkles"
        case .handwriting: return "pencil.tip.crop.circle"
        }
    }

    var color: Color {
        switch self {
        case .text: return .blue
        case .highlight: return .yellow
        case .summary: return .green
        case .question: return .orange
        case .aiResponse: return .purple
        case .handwriting: return .teal
        }
    }
}

// MARK: - 笔记颜色

enum StudyNoteColor: String, Codable, CaseIterable {
    case `default` = "default"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"

    var color: Color {
        switch self {
        case .default: return Color(.systemGray6)
        case .red: return .red.opacity(0.1)
        case .orange: return .orange.opacity(0.1)
        case .yellow: return .yellow.opacity(0.15)
        case .green: return .green.opacity(0.1)
        case .blue: return .blue.opacity(0.1)
        case .purple: return .purple.opacity(0.1)
        }
    }

    var solidColor: Color {
        switch self {
        case .default: return .gray
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

// MARK: - 笔记附件

struct NoteAttachment: Identifiable, Codable {
    let id: UUID
    var type: AttachmentType
    var data: Data?
    var url: String?

    enum AttachmentType: String, Codable {
        case image
        case drawing
        case audio
        case link
    }
}

// MARK: - 笔记过滤器

struct NoteFilter {
    var searchText: String = ""
    var types: Set<StudyNoteType> = []
    var colors: Set<StudyNoteColor> = []
    var showFavoritesOnly: Bool = false
    var sortBy: NoteSortOption = .updatedAt
    var sortAscending: Bool = false

    var isEmpty: Bool {
        searchText.isEmpty && types.isEmpty && colors.isEmpty && !showFavoritesOnly
    }

    func matches(_ note: StudyNote) -> Bool {
        // 文本搜索
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            let matchesTitle = note.title.lowercased().contains(query)
            let matchesContent = note.content.lowercased().contains(query)
            let matchesTags = note.tags.contains { $0.lowercased().contains(query) }
            if !matchesTitle && !matchesContent && !matchesTags {
                return false
            }
        }

        // 类型过滤
        if !types.isEmpty && !types.contains(note.type) {
            return false
        }

        // 颜色过滤
        if !colors.isEmpty && !colors.contains(note.color) {
            return false
        }

        // 收藏过滤
        if showFavoritesOnly && !note.isFavorite {
            return false
        }

        return true
    }
}

// MARK: - 排序选项

enum NoteSortOption: String, CaseIterable {
    case updatedAt = "更新时间"
    case createdAt = "创建时间"
    case title = "标题"
    case pageIndex = "页码"

    func compare(_ a: StudyNote, _ b: StudyNote, ascending: Bool) -> Bool {
        let result: Bool
        switch self {
        case .updatedAt:
            result = a.updatedAt < b.updatedAt
        case .createdAt:
            result = a.createdAt < b.createdAt
        case .title:
            result = a.displayTitle.localizedCompare(b.displayTitle) == .orderedAscending
        case .pageIndex:
            result = (a.pageIndex ?? 0) < (b.pageIndex ?? 0)
        }
        return ascending ? result : !result
    }
}

// MARK: - 笔记统计

struct NoteStatistics {
    let totalCount: Int
    let byType: [StudyNoteType: Int]
    let favoriteCount: Int
    let thisWeekCount: Int
    let averageLength: Int

    static var empty: NoteStatistics {
        NoteStatistics(
            totalCount: 0,
            byType: [:],
            favoriteCount: 0,
            thisWeekCount: 0,
            averageLength: 0
        )
    }
}

// MARK: - 常用标签

struct CommonTags {
    static let subjects = ["语文", "数学", "英语", "物理", "化学", "生物", "历史", "地理", "政治"]
    static let types = ["重点", "难点", "易错", "公式", "定理", "词汇", "语法", "实验"]
    static let status = ["待复习", "已掌握", "需加强"]

    static var all: [String] {
        subjects + types + status
    }
}

// MARK: - 快捷标签（带图标）

struct QuickTag: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color

    static let presets: [QuickTag] = [
        QuickTag(label: "重点", icon: "pin.fill", color: .red),
        QuickTag(label: "难点", icon: "exclamationmark.triangle.fill", color: .orange),
        QuickTag(label: "待复习", icon: "arrow.clockwise", color: .blue),
        QuickTag(label: "已掌握", icon: "checkmark.circle.fill", color: .green)
    ]

    /// 标签文本（用于存储）
    var tagText: String {
        label
    }
}

// MARK: - 教材笔记分组（用于统一笔记视图）

struct TextbookNotesGroup: Identifiable {
    var id: String { textbookId }
    let textbookId: String
    let textbook: TextbookInfo?
    let notes: [StudyNote]

    var noteCount: Int { notes.count }

    /// 最近一条笔记的时间
    var latestNoteTime: Date? {
        notes.map { $0.updatedAt }.max()
    }

    /// 预览笔记（最近3条）
    var previewNotes: [StudyNote] {
        Array(notes.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
    }
}

// MARK: - 教材基本信息

struct TextbookInfo: Codable, Identifiable {
    let id: String
    let title: String
    let subject: String
    let grade: String
    let semester: String
    let version: String?
    let pdfUrl: String?
    let coverUrl: String?

    /// 显示标题（包含年级学期）
    var displayTitle: String {
        "\(subject) \(grade)\(semester)"
    }

    /// 学科图标
    var subjectIcon: String {
        switch subject {
        case "语文": return "📖"
        case "数学": return "🔢"
        case "英语": return "🔤"
        case "科学": return "🔬"
        case "物理": return "⚡"
        case "化学": return "🧪"
        case "生物": return "🌱"
        case "历史": return "📜"
        case "地理": return "🌍"
        default: return "📚"
        }
    }

    /// 学科颜色
    var subjectColor: Color {
        switch subject {
        case "语文": return .red
        case "数学": return .blue
        case "英语": return .purple
        case "科学": return .green
        case "物理": return .orange
        case "化学": return .cyan
        case "生物": return .green
        case "历史": return .brown
        case "地理": return .teal
        default: return .gray
        }
    }

    /// 封面图片URL
    var coverImageURL: URL? {
        guard let coverUrl = coverUrl, !coverUrl.isEmpty else { return nil }
        return URL(string: coverUrl)
    }
}

// MARK: - 同步状态

enum NoteSyncStatus: String, Codable {
    case synced = "synced"           // 已同步
    case pending = "pending"         // 待同步
    case conflict = "conflict"       // 存在冲突
    case failed = "failed"           // 同步失败

    var icon: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .pending: return "arrow.triangle.2.circlepath.icloud"
        case .conflict: return "exclamationmark.icloud"
        case .failed: return "xmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .synced: return .green
        case .pending: return .orange
        case .conflict: return .red
        case .failed: return .red
        }
    }
}

// MARK: - 笔记同步元数据

struct NoteSyncMetadata: Codable {
    var lastSyncTime: Date?
    var pendingSyncIds: Set<UUID>
    var conflictIds: Set<UUID>

    static var empty: NoteSyncMetadata {
        NoteSyncMetadata(lastSyncTime: nil, pendingSyncIds: [], conflictIds: [])
    }
}

// MARK: - 服务器笔记响应（用于解析API响应）

struct ServerNoteResponse: Codable {
    let id: String
    let userId: String
    let textbookId: String
    let sessionId: String?
    let sourceType: String
    let query: String
    let content: ServerNoteContent?
    let snippet: String?
    let page: Int?
    let createdAt: String

    /// 解析content JSON
    struct ServerNoteContent: Codable {
        let text: String?
        let tags: [String]?
        let isFavorite: Bool?
        let color: String?
    }
}

// MARK: - 分组响应（用于解析按教材分组的API响应）

struct GroupedNotesResponse: Codable {
    let success: Bool
    let data: GroupedData?

    struct GroupedData: Codable {
        let groups: [NoteGroup]?
        let pagination: Pagination?
    }

    struct NoteGroup: Codable {
        let textbookId: String
        let textbook: TextbookInfo?
        let notes: [ServerNoteResponse]
    }

    struct Pagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
    }
}

// MARK: - 语音笔记数据

struct VoiceNoteData: Codable, Identifiable {
    let id: UUID
    let audioFileURL: String        // 音频文件路径（本地或远程URL）
    let transcribedText: String     // 转写文本
    let duration: TimeInterval      // 音频时长（秒）
    let isOfflineRecognized: Bool   // 是否使用离线识别
    let createdAt: Date

    init(
        id: UUID = UUID(),
        audioFileURL: String,
        transcribedText: String,
        duration: TimeInterval,
        isOfflineRecognized: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.audioFileURL = audioFileURL
        self.transcribedText = transcribedText
        self.duration = duration
        self.isOfflineRecognized = isOfflineRecognized
        self.createdAt = createdAt
    }

    /// 从本地URL创建
    init(localURL: URL, transcribedText: String, duration: TimeInterval, isOffline: Bool) {
        self.id = UUID()
        self.audioFileURL = localURL.path
        self.transcribedText = transcribedText
        self.duration = duration
        self.isOfflineRecognized = isOffline
        self.createdAt = Date()
    }

    /// 获取本地文件URL
    var localFileURL: URL? {
        if audioFileURL.hasPrefix("/") {
            return URL(fileURLWithPath: audioFileURL)
        }
        return nil
    }

    /// 获取远程URL
    var remoteURL: URL? {
        if audioFileURL.hasPrefix("http") {
            return URL(string: audioFileURL)
        }
        return nil
    }

    /// 格式化时长显示
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 笔记类型扩展（添加语音笔记类型）

extension StudyNoteType {
    static let voice = StudyNoteType(rawValue: "voice") ?? .text

    var isVoiceNote: Bool {
        self.rawValue == "voice"
    }
}

// MARK: - 附件扩展（语音笔记便利方法）

extension NoteAttachment {
    /// 创建语音笔记附件
    static func voiceNote(url: String, duration: TimeInterval) -> NoteAttachment {
        NoteAttachment(
            id: UUID(),
            type: .audio,
            data: nil,
            url: url
        )
    }

    /// 是否为语音附件
    var isAudio: Bool {
        type == .audio
    }

    /// 获取音频URL
    var audioURL: URL? {
        guard type == .audio, let urlString = url else { return nil }
        if urlString.hasPrefix("/") {
            return URL(fileURLWithPath: urlString)
        }
        return URL(string: urlString)
    }
}

// MARK: - 语音笔记上传请求

struct VoiceNoteUploadRequest: Codable {
    let textbookId: String
    let page: Int?
    let text: String
    let audioUrl: String
    let duration: TimeInterval
    let isOffline: Bool

    init(textbookId: String, page: Int?, voiceNote: VoiceNoteData) {
        self.textbookId = textbookId
        self.page = page
        self.text = voiceNote.transcribedText
        self.audioUrl = voiceNote.audioFileURL
        self.duration = voiceNote.duration
        self.isOffline = voiceNote.isOfflineRecognized
    }
}
