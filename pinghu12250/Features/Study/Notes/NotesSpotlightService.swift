//
//  NotesSpotlightService.swift
//  pinghu12250
//
//  笔记 Spotlight 索引服务 - 支持系统搜索
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - Spotlight 索引服务

@MainActor
class NotesSpotlightService {
    static let shared = NotesSpotlightService()

    private let domainIdentifier = "com.beichentech.pinghu12250.notes"

    private init() {}

    // MARK: - 索引单条笔记

    func indexNote(_ note: StudyNote, textbookName: String? = nil) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // 标题
        attributeSet.title = note.displayTitle

        // 内容描述
        attributeSet.contentDescription = note.content

        // 关键词（标签 + 笔记类型）
        var keywords = note.tags
        keywords.append(note.type.displayName)
        if let textbook = textbookName {
            keywords.append(textbook)
        }
        attributeSet.keywords = keywords

        // 时间戳
        attributeSet.contentCreationDate = note.createdAt
        attributeSet.contentModificationDate = note.updatedAt

        // 缩略图提示
        attributeSet.thumbnailData = nil  // 可以添加类型图标

        // 显示名称
        attributeSet.displayName = note.displayTitle

        // 内容类型
        attributeSet.contentType = UTType.plainText.identifier

        // 创建可搜索项
        let item = CSSearchableItem(
            uniqueIdentifier: note.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // 设置过期时间（1年）
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

        // 添加到索引
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 索引笔记失败: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("[Spotlight] 索引笔记成功: \(note.displayTitle)")
                #endif
            }
        }
    }

    // MARK: - 批量索引笔记

    func indexNotes(_ notes: [StudyNote], textbooks: [String: String] = [:]) {
        let items = notes.map { note -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

            attributeSet.title = note.displayTitle
            attributeSet.contentDescription = note.content

            var keywords = note.tags
            keywords.append(note.type.displayName)
            if let textbook = textbooks[note.textbookId] {
                keywords.append(textbook)
            }
            attributeSet.keywords = keywords

            attributeSet.contentCreationDate = note.createdAt
            attributeSet.contentModificationDate = note.updatedAt
            attributeSet.displayName = note.displayTitle
            attributeSet.contentType = UTType.plainText.identifier

            let item = CSSearchableItem(
                uniqueIdentifier: note.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 批量索引失败: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("[Spotlight] 批量索引成功: \(items.count) 条笔记")
                #endif
            }
        }
    }

    // MARK: - 删除索引

    func removeNote(_ noteId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [noteId.uuidString]) { error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 删除索引失败: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func removeNotes(_ noteIds: [UUID]) {
        let identifiers = noteIds.map { $0.uuidString }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 批量删除索引失败: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - 清除所有索引

    func removeAllIndexes() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 清除所有索引失败: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("[Spotlight] 已清除所有笔记索引")
                #endif
            }
        }
    }

    // MARK: - 重建索引

    func rebuildIndex(notes: [StudyNote], textbooks: [String: String] = [:]) {
        // 先清除旧索引
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("[Spotlight] 清除旧索引失败: \(error.localizedDescription)")
                #endif
                return
            }

            // 重新索引
            Task { @MainActor in
                self?.indexNotes(notes, textbooks: textbooks)
            }
        }
    }

    // MARK: - 处理 Spotlight 打开

    /// 处理从 Spotlight 点击打开的笔记
    /// 在 SceneDelegate 或 App 中调用
    func handleSpotlightActivity(_ userActivity: NSUserActivity) -> UUID? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let noteId = UUID(uuidString: identifier) else {
            return nil
        }

        #if DEBUG
        print("[Spotlight] 打开笔记: \(noteId)")
        #endif

        return noteId
    }
}

// MARK: - NotesManager 扩展 - Spotlight 集成

extension NotesManager {
    /// 同步笔记到 Spotlight
    func syncToSpotlight() {
        // 构建教材名称映射
        var textbookNames: [String: String] = [:]
        for group in notesGroups {
            textbookNames[group.textbookId] = group.textbook?.displayTitle ?? "未知教材"
        }

        NotesSpotlightService.shared.indexNotes(notes, textbooks: textbookNames)
    }

    /// 创建笔记时同时索引
    func indexNoteToSpotlight(_ note: StudyNote) {
        let textbookName = notesGroups.first { $0.textbookId == note.textbookId }?.textbook?.displayTitle
        NotesSpotlightService.shared.indexNote(note, textbookName: textbookName)
    }

    /// 删除笔记时同时移除索引
    func removeNoteFromSpotlight(_ noteId: UUID) {
        NotesSpotlightService.shared.removeNote(noteId)
    }
}
