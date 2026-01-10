//
//  CacheService.swift
//  pinghu12250
//
//  离线缓存服务 - 管理PDF、图片、数据的本地缓存
//

import Foundation
import SwiftUI
import Combine

/// 缓存服务 - 单例
@MainActor
class CacheService: ObservableObject {
    static let shared = CacheService()

    // MARK: - 缓存目录

    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("pinghu12250")
    }

    private var pdfCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("pdfs")
    }

    private var imageCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("images")
    }

    private var dataCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("data")
    }

    private var poetryCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("poetry")
    }

    private var epubCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("epubs")
    }

    // MARK: - 状态

    @Published var downloadingItems: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var cachedTextbookIds: Set<String> = []
    @Published var cachedPoetryIds: Set<String> = []
    @Published var cachedEpubIds: Set<String> = []

    // MARK: - 初始化

    private init() {
        createCacheDirectories()
        loadCachedItemIds()
    }

    private func createCacheDirectories() {
        let directories = [pdfCacheDirectory, imageCacheDirectory, dataCacheDirectory, poetryCacheDirectory, epubCacheDirectory]
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    private func loadCachedItemIds() {
        // 加载已缓存的教材ID（PDF）
        if let files = try? fileManager.contentsOfDirectory(atPath: pdfCacheDirectory.path) {
            for file in files where file.hasPrefix("textbook_") && file.hasSuffix(".pdf") {
                let id = file.replacingOccurrences(of: "textbook_", with: "")
                    .replacingOccurrences(of: ".pdf", with: "")
                cachedTextbookIds.insert(id)
            }
        }

        // 加载已缓存的诗词ID
        if let files = try? fileManager.contentsOfDirectory(atPath: poetryCacheDirectory.path) {
            for file in files where file.hasSuffix(".json") {
                let id = file.replacingOccurrences(of: ".json", with: "")
                cachedPoetryIds.insert(id)
            }
        }

        // 加载已缓存的EPUB ID
        if let files = try? fileManager.contentsOfDirectory(atPath: epubCacheDirectory.path) {
            for file in files where file.hasPrefix("epub_") {
                // 格式: epub_textbookId/
                let id = file.replacingOccurrences(of: "epub_", with: "")
                cachedEpubIds.insert(id)
            }
        }
    }

    // MARK: - PDF 缓存

    /// 检查PDF是否已缓存
    func isPDFCached(textbookId: String) -> Bool {
        cachedTextbookIds.contains(textbookId)
    }

    /// 获取缓存的PDF路径
    func cachedPDFPath(textbookId: String) -> URL? {
        let path = pdfCacheDirectory.appendingPathComponent("textbook_\(textbookId).pdf")
        return fileManager.fileExists(atPath: path.path) ? path : nil
    }

    /// 下载并缓存PDF
    func downloadPDF(textbookId: String, pdfUrl: String) async throws -> URL {
        guard let url = URL(string: pdfUrl) else {
            throw CacheError.invalidURL
        }

        // 检查是否已缓存
        if let cachedPath = cachedPDFPath(textbookId: textbookId) {
            return cachedPath
        }

        // 标记为正在下载
        downloadingItems.insert(textbookId)
        downloadProgress[textbookId] = 0

        defer {
            downloadingItems.remove(textbookId)
            downloadProgress.removeValue(forKey: textbookId)
        }

        // 下载文件
        let (data, _) = try await URLSession.shared.data(from: url)

        // 保存到缓存
        let localPath = pdfCacheDirectory.appendingPathComponent("textbook_\(textbookId).pdf")
        try data.write(to: localPath)

        cachedTextbookIds.insert(textbookId)
        downloadProgress[textbookId] = 1.0

        return localPath
    }

    /// 删除缓存的PDF
    func deleteCachedPDF(textbookId: String) {
        let path = pdfCacheDirectory.appendingPathComponent("textbook_\(textbookId).pdf")
        try? fileManager.removeItem(at: path)
        cachedTextbookIds.remove(textbookId)
    }

    // MARK: - EPUB 缓存

    /// 检查EPUB是否已缓存
    func isEPUBCached(textbookId: String) -> Bool {
        cachedEpubIds.contains(textbookId)
    }

    /// 获取EPUB缓存目录
    func cachedEPUBDirectory(textbookId: String) -> URL? {
        let path = epubCacheDirectory.appendingPathComponent("epub_\(textbookId)")
        return fileManager.fileExists(atPath: path.path) ? path : nil
    }

    /// 缓存EPUB章节HTML
    func cacheEPUBChapter(textbookId: String, chapterId: String, html: String) {
        let epubDir = epubCacheDirectory.appendingPathComponent("epub_\(textbookId)")

        // 创建目录
        if !fileManager.fileExists(atPath: epubDir.path) {
            try? fileManager.createDirectory(at: epubDir, withIntermediateDirectories: true)
        }

        // 保存章节HTML
        let chapterPath = epubDir.appendingPathComponent("\(chapterId).html")
        try? html.write(to: chapterPath, atomically: true, encoding: .utf8)

        // 标记为已缓存
        cachedEpubIds.insert(textbookId)
    }

    /// 获取缓存的EPUB章节
    func getCachedEPUBChapter(textbookId: String, chapterId: String) -> String? {
        let chapterPath = epubCacheDirectory
            .appendingPathComponent("epub_\(textbookId)")
            .appendingPathComponent("\(chapterId).html")

        return try? String(contentsOf: chapterPath, encoding: .utf8)
    }

    /// 检查EPUB章节是否已缓存
    func isEPUBChapterCached(textbookId: String, chapterId: String) -> Bool {
        let chapterPath = epubCacheDirectory
            .appendingPathComponent("epub_\(textbookId)")
            .appendingPathComponent("\(chapterId).html")

        return fileManager.fileExists(atPath: chapterPath.path)
    }

    /// 删除缓存的EPUB
    func deleteCachedEPUB(textbookId: String) {
        let path = epubCacheDirectory.appendingPathComponent("epub_\(textbookId)")
        try? fileManager.removeItem(at: path)
        cachedEpubIds.remove(textbookId)
    }

    /// 检查教材是否已缓存（统一方法，支持PDF和EPUB）
    func isTextbookCached(textbookId: String, isEpub: Bool) -> Bool {
        if isEpub {
            return isEPUBCached(textbookId: textbookId)
        } else {
            return isPDFCached(textbookId: textbookId)
        }
    }

    // MARK: - 诗词缓存

    /// 检查诗词是否已缓存
    func isPoetryCached(poetryId: String) -> Bool {
        cachedPoetryIds.contains(poetryId)
    }

    /// 获取缓存的诗词数据
    func getCachedPoetry<T: Decodable>(poetryId: String, type: T.Type) -> T? {
        let path = poetryCacheDirectory.appendingPathComponent("\(poetryId).json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 缓存诗词数据
    func cachePoetry<T: Encodable>(poetryId: String, data: T) throws {
        let path = poetryCacheDirectory.appendingPathComponent("\(poetryId).json")
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: path)
        cachedPoetryIds.insert(poetryId)
    }

    /// 缓存诗词列表
    func cachePoetryList<T: Encodable>(data: T) throws {
        let path = poetryCacheDirectory.appendingPathComponent("poetry_list.json")
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: path)
    }

    /// 获取缓存的诗词列表
    func getCachedPoetryList<T: Decodable>(type: T.Type) -> T? {
        let path = poetryCacheDirectory.appendingPathComponent("poetry_list.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 删除缓存的诗词
    func deleteCachedPoetry(poetryId: String) {
        let path = poetryCacheDirectory.appendingPathComponent("\(poetryId).json")
        try? fileManager.removeItem(at: path)
        cachedPoetryIds.remove(poetryId)
    }

    // MARK: - 通用数据缓存

    /// 缓存数据
    func cacheData<T: Encodable>(key: String, data: T, expiresIn: TimeInterval? = nil) throws {
        let cacheItem = CacheItem(
            data: try JSONEncoder().encode(data),
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) }
        )
        let path = dataCacheDirectory.appendingPathComponent("\(key).cache")
        let encoded = try JSONEncoder().encode(cacheItem)
        try encoded.write(to: path)
    }

    /// 获取缓存数据
    func getCachedData<T: Decodable>(key: String, type: T.Type) -> T? {
        let path = dataCacheDirectory.appendingPathComponent("\(key).cache")
        guard let cacheData = try? Data(contentsOf: path),
              let cacheItem = try? JSONDecoder().decode(CacheItem.self, from: cacheData) else {
            return nil
        }

        // 检查是否过期
        if let expiresAt = cacheItem.expiresAt, Date() > expiresAt {
            try? fileManager.removeItem(at: path)
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: cacheItem.data)
    }

    /// 删除缓存数据
    func removeCachedData(key: String) {
        let path = dataCacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: path)
    }

    // MARK: - 图片缓存

    /// 获取缓存的图片
    func getCachedImage(url: String) -> UIImage? {
        let filename = url.md5Hash + ".img"
        let path = imageCacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    /// 缓存图片
    func cacheImage(url: String, image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = url.md5Hash + ".img"
        let path = imageCacheDirectory.appendingPathComponent(filename)
        try? data.write(to: path)
    }

    /// 下载并缓存图片
    func downloadImage(url: String) async -> UIImage? {
        // 处理 base64 data URL
        if url.hasPrefix("data:image") {
            return decodeBase64Image(dataURL: url)
        }

        // 先检查缓存
        if let cached = getCachedImage(url: url) {
            return cached
        }

        // 下载图片
        guard let imageUrl = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: imageUrl),
              let image = UIImage(data: data) else {
            return nil
        }

        // 缓存图片
        cacheImage(url: url, image: image)
        return image
    }

    /// 解码 base64 data URL 为 UIImage
    private func decodeBase64Image(dataURL: String) -> UIImage? {
        // 格式: data:image/jpeg;base64,/9j/4AAQSkZJRg...
        guard let commaIndex = dataURL.firstIndex(of: ",") else {
            return nil
        }
        let base64String = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - 缓存统计

    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        let directories = [pdfCacheDirectory, imageCacheDirectory, dataCacheDirectory, poetryCacheDirectory]

        for directory in directories {
            if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }

        return totalSize
    }

    /// 格式化缓存大小
    func formattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 清除所有缓存
    func clearAllCache() {
        let directories = [pdfCacheDirectory, imageCacheDirectory, dataCacheDirectory, poetryCacheDirectory]
        for directory in directories {
            try? fileManager.removeItem(at: directory)
        }
        createCacheDirectories()
        cachedTextbookIds.removeAll()
        cachedPoetryIds.removeAll()
    }

    /// 清除过期缓存
    func clearExpiredCache() {
        // 清除过期的数据缓存
        if let files = try? fileManager.contentsOfDirectory(atPath: dataCacheDirectory.path) {
            for file in files where file.hasSuffix(".cache") {
                let path = dataCacheDirectory.appendingPathComponent(file)
                if let data = try? Data(contentsOf: path),
                   let cacheItem = try? JSONDecoder().decode(CacheItem.self, from: data),
                   let expiresAt = cacheItem.expiresAt,
                   Date() > expiresAt {
                    try? fileManager.removeItem(at: path)
                }
            }
        }
    }
}

// MARK: - 缓存项

private struct CacheItem: Codable {
    let data: Data
    let expiresAt: Date?
}

// MARK: - 缓存错误

enum CacheError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case saveFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .downloadFailed: return "下载失败"
        case .saveFailed: return "保存失败"
        case .notFound: return "缓存不存在"
        }
    }
}

// MARK: - String MD5 扩展

import CommonCrypto

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
