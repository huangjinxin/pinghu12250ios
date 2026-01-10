//
//  NotesWidgetData.swift
//  pinghu12250
//
//  笔记小组件数据层 - 用于 App Group 共享
//

import Foundation
import WidgetKit

// MARK: - Widget 数据模型

struct NotesWidgetEntry: TimelineEntry {
    let date: Date
    let notes: [WidgetNote]
    let totalCount: Int
    let configuration: NotesWidgetConfiguration
}

struct WidgetNote: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let type: String
    let textbookName: String
    let pageIndex: Int?
    let isFavorite: Bool
    let updatedAt: Date

    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        let truncated = String(firstLine.prefix(20))
        return truncated.isEmpty ? "无标题" : truncated
    }

    var typeIcon: String {
        switch type {
        case "text": return "note.text"
        case "highlight": return "highlighter"
        case "summary": return "doc.text.magnifyingglass"
        case "question": return "questionmark.circle"
        case "ai": return "sparkles"
        case "handwriting": return "pencil.tip.crop.circle"
        default: return "note.text"
        }
    }
}

struct NotesWidgetConfiguration: Codable {
    var showFavoritesOnly: Bool
    var maxNotes: Int
    var textbookId: String?

    static var `default`: NotesWidgetConfiguration {
        NotesWidgetConfiguration(
            showFavoritesOnly: false,
            maxNotes: 3,
            textbookId: nil
        )
    }
}

// MARK: - Widget 数据提供者

class NotesWidgetDataProvider {
    static let shared = NotesWidgetDataProvider()

    private let appGroupId = "group.com.beichentech.pinghu12250"
    private let notesKey = "widget_notes"
    private let configKey = "widget_config"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // MARK: - 保存数据到 App Group

    func saveNotesForWidget(_ notes: [StudyNote], textbooks: [String: String] = [:]) {
        let widgetNotes = notes.prefix(10).map { note in
            WidgetNote(
                id: note.id.uuidString,
                title: note.title,
                content: note.content,
                type: note.type.rawValue,
                textbookName: textbooks[note.textbookId] ?? "未知教材",
                pageIndex: note.pageIndex,
                isFavorite: note.isFavorite,
                updatedAt: note.updatedAt
            )
        }

        if let data = try? JSONEncoder().encode(Array(widgetNotes)) {
            userDefaults?.set(data, forKey: notesKey)
        }

        // 触发 Widget 刷新
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveConfiguration(_ config: NotesWidgetConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults?.set(data, forKey: configKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 读取数据

    func loadNotes() -> [WidgetNote] {
        guard let data = userDefaults?.data(forKey: notesKey),
              let notes = try? JSONDecoder().decode([WidgetNote].self, from: data) else {
            return []
        }
        return notes
    }

    func loadConfiguration() -> NotesWidgetConfiguration {
        guard let data = userDefaults?.data(forKey: configKey),
              let config = try? JSONDecoder().decode(NotesWidgetConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    // MARK: - 生成 Timeline Entry

    func getEntry(for configuration: NotesWidgetConfiguration? = nil) -> NotesWidgetEntry {
        let config = configuration ?? loadConfiguration()
        var notes = loadNotes()

        // 应用过滤
        if config.showFavoritesOnly {
            notes = notes.filter { $0.isFavorite }
        }

        if let textbookId = config.textbookId {
            notes = notes.filter { $0.id.contains(textbookId) }
        }

        // 限制数量
        let limitedNotes = Array(notes.prefix(config.maxNotes))

        return NotesWidgetEntry(
            date: Date(),
            notes: limitedNotes,
            totalCount: notes.count,
            configuration: config
        )
    }
}

// MARK: - NotesManager 扩展 - Widget 数据同步

extension NotesManager {
    /// 同步笔记到 Widget
    func syncToWidget() {
        let recentNotes = notes
            .sorted { $0.updatedAt > $1.updatedAt }

        // 构建教材名称映射
        var textbookNames: [String: String] = [:]
        for group in notesGroups {
            textbookNames[group.textbookId] = group.textbook?.displayTitle ?? "未知教材"
        }

        NotesWidgetDataProvider.shared.saveNotesForWidget(recentNotes, textbooks: textbookNames)
    }
}
