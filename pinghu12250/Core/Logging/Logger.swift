//
//  Logger.swift
//  pinghu12250
//
//  统一日志系统 - 替换所有 print()，支持分级和本地持久化
//

import Foundation
import os
import UIKit

// MARK: - 日志级别

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var prefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARNING"
        case .error: return "❌ ERROR"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 日志管理器

final class Logger {
    static let shared = Logger()

    // 系统日志
    private let osLog = OSLog(subsystem: "com.pinghu12250", category: "App")

    // 日志文件路径
    private let logFileURL: URL

    // 最小日志级别
    #if DEBUG
    var minLevel: LogLevel = .debug
    #else
    var minLevel: LogLevel = .warning
    #endif

    // 是否输出到控制台（Release 模式下默认关闭）
    #if DEBUG
    var consoleEnabled = true
    #else
    var consoleEnabled = false
    #endif

    // 是否写入文件
    var fileEnabled = true

    // 日志保留天数
    private let retentionDays = 7

    // 最大日志文件大小（5MB）
    private let maxFileSize: Int64 = 5 * 1024 * 1024

    // 文件写入队列
    private let fileQueue = DispatchQueue(label: "com.pinghu12250.logger.file")

    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        // 创建日志目录
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // 日志文件名包含日期
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        logFileURL = logsDir.appendingPathComponent("app-\(dateStr).log")

        // 启动时清理旧日志
        cleanupOldLogs()
    }

    // MARK: - 日志方法

    /// 调试日志
    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    /// 信息日志
    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    /// 警告日志
    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    /// 错误日志
    func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
    }

    // MARK: - 核心日志方法

    private func log(
        level: LogLevel,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= minLevel else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.prefix) [\(fileName):\(line)] \(function) - \(message)"

        // 输出到控制台
        if consoleEnabled {
            print(logMessage)
        }

        // 输出到系统日志
        os_log("%{public}@", log: osLog, type: level.osLogType, message)

        // 写入文件
        if fileEnabled {
            writeToFile(logMessage)
        }
    }

    // MARK: - 文件操作

    private func writeToFile(_ message: String) {
        fileQueue.async { [weak self] in
            guard let self = self else { return }

            let line = message + "\n"
            guard let data = line.data(using: .utf8) else { return }

            // 检查文件大小，如果超过限制则轮转
            self.rotateLogFileIfNeeded()

            // 追加写入
            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: self.logFileURL)
            }
        }
    }

    private func rotateLogFileIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? Int64,
              size > maxFileSize else {
            return
        }

        // 重命名旧文件
        let timestamp = Int(Date().timeIntervalSince1970)
        let archiveURL = logFileURL.deletingLastPathComponent()
            .appendingPathComponent("app-\(timestamp).log.old")

        try? FileManager.default.moveItem(at: logFileURL, to: archiveURL)
    }

    /// 清理过期日志
    func cleanupOldLogs() {
        fileQueue.async { [weak self] in
            guard let self = self else { return }

            let logsDir = self.logFileURL.deletingLastPathComponent()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -self.retentionDays, to: Date())!

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: logsDir,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { return }

            for file in files {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attrs[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - 导出日志

    /// 获取所有日志文件
    func getLogFiles() -> [URL] {
        let logsDir = logFileURL.deletingLastPathComponent()
        return (try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.creationDateKey]
        ).sorted { url1, url2 in
            let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }) ?? []
    }

    /// 导出所有日志到单个文件
    func exportLogs() -> URL? {
        let exportDir = FileManager.default.temporaryDirectory
        let exportURL = exportDir.appendingPathComponent("pinghu12250-logs-\(Int(Date().timeIntervalSince1970)).txt")

        var content = "=== 苹湖少儿空间 日志导出 ===\n"
        content += "导出时间: \(dateFormatter.string(from: Date()))\n"
        content += "设备: \(UIDevice.current.name)\n"
        content += "系统: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n"
        content += "=============================\n\n"

        for file in getLogFiles() {
            if let fileContent = try? String(contentsOf: file, encoding: .utf8) {
                content += "--- \(file.lastPathComponent) ---\n"
                content += fileContent
                content += "\n\n"
            }
        }

        do {
            try content.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            return nil
        }
    }

    /// 获取当前日志文件大小
    var currentLogSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? Int64 else {
            return "0 B"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 获取所有日志总大小
    var totalLogSize: String {
        var total: Int64 = 0

        for file in getLogFiles() {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    // MARK: - 性能监控

    /// 测量操作执行时间
    func measureTime<T>(
        _ label: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = CFAbsoluteTimeGetCurrent() - start

        log(
            level: .debug,
            message: "⏱ \(label) 耗时: \(String(format: "%.3f", duration * 1000))ms",
            file: file,
            function: function,
            line: line
        )

        return result
    }

    /// 异步测量操作执行时间
    func measureTimeAsync<T>(
        _ label: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - start

        log(
            level: .debug,
            message: "⏱ \(label) 耗时: \(String(format: "%.3f", duration * 1000))ms",
            file: file,
            function: function,
            line: line
        )

        return result
    }
}

// MARK: - 全局便捷方法

/// 全局日志实例
let log = Logger.shared
