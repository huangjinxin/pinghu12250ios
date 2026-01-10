//
//  CoreDataStack.swift
//  pinghu12250
//
//  Core Data 数据栈管理
//  用于本地离线数据存储和同步
//

import Foundation
import CoreData
import Combine

/// Core Data 数据栈单例
/// 管理持久化容器和上下文
@MainActor
class CoreDataStack: ObservableObject {

    // MARK: - Singleton

    static let shared = CoreDataStack()

    // MARK: - Properties

    /// 持久化容器
    let persistentContainer: NSPersistentContainer

    /// 主上下文（UI 线程使用）
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    /// 上次清理时间
    private var lastCleanupDate: Date?

    // MARK: - Initialization

    private init() {
        // 创建容器
        persistentContainer = NSPersistentContainer(name: "SyncModel")

        // 配置持久化存储描述
        if let description = persistentContainer.persistentStoreDescriptions.first {
            // 启用持久化历史追踪（用于同步）
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentHistoryTrackingKey)
            // 启用远程变更通知
            description.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        // 加载持久化存储
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                // 开发阶段打印错误，生产环境应该有更好的错误处理
                #if DEBUG
                print("[CoreData] 加载持久化存储失败: \(error)")
                #endif

                // 尝试删除并重建存储
                if let url = description.url {
                    try? FileManager.default.removeItem(at: url)
                    #if DEBUG
                    print("[CoreData] 已删除损坏的存储文件，将重建")
                    #endif
                }
            } else {
                #if DEBUG
                print("[CoreData] 持久化存储加载成功: \(description.url?.path ?? "unknown")")
                #endif
            }
        }

        // 配置主上下文
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // 设置撤销管理器（可选）
        viewContext.undoManager = nil
    }

    // MARK: - Context Management

    /// 保存主上下文
    func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            print("[CoreData] 保存上下文失败: \(error)")
            #endif
        }
    }

    /// 创建后台上下文
    /// 用于耗时操作，避免阻塞主线程
    func backgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    /// 在后台上下文中执行操作
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // MARK: - Cleanup

    /// 清理已删除的旧数据
    /// 保留最近 30 天的软删除记录用于同步
    func cleanupDeletedRecords() {
        let context = backgroundContext()

        context.perform {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            // 清理已删除的日记
            let diaryFetch: NSFetchRequest<NSFetchRequestResult> = LocalDiary.fetchRequest()
            diaryFetch.predicate = NSPredicate(format: "isDeleted == YES AND updatedAt < %@", cutoffDate as NSDate)

            let diaryDelete = NSBatchDeleteRequest(fetchRequest: diaryFetch)
            diaryDelete.resultType = .resultTypeCount

            do {
                let result = try context.execute(diaryDelete) as? NSBatchDeleteResult
                let count = result?.result as? Int ?? 0
                if count > 0 {
                    #if DEBUG
                    print("[CoreData] 已清理 \(count) 条已删除的日记记录")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[CoreData] 清理失败: \(error)")
                #endif
            }
        }
    }

    // MARK: - Statistics

    /// 获取本地数据统计
    func getStatistics() -> (diaries: Int, pendingSync: Int, conflicts: Int) {
        var diaryCount = 0
        var pendingCount = 0
        var conflictCount = 0

        // 日记总数
        let diaryFetch: NSFetchRequest<LocalDiary> = LocalDiary.fetchRequest()
        diaryFetch.predicate = NSPredicate(format: "isDeleted == NO")
        diaryCount = (try? viewContext.count(for: diaryFetch)) ?? 0

        // 待同步数
        let pendingFetch: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        pendingCount = (try? viewContext.count(for: pendingFetch)) ?? 0

        // 冲突数
        let conflictFetch: NSFetchRequest<LocalSyncConflict> = LocalSyncConflict.fetchRequest()
        conflictFetch.predicate = NSPredicate(format: "resolution == nil")
        conflictCount = (try? viewContext.count(for: conflictFetch)) ?? 0

        return (diaryCount, pendingCount, conflictCount)
    }

    // MARK: - Reset

    /// 重置所有本地数据（危险操作）
    func resetAllData() async {
        await withCheckedContinuation { continuation in
            performBackgroundTask { context in
                // 删除所有实体
                let entityNames = ["LocalDiary", "SyncQueueItem", "LocalSyncConflict"]

                for entityName in entityNames {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                    do {
                        try context.execute(deleteRequest)
                    } catch {
                        #if DEBUG
                        print("[CoreData] 删除 \(entityName) 失败: \(error)")
                        #endif
                    }
                }

                do {
                    try context.save()
                    #if DEBUG
                    print("[CoreData] 所有数据已重置")
                    #endif
                } catch {
                    #if DEBUG
                    print("[CoreData] 保存失败: \(error)")
                    #endif
                }

                continuation.resume()
            }
        }
    }
}

// MARK: - Preview Support

extension CoreDataStack {
    /// 预览用的占位实例
    static func placeholder() -> CoreDataStack {
        return CoreDataStack.shared
    }
}
