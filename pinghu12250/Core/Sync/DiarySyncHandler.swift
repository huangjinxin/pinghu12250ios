//
//  DiarySyncHandler.swift
//  pinghu12250
//
//  日记同步处理器 - 处理日记实体的同步逻辑
//

import Foundation
import CoreData
import Combine
import CryptoKit

/// 日记同步处理器
@MainActor
class DiarySyncHandler: ObservableObject {

    // MARK: - Singleton

    static let shared = DiarySyncHandler()

    // MARK: - Properties

    private let coreDataStack = CoreDataStack.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 保存日记到本地（离线优先）
    /// - Parameters:
    ///   - diary: 日记数据
    ///   - isNew: 是否是新创建
    func saveDiary(_ diary: SyncDiaryData, isNew: Bool = false) async throws {
        let context = coreDataStack.viewContext

        // 查找或创建本地记录
        let localDiary: LocalDiary
        if isNew {
            localDiary = LocalDiary(context: context)
            localDiary.id = UUID()
            localDiary.createdAt = Date()
            localDiary.authorId = AuthManager.shared.currentUser?.id ?? ""
        } else {
            let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
            if let serverId = diary.serverId {
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", serverId)
            } else {
                fetchRequest.predicate = NSPredicate(format: "id == %@", diary.localId as CVarArg)
            }

            if let existing = try context.fetch(fetchRequest).first {
                localDiary = existing
            } else {
                localDiary = LocalDiary(context: context)
                localDiary.id = diary.localId
                localDiary.createdAt = Date()
                localDiary.authorId = AuthManager.shared.currentUser?.id ?? ""
            }
        }

        // 更新字段
        localDiary.title = diary.title
        localDiary.content = diary.content
        localDiary.mood = diary.mood
        localDiary.weather = diary.weather
        localDiary.isPublic = diary.isPublic
        localDiary.updatedAt = Date()
        localDiary.version += 1
        localDiary.needsSync = true
        localDiary.syncStatus = "pending"
        localDiary.checksum = calculateChecksum(diary.content)

        if let serverId = diary.serverId {
            localDiary.serverId = serverId
        }

        try context.save()

        // 添加到同步队列
        try await addToSyncQueue(
            entityType: "Diary",
            entityId: localDiary.id?.uuidString ?? "",
            action: isNew ? "create" : "update",
            version: Int(localDiary.version),
            data: diary.toDictionary()
        )

        // 触发同步
        SyncManager.shared.triggerSync()

        #if DEBUG
        print("[DiarySyncHandler] 日记已保存到本地: \(diary.title)")
        #endif
    }

    /// 删除日记（软删除）
    func deleteDiary(_ diaryId: String) async throws {
        let context = coreDataStack.viewContext

        let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "id == %@ OR serverId == %@",
            diaryId, diaryId
        )

        guard let diary = try context.fetch(fetchRequest).first else {
            throw SyncError.conflictNotFound
        }

        diary.markedAsDeleted = true
        diary.updatedAt = Date()
        diary.version += 1
        diary.needsSync = true
        diary.syncStatus = "pending"

        try context.save()

        // 添加到同步队列
        try await addToSyncQueue(
            entityType: "Diary",
            entityId: diary.id?.uuidString ?? "",
            action: "delete",
            version: Int(diary.version),
            data: nil
        )

        SyncManager.shared.triggerSync()

        #if DEBUG
        print("[DiarySyncHandler] 日记已标记删除: \(diaryId)")
        #endif
    }

    /// 获取所有日记（本地）
    func getAllDiaries() async throws -> [SyncDiaryData] {
        let context = coreDataStack.viewContext

        let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "markedAsDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        let localDiaries = try context.fetch(fetchRequest)

        return localDiaries.map { diary in
            SyncDiaryData(
                localId: diary.id ?? UUID(),
                serverId: diary.serverId,
                title: diary.title ?? "",
                content: diary.content ?? "",
                mood: diary.mood,
                weather: diary.weather,
                isPublic: diary.isPublic,
                version: Int(diary.version),
                createdAt: diary.createdAt ?? Date(),
                updatedAt: diary.updatedAt ?? Date(),
                needsSync: diary.needsSync
            )
        }
    }

    /// 获取单个日记
    func getLocalDiary(by id: String) async throws -> LocalDiary? {
        let context = coreDataStack.viewContext

        let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "id == %@ OR serverId == %@",
            id, id
        )

        return try context.fetch(fetchRequest).first
    }

    /// 应用服务器变更
    func applyServerChanges(_ changes: [[String: Any]]) async throws {
        let context = coreDataStack.viewContext

        for change in changes {
            guard let entityId = change["entityId"] as? String,
                  let action = change["action"] as? String else {
                continue
            }

            if action == "delete" {
                // 删除操作
                let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", entityId)

                if let diary = try context.fetch(fetchRequest).first {
                    diary.markedAsDeleted = true
                    diary.needsSync = false
                    diary.syncStatus = "synced"
                }
            } else if let data = change["data"] as? [String: Any] {
                // 创建或更新操作
                let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
                let localId = data["localId"] as? String ?? ""
                fetchRequest.predicate = NSPredicate(
                    format: "serverId == %@ OR id.uuidString == %@",
                    entityId, localId
                )

                let diary: LocalDiary
                if let existing = try context.fetch(fetchRequest).first {
                    // 检查版本，只有服务器版本更高才更新
                    let serverVersion = change["version"] as? Int ?? 0
                    if serverVersion <= existing.version && existing.needsSync {
                        // 本地有未同步的更新，跳过服务器变更
                        continue
                    }
                    diary = existing
                } else {
                    diary = LocalDiary(context: context)
                    diary.id = UUID()
                    diary.authorId = AuthManager.shared.currentUser?.id ?? ""
                }

                // 更新字段
                diary.serverId = entityId
                diary.title = data["title"] as? String ?? ""
                diary.content = data["content"] as? String ?? ""
                diary.mood = data["mood"] as? String
                diary.weather = data["weather"] as? String
                diary.isPublic = data["isPublic"] as? Bool ?? true
                diary.version = Int32(change["version"] as? Int ?? 1)
                diary.needsSync = false
                diary.syncStatus = "synced"
                diary.checksum = data["checksum"] as? String

                if let createdAtStr = data["createdAt"] as? String {
                    diary.createdAt = ISO8601DateFormatter().date(from: createdAtStr)
                }
                if let updatedAtStr = data["updatedAt"] as? String {
                    diary.updatedAt = ISO8601DateFormatter().date(from: updatedAtStr)
                }
            }
        }

        try context.save()
        #if DEBUG
        print("[DiarySyncHandler] 应用了 \(changes.count) 条服务器变更")
        #endif
    }

    /// 更新本地记录（同步成功后）
    func updateLocalRecord(entityId: String, serverId: String, version: Int) async throws {
        let context = coreDataStack.viewContext

        let fetchRequest: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id.uuidString == %@", entityId)

        if let diary = try context.fetch(fetchRequest).first {
            diary.serverId = serverId
            diary.version = Int32(version)
            diary.needsSync = false
            diary.syncStatus = "synced"
            try context.save()
        }
    }

    // MARK: - Private Methods

    private func addToSyncQueue(entityType: String, entityId: String, action: String, version: Int, data: [String: Any]?) async throws {
        let context = coreDataStack.viewContext

        // 检查是否已有相同实体的队列项
        let fetchRequest: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "entityType == %@ AND entityId == %@",
            entityType, entityId
        )

        // 删除旧的队列项（合并更新）
        let existingItems = try context.fetch(fetchRequest)
        for item in existingItems {
            context.delete(item)
        }

        // 创建新的队列项
        let queueItem = SyncQueueItem(context: context)
        queueItem.id = UUID()
        queueItem.entityType = entityType
        queueItem.entityId = entityId
        queueItem.action = action
        queueItem.version = Int32(version)
        queueItem.createdAt = Date()
        queueItem.retryCount = 0

        if let data = data {
            queueItem.data = try JSONSerialization.data(withJSONObject: data)
        }

        try context.save()
    }

    private func calculateChecksum(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - SyncDiaryData Model

/// 日记数据模型（用于同步）
struct SyncDiaryData: Identifiable {
    var id: UUID { localId }
    let localId: UUID
    var serverId: String?
    var title: String
    var content: String
    var mood: String?
    var weather: String?
    var isPublic: Bool
    var version: Int
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "content": content,
            "isPublic": isPublic
        ]
        if let mood = mood { dict["mood"] = mood }
        if let weather = weather { dict["weather"] = weather }
        return dict
    }

    static func placeholder() -> SyncDiaryData {
        SyncDiaryData(
            localId: UUID(),
            serverId: nil,
            title: "示例日记",
            content: "这是一篇示例日记内容",
            mood: "happy",
            weather: "sunny",
            isPublic: true,
            version: 1,
            createdAt: Date(),
            updatedAt: Date(),
            needsSync: false
        )
    }
}
