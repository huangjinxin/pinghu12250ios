//
//  ChatImageStorage.swift
//  pinghu12250
//
//  聊天图片存储 - 将图片存入文件系统，避免 UserDefaults 阻塞
//

import UIKit

// MARK: - 聊天图片存储

@MainActor
final class ChatImageStorage {
    static let shared = ChatImageStorage()

    // 存储目录
    private let imagesDirectory: URL

    // 最大图片宽度（用于压缩）
    private let maxImageWidth: CGFloat = 1024

    // 压缩质量
    private let compressionQuality: CGFloat = 0.7

    // 图片保留天数
    private let retentionDays: Int = 30

    private init() {
        // 创建存储目录
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        imagesDirectory = cacheDir.appendingPathComponent("pinghu12250/chat_images", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        // 启动时清理过期图片（异步）
        Task {
            await cleanupOldImages()
        }
    }

    // MARK: - 保存图片

    /// 保存图片到文件系统
    /// - Parameters:
    ///   - image: 要保存的图片
    ///   - id: 图片唯一标识（通常使用 UUID）
    /// - Returns: 文件相对路径（用于存储到 UserDefaults）
    func save(image: UIImage, id: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [self] in
                // 压缩图片
                let compressedImage = compressImage(image)

                guard let data = compressedImage.jpegData(compressionQuality: compressionQuality) else {
                    continuation.resume(returning: nil)
                    return
                }

                // 生成文件名
                let fileName = "\(id).jpg"
                let fileURL = imagesDirectory.appendingPathComponent(fileName)

                do {
                    try data.write(to: fileURL)
                    continuation.resume(returning: fileName)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 同步保存图片（在主线程调用时会阻塞，谨慎使用）
    func saveSync(image: UIImage, id: String) -> String? {
        let compressedImage = compressImage(image)

        guard let data = compressedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }

        let fileName = "\(id).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }

    // MARK: - 加载图片

    /// 异步加载图片
    /// - Parameter path: 文件相对路径
    /// - Returns: 加载的图片
    func load(path: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [self] in
                let fileURL = imagesDirectory.appendingPathComponent(path)

                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    /// 同步加载图片
    func loadSync(path: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(path)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    // MARK: - 删除图片

    /// 删除指定图片
    func delete(path: String) {
        let fileURL = imagesDirectory.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 删除所有图片
    func deleteAll() {
        try? FileManager.default.removeItem(at: imagesDirectory)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 清理过期图片

    /// 清理超过保留期限的图片
    func cleanupOldImages() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .background).async { [self] in
                let fileManager = FileManager.default
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

                guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
                    continuation.resume()
                    return
                }

                for file in files {
                    if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       creationDate < cutoffDate {
                        try? fileManager.removeItem(at: file)
                    }
                }

                continuation.resume()
            }
        }
    }

    // MARK: - 存储大小

    /// 获取图片存储大小
    func getStorageSize() -> Int64 {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            if let size = try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }

    /// 格式化的存储大小
    var formattedStorageSize: String {
        let size = getStorageSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - 私有方法

    /// 压缩图片（nonisolated 以便在后台线程调用）
    nonisolated private func compressImage(_ image: UIImage) -> UIImage {
        let size = image.size

        // 如果图片已经足够小，直接返回
        if size.width <= maxImageWidth {
            return image
        }

        // 计算缩放比例
        let scale = maxImageWidth / size.width
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - 可序列化的图片引用

/// 用于替代直接存储 Base64 的图片引用
struct ImageReference: Codable {
    let id: String
    let path: String
    let createdAt: Date

    init(id: String = UUID().uuidString, path: String) {
        self.id = id
        self.path = path
        self.createdAt = Date()
    }

    /// 从 UIImage 创建引用（同步）
    static func create(from image: UIImage) -> ImageReference? {
        let id = UUID().uuidString
        guard let path = ChatImageStorage.shared.saveSync(image: image, id: id) else {
            return nil
        }
        return ImageReference(id: id, path: path)
    }

    /// 从 UIImage 创建引用（异步）
    static func createAsync(from image: UIImage) async -> ImageReference? {
        let id = UUID().uuidString
        guard let path = await ChatImageStorage.shared.save(image: image, id: id) else {
            return nil
        }
        return ImageReference(id: id, path: path)
    }

    /// 加载图片（异步）
    func loadImage() async -> UIImage? {
        await ChatImageStorage.shared.load(path: path)
    }

    /// 加载图片（同步）
    func loadImageSync() -> UIImage? {
        ChatImageStorage.shared.loadSync(path: path)
    }

    /// 删除图片
    func delete() {
        ChatImageStorage.shared.delete(path: path)
    }
}
