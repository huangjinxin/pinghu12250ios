//
//  NotesService.swift
//  pinghu12250
//
//  笔记服务 - 本地存储和API同步
//

import Foundation
import SwiftUI
import Combine

// MARK: - 笔记管理器

@MainActor
class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published var notes: [StudyNote] = []
    @Published var isLoading = false
    @Published var error: String?

    // 跨教材笔记分组（用于AllNotesView）
    @Published var notesGroups: [TextbookNotesGroup] = []
    @Published var isLoadingGroups = false

    // 同步状态
    @Published var syncMetadata = NoteSyncMetadata.empty

    private let storageKey = "study_notes"
    private let syncMetadataKey = "notes_sync_metadata"
    private let maxLocalNotes = 500
    private var sessionId: String = ""

    private init() {
        loadLocalNotes()
        loadSyncMetadata()
        generateSessionId()
    }

    // MARK: - Session ID

    private func generateSessionId() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = Int.random(in: 1000...9999)
        sessionId = "session_\(timestamp)_\(random)"
    }

    // MARK: - CRUD 操作

    /// 创建笔记
    func createNote(_ note: StudyNote) {
        notes.insert(note, at: 0)
        saveLocalNotes()

        // 索引到 Spotlight
        indexNoteToSpotlight(note)

        // 异步同步到服务器
        Task {
            await syncNoteToServer(note)
        }
    }

    /// 便捷方法：保存笔记（异步）- 用于阅读器中选中文本保存
    func saveNote(text: String, textbookId: String, page: Int) async {
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: page - 1,  // 转换为0索引
            title: "",
            content: text,
            type: StudyNoteType.text
        )
        createNote(note)
    }

    /// 保存字典查询结果到笔记
    func saveDictNote(word: String, pinyin: String, definition: String, textbookId: String, page: Int) async {
        let content = "\(word) [\(pinyin)] \(definition)"
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: page - 1,
            title: word,
            content: content,
            type: .text,
            tags: ["字典"]
        )
        createNote(note)
    }

    /// 更新笔记
    func updateNote(_ note: StudyNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated.updatedAt = Date()
            notes[index] = updated
            saveLocalNotes()

            // 重新索引到 Spotlight
            indexNoteToSpotlight(updated)

            Task {
                await syncNoteToServer(updated)
            }
        }
    }

    /// 删除笔记
    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        saveLocalNotes()

        // 从 Spotlight 移除
        removeNoteFromSpotlight(id)

        Task {
            await deleteRemoteNote(id)
        }
    }

    /// 切换收藏状态
    func toggleFavorite(_ id: UUID) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].isFavorite.toggle()
            notes[index].updatedAt = Date()
            saveLocalNotes()

            Task {
                await syncNoteToServer(notes[index])
            }
        }
    }

    /// 切换疑问解决状态
    func toggleResolved(_ id: UUID) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].isResolved.toggle()
            notes[index].updatedAt = Date()
            saveLocalNotes()

            Task {
                await syncNoteToServer(notes[index])
            }
        }
    }

    /// 切换标签
    func toggleTag(_ id: UUID, tag: String) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            if notes[index].tags.contains(tag) {
                notes[index].tags.removeAll { $0 == tag }
            } else {
                notes[index].tags.append(tag)
            }
            notes[index].updatedAt = Date()
            saveLocalNotes()

            Task {
                await syncNoteToServer(notes[index])
            }
        }
    }

    // MARK: - 查询方法

    /// 获取教材的所有笔记
    func getNotes(for textbookId: String) -> [StudyNote] {
        notes.filter { $0.textbookId == textbookId }
    }

    /// 获取指定页面的笔记
    func getNotes(for textbookId: String, pageIndex: Int) -> [StudyNote] {
        notes.filter { $0.textbookId == textbookId && $0.pageIndex == pageIndex }
    }

    /// 应用过滤器
    func getFilteredNotes(filter: NoteFilter, textbookId: String? = nil) -> [StudyNote] {
        var result = notes

        // 教材过滤
        if let textbookId = textbookId {
            result = result.filter { $0.textbookId == textbookId }
        }

        // 应用过滤器
        result = result.filter { filter.matches($0) }

        // 排序
        result.sort { filter.sortBy.compare($0, $1, ascending: filter.sortAscending) }

        return result
    }

    /// 获取统计数据
    func getStatistics(textbookId: String? = nil) -> NoteStatistics {
        var targetNotes = notes
        if let textbookId = textbookId {
            targetNotes = notes.filter { $0.textbookId == textbookId }
        }

        let byType = Dictionary(grouping: targetNotes, by: { $0.type })
            .mapValues { $0.count }

        let favoriteCount = targetNotes.filter { $0.isFavorite }.count

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let thisWeekCount = targetNotes.filter { $0.createdAt >= weekAgo }.count

        let totalLength = targetNotes.reduce(0) { $0 + $1.content.count }
        let averageLength = targetNotes.isEmpty ? 0 : totalLength / targetNotes.count

        return NoteStatistics(
            totalCount: targetNotes.count,
            byType: byType,
            favoriteCount: favoriteCount,
            thisWeekCount: thisWeekCount,
            averageLength: averageLength
        )
    }

    // MARK: - 批注笔记查询

    /// 查找指定页的批注笔记（每页唯一）
    func findAnnotationNote(textbookId: String, pageIndex: Int) -> StudyNote? {
        notes.first { note in
            note.textbookId == textbookId &&
            note.pageIndex == pageIndex &&
            note.type == .handwriting &&
            note.tags.contains("批注")
        }
    }

    /// 获取教材的所有批注笔记
    func getAnnotationNotes(for textbookId: String) -> [StudyNote] {
        notes.filter { note in
            note.textbookId == textbookId &&
            note.type == .handwriting &&
            note.tags.contains("批注")
        }
        .sorted { ($0.pageIndex ?? 0) < ($1.pageIndex ?? 0) }
    }

    /// 检查指定页是否有批注
    func hasAnnotation(textbookId: String, pageIndex: Int) -> Bool {
        findAnnotationNote(textbookId: textbookId, pageIndex: pageIndex) != nil
    }

    /// 获取有批注的页码列表
    func getAnnotatedPages(for textbookId: String) -> [Int] {
        getAnnotationNotes(for: textbookId)
            .compactMap { $0.pageIndex }
            .sorted()
    }

    // MARK: - 跨教材查询（用于统一笔记入口）

    /// 获取所有笔记并按教材分组（从服务器）
    func fetchAllNotesGrouped() async {
        guard let token = APIService.shared.authToken else { return }

        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "?groupBy=textbook&limit=100") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("[Notes] fetchAllNotesGrouped failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                #endif
                return
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(GroupedNotesResponse.self, from: data)

            if result.success, let groups = result.data?.groups {
                notesGroups = groups.map { group in
                    let studyNotes = group.notes.compactMap { parseServerNoteResponse($0) }
                    return TextbookNotesGroup(
                        textbookId: group.textbookId,
                        textbook: group.textbook,
                        notes: studyNotes
                    )
                }.sorted { ($0.latestNoteTime ?? .distantPast) > ($1.latestNoteTime ?? .distantPast) }

                #if DEBUG
                print("[Notes] Loaded \(notesGroups.count) textbook groups")
                #endif
            }
        } catch {
            #if DEBUG
            print("[Notes] fetchAllNotesGrouped error: \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }

    /// 本地按教材分组
    func getLocalNotesGrouped() -> [TextbookNotesGroup] {
        let grouped = Dictionary(grouping: notes, by: { $0.textbookId })
        return grouped.map { textbookId, notes in
            TextbookNotesGroup(
                textbookId: textbookId,
                textbook: nil,  // 本地模式没有教材详情
                notes: notes
            )
        }.sorted { ($0.latestNoteTime ?? .distantPast) > ($1.latestNoteTime ?? .distantPast) }
    }

    /// 搜索笔记（跨教材）
    func searchNotes(query: String) async -> [StudyNote] {
        guard let token = APIService.shared.authToken else {
            // 无网络时搜索本地
            return searchLocalNotes(query: query)
        }

        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "?search=\(encodedQuery)&limit=50") else {
                return searchLocalNotes(query: query)
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return searchLocalNotes(query: query)
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let dataDict = json["data"] as? [String: Any],
               let notesArray = dataDict["notes"] as? [[String: Any]] {
                return notesArray.compactMap { parseServerNote($0) }
            }
        } catch {
            #if DEBUG
            print("[Notes] Search error: \(error)")
            #endif
        }

        return searchLocalNotes(query: query)
    }

    /// 本地搜索
    private func searchLocalNotes(query: String) -> [StudyNote] {
        let lowercasedQuery = query.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(lowercasedQuery) ||
            note.content.lowercased().contains(lowercasedQuery) ||
            note.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// 按类型筛选所有笔记
    func filterNotesByType(_ type: StudyNoteType) -> [StudyNote] {
        notes.filter { $0.type == type }
    }

    /// 获取所有收藏的笔记
    func getFavoriteNotes() -> [StudyNote] {
        notes.filter { $0.isFavorite }
    }

    /// 解析服务器响应模型
    private func parseServerNoteResponse(_ response: ServerNoteResponse) -> StudyNote? {
        guard let id = UUID(uuidString: response.id) else { return nil }

        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: response.createdAt) ?? Date()

        // 从 sourceType 推断笔记类型
        let type: StudyNoteType
        switch response.sourceType {
        case "dict":
            type = .text
        case "ai_analysis":
            type = .aiResponse
        case "pdf_selection":
            type = .highlight
        case "practice":
            type = .question
        case "user_note":
            type = .summary
        default:
            type = .text
        }

        let content = response.content?.text ?? response.snippet ?? ""
        let tags = response.content?.tags ?? []
        let isFavorite = response.content?.isFavorite ?? false
        let colorStr = response.content?.color ?? "default"
        let color = StudyNoteColor(rawValue: colorStr) ?? .default

        return StudyNote(
            id: id,
            textbookId: response.textbookId,
            pageIndex: response.page != nil ? response.page! - 1 : nil,  // 转为0索引
            title: response.query,
            content: content,
            type: type,
            tags: tags,
            color: color,
            createdAt: createdAt,
            updatedAt: createdAt,
            isFavorite: isFavorite,
            attachments: []
        )
    }

    // MARK: - AI 笔记快捷创建

    /// 从 AI 回复创建笔记
    func createFromAIResponse(content: String, textbookId: String, pageIndex: Int?) {
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: pageIndex,
            title: "",
            content: content,
            type: StudyNoteType.aiResponse,
            tags: ["AI生成"]
        )
        createNote(note)
    }

    /// 从选中文本创建高亮笔记
    func createHighlight(text: String, textbookId: String, pageIndex: Int) {
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: pageIndex,
            title: "",
            content: text,
            type: StudyNoteType.highlight,
            color: StudyNoteColor.yellow
        )
        createNote(note)
    }

    // MARK: - 本地存储

    private func loadLocalNotes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StudyNote].self, from: data) else {
            return
        }
        notes = decoded
    }

    private func saveLocalNotes() {
        // 限制本地存储数量
        if notes.count > maxLocalNotes {
            notes = Array(notes.prefix(maxLocalNotes))
        }

        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)

        // 同步到 Widget
        syncToWidget()
    }

    private func loadSyncMetadata() {
        guard let data = UserDefaults.standard.data(forKey: syncMetadataKey),
              let decoded = try? JSONDecoder().decode(NoteSyncMetadata.self, from: data) else {
            return
        }
        syncMetadata = decoded
    }

    private func saveSyncMetadata() {
        guard let data = try? JSONEncoder().encode(syncMetadata) else { return }
        UserDefaults.standard.set(data, forKey: syncMetadataKey)
    }

    /// 获取笔记的同步状态
    func getSyncStatus(for noteId: UUID) -> NoteSyncStatus {
        if syncMetadata.conflictIds.contains(noteId) {
            return .conflict
        } else if syncMetadata.pendingSyncIds.contains(noteId) {
            return .pending
        } else {
            return .synced
        }
    }

    /// 标记笔记需要同步
    private func markNeedSync(_ noteId: UUID) {
        syncMetadata.pendingSyncIds.insert(noteId)
        saveSyncMetadata()
    }

    /// 标记笔记已同步
    private func markSynced(_ noteId: UUID) {
        syncMetadata.pendingSyncIds.remove(noteId)
        syncMetadata.conflictIds.remove(noteId)
        saveSyncMetadata()
    }

    // MARK: - 服务器同步

    /// 同步笔记到服务器（使用后端期望的格式，包含扩展字段）
    private func syncNoteToServer(_ note: StudyNote) async {
        guard let token = APIService.shared.authToken else {
            markNeedSync(note.id)
            return
        }

        do {
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            // 根据笔记类型确定sourceType
            let sourceType: String
            switch note.type {
            case .text:
                sourceType = note.tags.contains("字典") ? "dict" : "pdf_selection"
            case .highlight:
                sourceType = "pdf_selection"
            case .summary:
                sourceType = "user_note"
            case .question:
                sourceType = "practice"
            case .aiResponse:
                sourceType = "ai_analysis"
            case .handwriting:
                sourceType = "handwriting"
            }

            // 构建符合后端API的请求体（包含扩展字段）
            let contentDict: [String: Any] = [
                "text": note.content,
                "tags": note.tags,
                "isFavorite": note.isFavorite,
                "color": note.color.rawValue
            ]

            let body: [String: Any] = [
                "textbookId": note.textbookId,
                "sessionId": sessionId,
                "sourceType": sourceType,
                "query": note.title.isEmpty ? String(note.content.prefix(50)) : note.title,
                "content": contentDict,
                "snippet": String(note.content.prefix(100)),
                "page": (note.pageIndex ?? 0) + 1  // 转换为1索引
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                markSynced(note.id)
                #if DEBUG
                print("[Notes] Note synced successfully")
                #endif
            } else {
                markNeedSync(note.id)
                #if DEBUG
                print("[Notes] Sync failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                #endif
            }
        } catch {
            markNeedSync(note.id)
            #if DEBUG
            print("[Notes] Sync error: \(error.localizedDescription)")
            #endif
        }
    }

    private func deleteRemoteNote(_ id: UUID) async {
        guard let token = APIService.shared.authToken else { return }

        do {
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "/\(id.uuidString)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("Note delete error: \(error.localizedDescription)")
            #endif
        }
    }

    /// 从服务器拉取笔记
    func fetchFromServer(textbookId: String) async {
        guard let token = APIService.shared.authToken else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.textbookNotes + "/textbook/\(textbookId)") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let notesData = json["data"] as? [[String: Any]] {
                let serverNotes = notesData.compactMap { parseServerNote($0) }
                mergeServerNotes(serverNotes, textbookId: textbookId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseServerNote(_ data: [String: Any]) -> StudyNote? {
        guard let idString = data["id"] as? String,
              let textbookId = data["textbookId"] as? String,
              let content = data["content"] as? String else {
            return nil
        }

        let id = UUID(uuidString: idString) ?? UUID()
        let pageIndex = data["pageIndex"] as? Int
        let title = data["title"] as? String ?? ""
        let typeRaw = data["noteType"] as? String ?? "text"
        let type = StudyNoteType(rawValue: typeRaw) ?? .text
        let tags = data["tags"] as? [String] ?? []
        let colorRaw = data["color"] as? String ?? "default"
        let color = StudyNoteColor(rawValue: colorRaw) ?? .default
        let isFavorite = data["isFavorite"] as? Bool ?? false

        let dateFormatter = ISO8601DateFormatter()
        let createdAt = (data["createdAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = (data["updatedAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()

        return StudyNote(
            id: id,
            textbookId: textbookId,
            pageIndex: pageIndex,
            title: title,
            content: content,
            type: type,
            tags: tags,
            color: color,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFavorite: isFavorite,
            attachments: []
        )
    }

    private func mergeServerNotes(_ serverNotes: [StudyNote], textbookId: String) {
        let localNotes = notes.filter { $0.textbookId == textbookId }
        var merged: [StudyNote] = []

        // 构建服务器笔记的ID映射
        var serverMap: [UUID: StudyNote] = [:]
        serverNotes.forEach { serverMap[$0.id] = $0 }

        // 合并逻辑：基于 updatedAt 时间戳比对
        for local in localNotes {
            if let server = serverMap[local.id] {
                // 两边都有：取更新时间晚的
                if local.updatedAt > server.updatedAt {
                    merged.append(local)
                    // 本地更新，需要重新同步到服务器
                    markNeedSync(local.id)
                } else if local.updatedAt < server.updatedAt {
                    merged.append(server)
                    markSynced(server.id)
                } else {
                    // 时间相同，保留服务器版本
                    merged.append(server)
                    markSynced(server.id)
                }
                serverMap.removeValue(forKey: local.id)
            } else {
                // 只有本地有：可能是新创建或服务器已删除
                if let lastSync = syncMetadata.lastSyncTime, local.createdAt > lastSync {
                    // 上次同步后创建的，保留并上传
                    merged.append(local)
                    markNeedSync(local.id)
                }
                // 否则认为是服务器删除的，不保留
            }
        }

        // 只有服务器有的：添加到本地
        for (_, serverNote) in serverMap {
            merged.append(serverNote)
            markSynced(serverNote.id)
        }

        // 更新本地存储
        notes = notes.filter { $0.textbookId != textbookId } + merged
        notes.sort { $0.updatedAt > $1.updatedAt }

        // 更新同步时间
        syncMetadata.lastSyncTime = Date()
        saveSyncMetadata()
        saveLocalNotes()

        #if DEBUG
        print("[Notes] Merged \(merged.count) notes for textbook \(textbookId)")
        #endif
    }

    /// 同步所有待同步的笔记
    func syncPendingNotes() async {
        let pendingIds = syncMetadata.pendingSyncIds
        for noteId in pendingIds {
            if let note = notes.first(where: { $0.id == noteId }) {
                await syncNoteToServer(note)
            }
        }
    }

    // MARK: - 导出功能

    func exportNotes(textbookId: String, format: ExportFormat) -> String {
        let targetNotes = getNotes(for: textbookId)

        switch format {
        case .markdown:
            return exportToMarkdown(targetNotes)
        case .plainText:
            return exportToPlainText(targetNotes)
        case .json:
            return exportToJSON(targetNotes)
        }
    }

    private func exportToMarkdown(_ notes: [StudyNote]) -> String {
        var result = "# 学习笔记\n\n"
        let grouped = Dictionary(grouping: notes) { $0.pageIndex ?? -1 }

        for (pageIndex, pageNotes) in grouped.sorted(by: { $0.key < $1.key }) {
            if pageIndex >= 0 {
                result += "## 第 \(pageIndex + 1) 页\n\n"
            } else {
                result += "## 未分类\n\n"
            }

            for note in pageNotes {
                result += "### \(note.displayTitle)\n\n"
                result += "\(note.content)\n\n"
                if !note.tags.isEmpty {
                    result += "标签: \(note.tags.joined(separator: ", "))\n\n"
                }
                result += "---\n\n"
            }
        }

        return result
    }

    private func exportToPlainText(_ notes: [StudyNote]) -> String {
        notes.map { note in
            """
            【\(note.displayTitle)】
            \(note.content)
            创建时间: \(note.createdAt.formatted())
            """
        }.joined(separator: "\n\n================\n\n")
    }

    private func exportToJSON(_ notes: [StudyNote]) -> String {
        guard let data = try? JSONEncoder().encode(notes),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    enum ExportFormat {
        case markdown
        case plainText
        case json
    }
}
