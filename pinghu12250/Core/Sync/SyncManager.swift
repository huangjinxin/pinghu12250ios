//
//  SyncManager.swift
//  pinghu12250
//
//  主同步管理器 - 协调所有同步操作
//

import Foundation
import Combine
import CoreData
import Network
import UIKit

/// 同步状态
enum SyncStatus: Equatable {
    case idle
    case syncing(progress: Double, message: String)
    case success(lastSync: Date)
    case failed(error: String)
    case conflict(count: Int)
    case offline

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

/// 冲突解决方式
enum ConflictResolution: String {
    case keepLocal = "keep_local"
    case keepServer = "keep_server"
    case merged = "merged"
}

/// 同步管理器
/// 负责协调 iOS 客户端与服务器之间的数据同步
@MainActor
class SyncManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SyncManager()

    // MARK: - Published Properties

    @Published var status: SyncStatus = .idle
    @Published var pendingChangesCount: Int = 0
    @Published var conflictsCount: Int = 0
    @Published var lastSyncTime: Date?
    @Published var isOnline: Bool = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.pinghu.syncMonitor")

    private var deviceId: String {
        // 获取或生成设备唯一标识
        if let id = UserDefaults.standard.string(forKey: "sync_device_id") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "sync_device_id")
        return newId
    }

    private var deviceName: String {
        UIDevice.current.name
    }

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
        loadSyncState()
    }

    // MARK: - Setup

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    // 网络恢复时自动触发同步
                    self?.triggerSync()
                } else {
                    self?.status = .offline
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func loadSyncState() {
        // 从 UserDefaults 加载上次同步时间
        if let timestamp = UserDefaults.standard.object(forKey: "last_sync_time") as? Date {
            lastSyncTime = timestamp
        }

        // 加载待同步数量
        updatePendingCount()
        updateConflictsCount()
    }

    // MARK: - Public Methods

    /// 触发同步（非阻塞）
    func triggerSync() {
        guard isOnline else {
            status = .offline
            return
        }

        guard !status.isSyncing else {
            #if DEBUG
            print("[SyncManager] 同步正在进行中，跳过")
            #endif
            return
        }

        Task {
            await performSync()
        }
    }

    /// 强制同步（等待完成）
    func forceSync() async {
        guard isOnline else {
            status = .offline
            return
        }

        await performSync()
    }

    /// 注册设备到服务器
    func registerDevice() async throws {
        guard let token = APIService.shared.authToken else {
            throw SyncError.notAuthenticated
        }

        let body: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName,
            "deviceType": "ios"
        ]

        let url = URL(string: "\(APIConfig.baseURL)/api/sync/register-device")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.serverError("设备注册失败")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success {
            #if DEBUG
            print("[SyncManager] 设备注册成功: \(deviceId)")
            #endif
        }
    }

    /// 解决冲突
    func resolveConflict(_ conflictId: UUID, resolution: ConflictResolution, mergedData: [String: Any]? = nil) async throws {
        guard let token = APIService.shared.authToken else {
            throw SyncError.notAuthenticated
        }

        // 获取本地冲突记录
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<LocalSyncConflict> = LocalSyncConflict.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conflictId as CVarArg)

        guard let conflict = try context.fetch(fetchRequest).first,
              let serverConflictId = conflict.serverConflictId else {
            throw SyncError.conflictNotFound
        }

        // 调用服务器解决冲突 API
        var body: [String: Any] = [
            "conflictId": serverConflictId,
            "resolution": resolution.rawValue
        ]

        if let merged = mergedData {
            body["mergedData"] = merged
        }

        let url = URL(string: "\(APIConfig.baseURL)/api/sync/resolve-conflict")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.serverError("解决冲突失败")
        }

        // 删除本地冲突记录
        context.delete(conflict)
        try context.save()

        updateConflictsCount()
        #if DEBUG
        print("[SyncManager] 冲突已解决: \(conflictId)")
        #endif
    }

    // MARK: - Private Methods

    private func performSync() async {
        status = .syncing(progress: 0, message: "正在同步...")

        do {
            // 1. 注册设备
            status = .syncing(progress: 0.1, message: "注册设备...")
            try await registerDevice()

            // 2. 拉取服务器变更
            status = .syncing(progress: 0.3, message: "获取服务器变更...")
            try await pullChanges()

            // 3. 推送本地变更
            status = .syncing(progress: 0.6, message: "推送本地变更...")
            try await pushChanges()

            // 4. 更新同步状态
            let now = Date()
            lastSyncTime = now
            UserDefaults.standard.set(now, forKey: "last_sync_time")

            status = .syncing(progress: 1.0, message: "同步完成")

            // 检查是否有冲突
            updateConflictsCount()
            if conflictsCount > 0 {
                status = .conflict(count: conflictsCount)
            } else {
                status = .success(lastSync: now)
            }

            #if DEBUG
            print("[SyncManager] 同步完成")
            #endif

        } catch {
            #if DEBUG
            print("[SyncManager] 同步失败: \(error)")
            #endif
            status = .failed(error: error.localizedDescription)
        }
    }

    private func pullChanges() async throws {
        guard let token = APIService.shared.authToken else {
            throw SyncError.notAuthenticated
        }

        let since = lastSyncTime ?? Date(timeIntervalSince1970: 0)
        let sinceString = ISO8601DateFormatter().string(from: since)

        var urlComponents = URLComponents(string: "\(APIConfig.baseURL)/api/sync/changes")!
        urlComponents.queryItems = [
            URLQueryItem(name: "since", value: sinceString),
            URLQueryItem(name: "types", value: "Diary"),
            URLQueryItem(name: "limit", value: "100")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.serverError("获取变更失败")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let responseData = json["data"] as? [String: Any],
              let changes = responseData["changes"] as? [[String: Any]] else {
            return
        }

        // 处理服务器变更
        try await DiarySyncHandler.shared.applyServerChanges(changes)

        #if DEBUG
        print("[SyncManager] 拉取了 \(changes.count) 条变更")
        #endif
    }

    private func pushChanges() async throws {
        guard let token = APIService.shared.authToken else {
            throw SyncError.notAuthenticated
        }

        // 获取待同步的队列项
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        fetchRequest.fetchLimit = 50

        let queueItems = try context.fetch(fetchRequest)

        if queueItems.isEmpty {
            #if DEBUG
            print("[SyncManager] 没有待推送的变更")
            #endif
            return
        }

        // 构建变更列表
        var changes: [[String: Any]] = []
        for item in queueItems {
            var change: [String: Any] = [
                "entityType": item.entityType ?? "Diary",
                "localId": item.entityId ?? "",
                "action": item.action ?? "update",
                "version": item.version
            ]

            if let dataBlob = item.data,
               let data = try? JSONSerialization.jsonObject(with: dataBlob) as? [String: Any] {
                change["data"] = data
            }

            changes.append(change)
        }

        let body: [String: Any] = [
            "deviceId": deviceId,
            "changes": changes
        ]

        let url = URL(string: "\(APIConfig.baseURL)/api/sync/push")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.serverError("推送变更失败")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let responseData = json["data"] as? [String: Any],
              let results = responseData["results"] as? [[String: Any]] else {
            return
        }

        // 处理推送结果
        try await processPushResults(results, queueItems: queueItems)

        #if DEBUG
        print("[SyncManager] 推送了 \(changes.count) 条变更")
        #endif
    }

    private func processPushResults(_ results: [[String: Any]], queueItems: [SyncQueueItem]) async throws {
        let context = CoreDataStack.shared.viewContext

        for (index, result) in results.enumerated() {
            guard index < queueItems.count else { break }
            let queueItem = queueItems[index]

            let status = result["status"] as? String ?? ""

            if status == "success" {
                // 成功：更新本地记录的 serverId 和版本号，删除队列项
                if let serverId = result["serverId"] as? String,
                   let newVersion = result["version"] as? Int {
                    try await DiarySyncHandler.shared.updateLocalRecord(
                        entityId: queueItem.entityId ?? "",
                        serverId: serverId,
                        version: newVersion
                    )
                }
                context.delete(queueItem)

            } else if status == "conflict" {
                // 冲突：创建本地冲突记录
                if let conflictData = result["conflict"] as? [String: Any] {
                    try await createLocalConflict(
                        entityType: queueItem.entityType ?? "Diary",
                        entityId: queueItem.entityId ?? "",
                        serverConflictId: result["serverId"] as? String,
                        serverData: conflictData
                    )
                }
                context.delete(queueItem)

            } else {
                // 错误：增加重试次数
                queueItem.retryCount += 1
                if queueItem.retryCount >= 3 {
                    context.delete(queueItem)
                }
            }
        }

        try context.save()
        updatePendingCount()
    }

    private func createLocalConflict(entityType: String, entityId: String, serverConflictId: String?, serverData: [String: Any]) async throws {
        let context = CoreDataStack.shared.viewContext

        let conflict = LocalSyncConflict(context: context)
        conflict.id = UUID()
        conflict.entityType = entityType
        conflict.entityId = entityId
        conflict.serverConflictId = serverConflictId
        conflict.serverVersion = Int32(serverData["serverVersion"] as? Int ?? 0)
        conflict.localVersion = Int32(serverData["localVersion"] as? Int ?? 0)
        conflict.createdAt = Date()

        if let serverDataDict = serverData["serverData"] as? [String: Any] {
            conflict.serverData = try JSONSerialization.data(withJSONObject: serverDataDict)
        }

        // 获取本地数据
        if let localDiary = try await DiarySyncHandler.shared.getLocalDiary(by: entityId) {
            let localData: [String: Any] = [
                "title": localDiary.title ?? "",
                "content": localDiary.content ?? "",
                "mood": localDiary.mood ?? "",
                "weather": localDiary.weather ?? ""
            ]
            conflict.localData = try JSONSerialization.data(withJSONObject: localData)
        }

        try context.save()
        updateConflictsCount()
    }

    private func updatePendingCount() {
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        pendingChangesCount = (try? context.count(for: fetchRequest)) ?? 0
    }

    private func updateConflictsCount() {
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<LocalSyncConflict> = LocalSyncConflict.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "resolution == nil")
        conflictsCount = (try? context.count(for: fetchRequest)) ?? 0
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case notAuthenticated
    case serverError(String)
    case conflictNotFound
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .serverError(let message):
            return message
        case .conflictNotFound:
            return "冲突记录不存在"
        case .networkUnavailable:
            return "网络不可用"
        }
    }
}
