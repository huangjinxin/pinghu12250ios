//
//  TextbookNote.swift
//  pinghu12250
//
//  教材笔记模型
//

import Foundation

/// 笔记类型
enum NoteType: String, Codable, CaseIterable {
    case highlight = "HIGHLIGHT"      // 高亮标注
    case annotation = "ANNOTATION"    // 批注
    case dictionary = "DICTIONARY"    // 查字典结果
    case search = "SEARCH"            // 搜索结果
    case ai = "AI"                    // AI 分析结果

    var displayName: String {
        switch self {
        case .highlight: return "高亮"
        case .annotation: return "批注"
        case .dictionary: return "字典"
        case .search: return "搜索"
        case .ai: return "AI分析"
        }
    }

    var iconName: String {
        switch self {
        case .highlight: return "highlighter"
        case .annotation: return "pencil.line"
        case .dictionary: return "character.book.closed"
        case .search: return "magnifyingglass"
        case .ai: return "sparkles"
        }
    }
}

/// 教材笔记模型
struct TextbookNote: Codable, Identifiable {
    let id: Int
    let userId: Int
    let textbookId: Int
    let pageNumber: Int?
    let noteType: String
    let selectedText: String?
    let content: String?
    let position: NotePosition?
    let color: String?
    let createdAt: Date?
    let updatedAt: Date?

    /// 笔记类型枚举
    var type: NoteType {
        NoteType(rawValue: noteType) ?? .annotation
    }
}

/// 笔记位置
struct NotePosition: Codable {
    let x: Double?
    let y: Double?
    let width: Double?
    let height: Double?
}

/// 创建笔记请求
struct CreateNoteRequest: Encodable {
    let textbookId: Int
    let pageNumber: Int?
    let noteType: String
    let selectedText: String?
    let content: String?
    let position: NotePosition?
    let color: String?
}

/// 笔记列表响应
struct NoteListResponse: Decodable {
    let notes: [TextbookNote]
    let total: Int
}
