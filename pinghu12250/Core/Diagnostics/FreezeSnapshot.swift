//
//  FreezeSnapshot.swift
//  pinghu12250
//
//  冻结点快照 - 记录 App 卡死时的诊断信息
//  用于在 Watchdog 触发前记录关键状态，便于后续排查
//

import Foundation
import UIKit

// MARK: - FreezeSnapshot 模型

struct FreezeSnapshot: Codable {
    let id: String
    let timestamp: Date
    let reason: String
    let level: WatchdogRecoveryLevel

    // 系统状态
    let memoryUsedMB: Double
    let memoryTotalMB: Double
    let memoryPercentage: Double

    // 应用状态
    let currentScreen: String
    let activeRequestCount: Int
    let activeRequestIds: [String]

    // 最近日志
    let recentLogs: [String]

    // 设备信息
    let deviceModel: String
    let osVersion: String
    let appVersion: String

    // MARK: - 创建快照

    static func capture(
        reason: String,
        level: WatchdogRecoveryLevel,
        currentScreen: String? = nil
    ) -> FreezeSnapshot {
        // 获取内存信息
        let memoryInfo = getMemoryInfo()

        // 获取活跃请求信息（在后台线程安全获取）
        let requestInfo = getActiveRequestInfo()

        // 获取最近日志
        let logs = AppLogger.shared.getRecentLogs(count: 20)

        return FreezeSnapshot(
            id: UUID().uuidString,
            timestamp: Date(),
            reason: reason,
            level: level,
            memoryUsedMB: memoryInfo.usedMB,
            memoryTotalMB: memoryInfo.totalMB,
            memoryPercentage: memoryInfo.percentage,
            currentScreen: currentScreen ?? getCurrentScreenName(),
            activeRequestCount: requestInfo.count,
            activeRequestIds: requestInfo.ids,
            recentLogs: logs,
            deviceModel: getDeviceModel(),
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
    }

    // MARK: - 辅助方法

    private static func getMemoryInfo() -> (usedMB: Double, totalMB: Double, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedBytes = Double(info.resident_size)
            let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
            let usedMB = usedBytes / 1024 / 1024
            let totalMB = totalBytes / 1024 / 1024
            let percentage = (usedBytes / totalBytes) * 100
            return (usedMB, totalMB, percentage)
        }

        return (0, 0, 0)
    }

    private static func getActiveRequestInfo() -> (count: Int, ids: [String]) {
        // 安全获取活跃请求信息
        // 注意：RequestController 是 @MainActor，但我们在后台线程调用
        // 这里简化处理，返回空数据（实际使用时应通过主线程安全访问）
        return (0, [])
    }

    private static func getCurrentScreenName() -> String {
        // 尝试获取当前屏幕名称
        // 这是一个简化实现，实际应用中可能需要通过 Router 或其他方式获取
        return "Unknown"
    }

    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    // MARK: - 格式化输出

    var formattedSummary: String {
        """
        === FreezeSnapshot ===
        ID: \(id)
        时间: \(timestamp.formatted())
        原因: \(reason)
        级别: \(level.description)

        内存: \(String(format: "%.0f", memoryUsedMB))MB / \(String(format: "%.0f", memoryTotalMB))MB (\(String(format: "%.1f", memoryPercentage))%)
        当前屏幕: \(currentScreen)
        活跃请求: \(activeRequestCount)

        设备: \(deviceModel)
        系统: iOS \(osVersion)
        版本: \(appVersion)

        最近日志:
        \(recentLogs.joined(separator: "\n"))
        ====================
        """
    }
}

// MARK: - WatchdogRecoveryLevel Codable 扩展

extension WatchdogRecoveryLevel: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = WatchdogRecoveryLevel(rawValue: rawValue) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - FreezeSnapshot 存储

final class FreezeSnapshotStorage {
    static let shared = FreezeSnapshotStorage()

    private let fileManager = FileManager.default
    private let maxSnapshots = 10 // 最多保存 10 个快照

    private var snapshotsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documentsPath.appendingPathComponent("FreezeSnapshots", isDirectory: true)

        // 确保目录存在
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }

    private init() {}

    // MARK: - 保存快照

    func save(_ snapshot: FreezeSnapshot) {
        let fileName = "freeze_\(snapshot.id).json"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL)

            #if DEBUG
            print("[FreezeSnapshot] 已保存快照: \(fileName)")
            #endif

            // 清理旧快照
            cleanupOldSnapshots()
        } catch {
            #if DEBUG
            print("[FreezeSnapshot] 保存失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载快照

    func loadAll() -> [FreezeSnapshot] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var snapshots: [FreezeSnapshot] = []

        for file in jsonFiles {
            if let data = try? Data(contentsOf: file),
               let snapshot = try? decoder.decode(FreezeSnapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }

        // 按时间倒序排列
        return snapshots.sorted { $0.timestamp > $1.timestamp }
    }

    /// 加载最近的快照
    func loadLatest() -> FreezeSnapshot? {
        loadAll().first
    }

    /// 加载上次启动前的快照（用于检测崩溃前的状态）
    func loadLastSessionSnapshots() -> [FreezeSnapshot] {
        // 返回最近 3 个快照
        Array(loadAll().prefix(3))
    }

    // MARK: - 清理

    private func cleanupOldSnapshots() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let jsonFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { url1, url2 in
                let date1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            }

        // 删除超过限制的旧文件
        if jsonFiles.count > maxSnapshots {
            for file in jsonFiles.dropFirst(maxSnapshots) {
                try? fileManager.removeItem(at: file)
                #if DEBUG
                print("[FreezeSnapshot] 已清理旧快照: \(file.lastPathComponent)")
                #endif
            }
        }
    }

    /// 清空所有快照
    func clearAll() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for file in files {
            try? fileManager.removeItem(at: file)
        }

        #if DEBUG
        print("[FreezeSnapshot] 已清空所有快照")
        #endif
    }
}

// MARK: - 简易日志记录器

final class AppLogger {
    static let shared = AppLogger()

    private var logs: [String] = []
    private let maxLogs = 100
    private let lock = NSLock()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    /// 记录日志
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logEntry = "[\(timestamp)] [\(fileName):\(line)] \(message)"

        lock.lock()
        logs.append(logEntry)
        if logs.count > maxLogs {
            logs.removeFirst()
        }
        lock.unlock()

        #if DEBUG
        #if DEBUG
        print(logEntry)
        #endif
        #endif
    }

    /// 获取最近的日志
    func getRecentLogs(count: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(logs.suffix(count))
    }

    /// 清空日志
    func clear() {
        lock.lock()
        logs.removeAll()
        lock.unlock()
    }
}

// MARK: - 便捷日志函数

func appLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(message, file: file, function: function, line: line)
}
