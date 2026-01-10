//
//  DownloadManager.swift
//  pinghu12250
//
//  专业下载管理器 - 支持后台下载、断点续传、进度显示
//

import Foundation
import Combine

// MARK: - 下载状态

enum DownloadState: Equatable {
    case idle
    case waiting
    case downloading(progress: Double)
    case paused(resumeData: Data?)
    case completed(localURL: URL)
    case failed(error: String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var progress: Double {
        switch self {
        case .downloading(let progress): return progress
        case .completed: return 1.0
        default: return 0.0
        }
    }
}

// MARK: - 下载任务

@MainActor
class DownloadTask: ObservableObject, Identifiable {
    let id: String
    let url: URL
    let fileName: String

    @Published var state: DownloadState = .idle
    @Published var bytesReceived: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var speed: Double = 0 // bytes per second

    var urlSessionTask: URLSessionDownloadTask?
    var resumeData: Data?
    var startTime: Date?
    var lastUpdateTime: Date?
    var lastBytesReceived: Int64 = 0

    init(id: String, url: URL, fileName: String) {
        self.id = id
        self.url = url
        self.fileName = fileName
    }

    var progressText: String {
        let received = ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(received) / \(total)"
    }

    var speedText: String {
        if speed > 0 {
            let speedStr = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
            return "\(speedStr)/s"
        }
        return ""
    }

    var estimatedTimeRemaining: String {
        guard speed > 0, totalBytes > bytesReceived else { return "" }
        let remaining = Double(totalBytes - bytesReceived) / speed
        if remaining < 60 {
            return "\(Int(remaining))秒"
        } else if remaining < 3600 {
            return "\(Int(remaining / 60))分钟"
        } else {
            return "\(Int(remaining / 3600))小时"
        }
    }

    func updateSpeed() {
        let now = Date()
        if let lastUpdate = lastUpdateTime {
            let elapsed = now.timeIntervalSince(lastUpdate)
            if elapsed >= 0.5 { // 每0.5秒更新一次速度
                let bytesInInterval = bytesReceived - lastBytesReceived
                speed = Double(bytesInInterval) / elapsed
                lastBytesReceived = bytesReceived
                lastUpdateTime = now
            }
        } else {
            lastUpdateTime = now
            lastBytesReceived = bytesReceived
        }
    }
}

// MARK: - 下载管理器

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    // MARK: - Published Properties

    @Published var activeTasks: [String: DownloadTask] = [:]
    @Published var isDownloading: Bool = false

    // MARK: - Private Properties

    private var backgroundSession: URLSession!
    private var foregroundSession: URLSession!
    private var completionHandlers: [String: (Result<URL, Error>) -> Void] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]

    // 缓存目录
    private let cacheDirectory: URL
    private let resumeDataDirectory: URL

    // 配置
    private let maxConcurrentDownloads = 3
    private let chunkSize = 65536 // 64KB

    // MARK: - 初始化

    private override init() {
        // 创建缓存目录
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("Downloads", isDirectory: true)
        resumeDataDirectory = cachesDir.appendingPathComponent("ResumeData", isDirectory: true)

        super.init()

        // 确保目录存在
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: resumeDataDirectory, withIntermediateDirectories: true)

        // 配置后台会话
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.pinghu12250.download")
        backgroundConfig.isDiscretionary = false
        backgroundConfig.sessionSendsLaunchEvents = true
        backgroundConfig.timeoutIntervalForRequest = 60
        backgroundConfig.timeoutIntervalForResource = 60 * 60 * 24 // 24小时
        backgroundConfig.httpMaximumConnectionsPerHost = maxConcurrentDownloads

        backgroundSession = URLSession(configuration: backgroundConfig, delegate: self, delegateQueue: nil)

        // 配置前台会话（用于快速下载）
        let foregroundConfig = URLSessionConfiguration.default
        foregroundConfig.timeoutIntervalForRequest = 30
        foregroundConfig.timeoutIntervalForResource = 60 * 60
        foregroundConfig.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        foregroundConfig.urlCache = nil // 禁用缓存，确保下载最新内容

        foregroundSession = URLSession(configuration: foregroundConfig, delegate: self, delegateQueue: nil)

        // 恢复未完成的下载
        restorePendingDownloads()
    }

    // MARK: - 公开接口

    /// 下载文件（带进度和完成回调）
    @MainActor
    func download(
        url: URL,
        fileName: String? = nil,
        useBackground: Bool = false,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> DownloadTask {
        let taskId = generateTaskId(for: url)
        let name = fileName ?? url.lastPathComponent

        // 检查缓存
        let cachedURL = cacheDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            let task = DownloadTask(id: taskId, url: url, fileName: name)
            task.state = .completed(localURL: cachedURL)
            completion(.success(cachedURL))
            return task
        }

        // 检查是否已有相同任务
        if let existingTask = activeTasks[taskId] {
            // 添加新的回调
            if let progress = progress {
                progressHandlers[taskId] = progress
            }
            completionHandlers[taskId] = completion
            return existingTask
        }

        // 创建新任务
        let task = DownloadTask(id: taskId, url: url, fileName: name)
        activeTasks[taskId] = task

        // 保存回调
        if let progress = progress {
            progressHandlers[taskId] = progress
        }
        completionHandlers[taskId] = completion

        // 检查断点续传数据
        let resumeDataURL = resumeDataDirectory.appendingPathComponent(taskId)
        if let resumeData = try? Data(contentsOf: resumeDataURL) {
            resumeDownload(task: task, resumeData: resumeData, useBackground: useBackground)
        } else {
            startDownload(task: task, useBackground: useBackground)
        }

        updateDownloadingState()
        return task
    }

    /// 暂停下载
    @MainActor
    func pause(taskId: String) {
        guard let task = activeTasks[taskId],
              let urlTask = task.urlSessionTask else { return }

        urlTask.cancel { [weak self] resumeData in
            DispatchQueue.main.async {
                task.resumeData = resumeData
                task.state = .paused(resumeData: resumeData)

                // 保存断点数据
                if let data = resumeData {
                    self?.saveResumeData(data, for: taskId)
                }

                self?.updateDownloadingState()
            }
        }
    }

    /// 恢复下载
    @MainActor
    func resume(taskId: String) {
        guard let task = activeTasks[taskId] else { return }

        if let resumeData = task.resumeData {
            resumeDownload(task: task, resumeData: resumeData, useBackground: false)
        } else {
            // 没有断点数据，重新开始
            startDownload(task: task, useBackground: false)
        }

        updateDownloadingState()
    }

    /// 取消下载
    @MainActor
    func cancel(taskId: String) {
        guard let task = activeTasks[taskId] else { return }

        task.urlSessionTask?.cancel()
        task.state = .idle

        // 清理
        activeTasks.removeValue(forKey: taskId)
        completionHandlers.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        deleteResumeData(for: taskId)

        updateDownloadingState()
    }

    /// 获取缓存文件路径
    func getCachedFileURL(for url: URL, fileName: String? = nil) -> URL? {
        let name = fileName ?? url.lastPathComponent
        let cachedURL = cacheDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: cachedURL.path) ? cachedURL : nil
    }

    /// 检查文件是否已缓存
    func isCached(url: URL, fileName: String? = nil) -> Bool {
        return getCachedFileURL(for: url, fileName: fileName) != nil
    }

    /// 清理缓存
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    /// 格式化的缓存大小
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: getCacheSize(), countStyle: .file)
    }

    // MARK: - 私有方法

    private func generateTaskId(for url: URL) -> String {
        return url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }

    private func startDownload(task: DownloadTask, useBackground: Bool) {
        let session = useBackground ? backgroundSession! : foregroundSession!
        var request = URLRequest(url: task.url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let urlTask = session.downloadTask(with: request)
        task.urlSessionTask = urlTask
        task.state = .waiting
        task.startTime = Date()

        urlTask.resume()

        DispatchQueue.main.async {
            task.state = .downloading(progress: 0)
        }
    }

    private func resumeDownload(task: DownloadTask, resumeData: Data, useBackground: Bool) {
        let session = useBackground ? backgroundSession! : foregroundSession!

        let urlTask = session.downloadTask(withResumeData: resumeData)
        task.urlSessionTask = urlTask
        task.state = .waiting
        task.startTime = Date()

        urlTask.resume()

        DispatchQueue.main.async {
            task.state = .downloading(progress: task.state.progress)
        }
    }

    private func saveResumeData(_ data: Data, for taskId: String) {
        let url = resumeDataDirectory.appendingPathComponent(taskId)
        try? data.write(to: url)
    }

    private func deleteResumeData(for taskId: String) {
        let url = resumeDataDirectory.appendingPathComponent(taskId)
        try? FileManager.default.removeItem(at: url)
    }

    private func restorePendingDownloads() {
        backgroundSession.getAllTasks { [weak self] tasks in
            for task in tasks {
                if let downloadTask = task as? URLSessionDownloadTask,
                   let url = downloadTask.originalRequest?.url {
                    let taskId = self?.generateTaskId(for: url) ?? ""

                    DispatchQueue.main.async {
                        let newTask = DownloadTask(id: taskId, url: url, fileName: url.lastPathComponent)
                        newTask.urlSessionTask = downloadTask
                        newTask.state = .downloading(progress: Double(downloadTask.countOfBytesReceived) / max(1, Double(downloadTask.countOfBytesExpectedToReceive)))
                        self?.activeTasks[taskId] = newTask
                    }
                }
            }
        }
    }

    @MainActor
    private func updateDownloadingState() {
        isDownloading = activeTasks.values.contains { $0.state.isDownloading }
    }

    private func findTask(for urlTask: URLSessionTask) -> DownloadTask? {
        guard let url = urlTask.originalRequest?.url else { return nil }
        let taskId = generateTaskId(for: url)
        return activeTasks[taskId]
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let task = findTask(for: downloadTask) else { return }

        let destinationURL = cacheDirectory.appendingPathComponent(task.fileName)

        do {
            // 删除已存在的文件
            try? FileManager.default.removeItem(at: destinationURL)
            // 移动下载的文件到缓存目录
            try FileManager.default.moveItem(at: location, to: destinationURL)

            DispatchQueue.main.async { [weak self] in
                task.state = .completed(localURL: destinationURL)
                task.bytesReceived = task.totalBytes

                // 清理断点数据
                self?.deleteResumeData(for: task.id)

                // 调用完成回调
                self?.completionHandlers[task.id]?(.success(destinationURL))
                self?.completionHandlers.removeValue(forKey: task.id)
                self?.progressHandlers.removeValue(forKey: task.id)

                // 从活动任务中移除（延迟一会，让UI有时间显示完成状态）
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.activeTasks.removeValue(forKey: task.id)
                    self?.updateDownloadingState()
                }
            }

            #if DEBUG
            print("下载完成: \(destinationURL.path)")
            #endif

        } catch {
            DispatchQueue.main.async { [weak self] in
                task.state = .failed(error: error.localizedDescription)
                self?.completionHandlers[task.id]?(.failure(error))
                self?.completionHandlers.removeValue(forKey: task.id)
                self?.progressHandlers.removeValue(forKey: task.id)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let task = findTask(for: downloadTask) else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        DispatchQueue.main.async { [weak self] in
            task.bytesReceived = totalBytesWritten
            task.totalBytes = totalBytesExpectedToWrite
            task.state = .downloading(progress: progress)
            task.updateSpeed()

            // 调用进度回调
            self?.progressHandlers[task.id]?(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }

        guard let downloadTask = findTask(for: task) else { return }

        // 检查是否是取消错误，并尝试获取断点数据
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled {
            if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                DispatchQueue.main.async { [weak self] in
                    downloadTask.resumeData = resumeData
                    downloadTask.state = .paused(resumeData: resumeData)
                    self?.saveResumeData(resumeData, for: downloadTask.id)
                }
                return
            }
        }

        DispatchQueue.main.async { [weak self] in
            downloadTask.state = .failed(error: error.localizedDescription)
            self?.completionHandlers[downloadTask.id]?(.failure(error))
            self?.completionHandlers.removeValue(forKey: downloadTask.id)
            self?.progressHandlers.removeValue(forKey: downloadTask.id)
            self?.updateDownloadingState()
        }
    }

    // 后台下载完成
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            // 通知 AppDelegate 后台下载完成
            NotificationCenter.default.post(name: .downloadManagerDidFinishBackgroundEvents, object: nil)
        }
    }
}

// MARK: - URLSessionDelegate

extension DownloadManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            #if DEBUG
            print("URLSession 失效: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let downloadManagerDidFinishBackgroundEvents = Notification.Name("downloadManagerDidFinishBackgroundEvents")
}

// MARK: - 便捷扩展

extension DownloadManager {
    /// 下载 PDF 并返回本地 URL（async/await 版本）
    @MainActor
    func downloadPDF(url: URL, textbookId: String) async throws -> URL {
        let fileName = "textbook_\(textbookId).pdf"

        // 检查缓存
        if let cachedURL = getCachedFileURL(for: url, fileName: fileName) {
            return cachedURL
        }

        // 使用 withCheckedThrowingContinuation 包装回调式 API
        return try await withCheckedThrowingContinuation { continuation in
            let _ = download(url: url, fileName: fileName) { result in
                switch result {
                case .success(let localURL):
                    continuation.resume(returning: localURL)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 下载 PDF 并获取实时任务（用于显示进度）
    @MainActor
    func downloadPDFWithProgress(url: URL, textbookId: String) -> DownloadTask {
        let fileName = "textbook_\(textbookId).pdf"

        // 检查缓存
        if let cachedURL = getCachedFileURL(for: url, fileName: fileName) {
            let task = DownloadTask(id: textbookId, url: url, fileName: fileName)
            task.state = .completed(localURL: cachedURL)
            return task
        }

        return download(url: url, fileName: fileName) { _ in }
    }

    // MARK: - 教材下载状态管理

    /// 检查教材是否已下载
    func isTextbookDownloaded(_ textbookId: String) -> Bool {
        let fileName = "textbook_\(textbookId).pdf"
        let cachedURL = cacheDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: cachedURL.path)
    }

    /// 获取教材的下载状态
    @MainActor
    func getTextbookDownloadState(_ textbookId: String, pdfURL: URL?) -> TextbookDownloadState {
        let fileName = "textbook_\(textbookId).pdf"

        // 检查是否已缓存
        let cachedURL = cacheDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return .downloaded
        }

        // 检查是否正在下载
        if let url = pdfURL {
            let taskId = generateTaskId(for: url)
            if let task = activeTasks[taskId] {
                switch task.state {
                case .downloading(let progress):
                    return .downloading(progress: progress)
                case .waiting:
                    return .downloading(progress: 0)
                case .paused:
                    return .paused
                case .failed:
                    return .failed
                default:
                    break
                }
            }
        }

        return .notDownloaded
    }

    /// 获取教材下载任务（如果正在下载）
    @MainActor
    func getTextbookDownloadTask(_ textbookId: String, pdfURL: URL) -> DownloadTask? {
        let taskId = generateTaskId(for: pdfURL)
        return activeTasks[taskId]
    }

    /// 批量下载教材
    @MainActor
    func downloadTextbooks(_ textbooks: [(id: String, url: URL)], useBackground: Bool = true) -> [DownloadTask] {
        var tasks: [DownloadTask] = []

        for textbook in textbooks {
            // 跳过已下载的
            if isTextbookDownloaded(textbook.id) {
                continue
            }

            let task = download(
                url: textbook.url,
                fileName: "textbook_\(textbook.id).pdf",
                useBackground: useBackground
            ) { _ in }

            tasks.append(task)
        }

        return tasks
    }

    /// 获取所有正在下载的教材任务
    @MainActor
    var activeTextbookTasks: [DownloadTask] {
        activeTasks.values.filter { $0.fileName.hasPrefix("textbook_") }
    }

    /// 正在下载的教材数量
    @MainActor
    var downloadingTextbookCount: Int {
        activeTextbookTasks.filter { $0.state.isDownloading }.count
    }
}

// MARK: - 教材下载状态枚举

enum TextbookDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case paused
    case downloaded
    case failed

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}
