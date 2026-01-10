//
//  AnnotationStorageService.swift
//  pinghu12250
//
//  批注存储服务 - JSON 文件存储
//  存储路径: ~/Documents/annotations/{userId}/{textbookId}.json
//

import Foundation

@MainActor
final class AnnotationStorageService {

    // MARK: - Singleton

    static let shared = AnnotationStorageService()
    private init() {}

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // 内存缓存
    private var cache: [String: UserAnnotationDocument] = [:]

    // MARK: - Public API

    /// 加载用户的批注文档
    func loadDocument(userId: String, textbookId: String) -> UserAnnotationDocument {
        let cacheKey = "\(userId)_\(textbookId)"

        // 检查缓存
        if let cached = cache[cacheKey] {
            return cached
        }

        // 从文件加载
        let url = documentURL(userId: userId, textbookId: textbookId)

        guard fileManager.fileExists(atPath: url.path) else {
            // 创建新文档
            let newDoc = UserAnnotationDocument(userId: userId, textbookId: textbookId)
            cache[cacheKey] = newDoc
            return newDoc
        }

        do {
            let data = try Data(contentsOf: url)
            let document = try decoder.decode(UserAnnotationDocument.self, from: data)
            cache[cacheKey] = document
            #if DEBUG
            print("[AnnotationStorage] 加载批注文档: \(document.annotations.count) 条")
            #endif
            return document
        } catch {
            #if DEBUG
            print("[AnnotationStorage] 加载失败: \(error)")
            #endif
            // 返回新文档
            let newDoc = UserAnnotationDocument(userId: userId, textbookId: textbookId)
            cache[cacheKey] = newDoc
            return newDoc
        }
    }

    /// 保存用户的批注文档
    func saveDocument(_ document: UserAnnotationDocument) throws {
        let cacheKey = "\(document.userId)_\(document.textbookId)"
        let url = documentURL(userId: document.userId, textbookId: document.textbookId)

        // 确保目录存在
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // 编码并写入
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)

        // 更新缓存
        cache[cacheKey] = document

        #if DEBUG
        print("[AnnotationStorage] 保存批注文档: \(document.annotations.count) 条")
        #endif
    }

    /// 更新缓存中的文档（不写入文件）
    func updateCache(userId: String, textbookId: String, document: UserAnnotationDocument) {
        let cacheKey = "\(userId)_\(textbookId)"
        cache[cacheKey] = document
    }

    /// 获取缓存的文档
    func getCached(userId: String, textbookId: String) -> UserAnnotationDocument? {
        let cacheKey = "\(userId)_\(textbookId)"
        return cache[cacheKey]
    }

    /// 清除缓存
    func clearCache() {
        cache.removeAll()
    }

    /// 删除用户的批注文档
    func deleteDocument(userId: String, textbookId: String) throws {
        let cacheKey = "\(userId)_\(textbookId)"
        let url = documentURL(userId: userId, textbookId: textbookId)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        cache.removeValue(forKey: cacheKey)

        #if DEBUG
        print("[AnnotationStorage] 删除批注文档: \(textbookId)")
        #endif
    }

    /// 获取用户的所有批注文档
    func listDocuments(userId: String) -> [String] {
        let directory = userDirectory(userId: userId)

        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    // MARK: - Private

    private func documentURL(userId: String, textbookId: String) -> URL {
        userDirectory(userId: userId)
            .appendingPathComponent("\(textbookId).json")
    }

    private func userDirectory(userId: String) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory
            .appendingPathComponent("annotations", isDirectory: true)
            .appendingPathComponent(userId, isDirectory: true)
    }
}

// MARK: - 增量保存辅助

extension AnnotationStorageService {

    /// 添加单条批注并保存
    func addAndSave(
        stroke: InkStrokeData,
        userId: String,
        textbookId: String
    ) throws {
        var document = loadDocument(userId: userId, textbookId: textbookId)
        document.addAnnotation(stroke)
        try saveDocument(document)
    }

    /// 移除单条批注并保存
    func removeAndSave(
        strokeId: String,
        userId: String,
        textbookId: String
    ) throws {
        var document = loadDocument(userId: userId, textbookId: textbookId)
        document.removeAnnotation(id: strokeId)
        try saveDocument(document)
    }
}

// MARK: - XFDF 迁移支持

extension AnnotationStorageService {

    /// 检查是否存在旧的 JSON 格式批注（且尚未迁移到 XFDF）
    func needsMigrationToXFDF(userId: String, textbookId: String) -> Bool {
        let jsonURL = documentURL(userId: userId, textbookId: textbookId)
        let xfdfURL = XFDFAnnotationService.shared.xfdfURL(userId: userId, textbookId: textbookId)

        let jsonExists = fileManager.fileExists(atPath: jsonURL.path)
        let xfdfExists = fileManager.fileExists(atPath: xfdfURL.path)

        // 如果 JSON 存在但 XFDF 不存在，需要迁移
        return jsonExists && !xfdfExists
    }

    /// 检查旧 JSON 格式是否存在
    func jsonDocumentExists(userId: String, textbookId: String) -> Bool {
        let url = documentURL(userId: userId, textbookId: textbookId)
        return fileManager.fileExists(atPath: url.path)
    }

    /// 标记迁移完成（可选：备份并删除旧 JSON 文件）
    func markMigrationComplete(userId: String, textbookId: String, deleteJSON: Bool = false) {
        if deleteJSON {
            let jsonURL = documentURL(userId: userId, textbookId: textbookId)
            if fileManager.fileExists(atPath: jsonURL.path) {
                // 备份到 .json.bak
                let backupURL = jsonURL.appendingPathExtension("bak")
                try? fileManager.moveItem(at: jsonURL, to: backupURL)

                #if DEBUG
                print("[AnnotationStorage] 已备份旧 JSON 文件: \(backupURL.lastPathComponent)")
                #endif
            }
        }

        // 清除缓存
        let cacheKey = "\(userId)_\(textbookId)"
        cache.removeValue(forKey: cacheKey)
    }

    /// 获取所有需要迁移的教材 ID
    func getTextbooksNeedingMigration(userId: String) -> [String] {
        let jsonFiles = listDocuments(userId: userId)
        let xfdfService = XFDFAnnotationService.shared

        return jsonFiles.filter { textbookId in
            !xfdfService.xfdfExists(userId: userId, textbookId: textbookId)
        }
    }
}
