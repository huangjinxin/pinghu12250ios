//
//  TextbookService.swift
//  pinghu12250
//
//  教材服务 - 处理教材相关 API 请求
//

import Foundation
import Combine

/// 教材服务
@MainActor
class TextbookService: ObservableObject {
    static let shared = TextbookService()

    private let apiService = APIService.shared

    @Published var textbooks: [Textbook] = []
    @Published var favorites: [Textbook] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var total: Int = 0  // 教材总数量

    // 分页状态
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMore = true

    // 筛选选项
    @Published var filterOptions: TextbookOptionsResponse?

    // 下载状态
    @Published var downloadingIds: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadedIds: Set<String> = []

    private init() {
        // 加载已下载的教材ID列表
        loadDownloadedIds()
    }

    // MARK: - 获取公开教材列表

    /// 获取教材列表（分页）
    func fetchTextbooks(
        page: Int = 1,
        subject: String? = nil,
        grade: Int? = nil,
        keyword: String? = nil,
        refresh: Bool = false
    ) async {
        if refresh {
            currentPage = 1
            textbooks = []
        }

        isLoading = true
        errorMessage = nil

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: "50")
        ]

        if let subject = subject, !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if let grade = grade {
            queryItems.append(URLQueryItem(name: "grade", value: String(grade)))
        }
        if let keyword = keyword, !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }

        do {
            let response: TextbookListResponse = try await apiService.get(
                APIConfig.Endpoints.textbooks,
                queryItems: queryItems
            )

            if refresh || page == 1 {
                textbooks = response.textbooks
            } else {
                textbooks.append(contentsOf: response.textbooks)
            }

            currentPage = response.page
            totalPages = response.totalPages
            total = response.total  // 更新总数
            hasMore = response.page < response.totalPages

            isLoading = false
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - 加载更多

    /// 加载下一页
    func loadMore() async {
        guard !isLoading && hasMore else { return }
        await fetchTextbooks(page: currentPage + 1)
    }

    // MARK: - 获取筛选选项

    /// 获取筛选选项（科目、年级、学期）
    func fetchFilterOptions() async {
        do {
            let response: TextbookOptionsResponse = try await apiService.get(
                APIConfig.Endpoints.textbookOptions
            )
            filterOptions = response
        } catch {
            // 静默失败，使用默认选项
        }
    }

    // MARK: - 获取教材详情

    /// 获取单个教材详情
    func fetchTextbookDetail(id: String) async -> Textbook? {
        do {
            let textbook: Textbook = try await apiService.get(
                "\(APIConfig.Endpoints.textbookDetail)/\(id)"
            )
            return textbook
        } catch {
            errorMessage = "获取详情失败"
            return nil
        }
    }

    // MARK: - 收藏管理

    /// 获取收藏列表
    func fetchFavorites() async {
        guard apiService.isAuthenticated else { return }

        do {
            let response: TextbookFavoritesResponse = try await apiService.get(APIConfig.Endpoints.textbookFavorites)
            favorites = response.favorites.compactMap { $0.textbook }
        } catch {
            // 静默失败
        }
    }

    /// 添加收藏
    func addFavorite(textbookId: String) async -> Bool {
        do {
            let _: [String: String] = try await apiService.post(
                "\(APIConfig.Endpoints.textbookFavorites)/\(textbookId)"
            )
            await fetchFavorites()
            return true
        } catch {
            return false
        }
    }

    /// 移除收藏
    func removeFavorite(textbookId: String) async -> Bool {
        do {
            let _: [String: String] = try await apiService.delete(
                "\(APIConfig.Endpoints.textbookFavorites)/\(textbookId)"
            )
            favorites.removeAll { $0.id == textbookId }
            return true
        } catch {
            return false
        }
    }

    /// 检查是否已收藏
    func isFavorite(textbookId: String) -> Bool {
        favorites.contains { $0.id == textbookId }
    }

    // MARK: - 下载管理

    /// 本地存储目录
    private var localStorageDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let textbooksDir = documentsPath.appendingPathComponent("Textbooks", isDirectory: true)
        // 确保目录存在
        try? FileManager.default.createDirectory(at: textbooksDir, withIntermediateDirectories: true)
        return textbooksDir
    }

    /// 获取教材本地文件路径
    func localFilePath(for textbook: Textbook) -> URL {
        let filename = "\(textbook.id)_\(textbook.title.replacingOccurrences(of: "/", with: "_")).\(textbook.isEpub ? "epub" : "pdf")"
        return localStorageDirectory.appendingPathComponent(filename)
    }

    /// 检查教材是否已下载
    func isDownloaded(_ textbook: Textbook) -> Bool {
        downloadedIds.contains(textbook.id)
    }

    /// 加载已下载的教材ID列表
    private func loadDownloadedIds() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: localStorageDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        downloadedIds = Set(files.compactMap { url -> String? in
            let filename = url.lastPathComponent
            // 从文件名提取ID（格式：id_title.pdf）
            if let underscoreIndex = filename.firstIndex(of: "_") {
                return String(filename[..<underscoreIndex])
            }
            return nil
        })
    }

    /// 下载单个教材到本地
    func downloadTextbook(_ textbook: Textbook) async -> Bool {
        // 检查是否有可下载的文件
        guard let remoteURL = textbook.isEpub ? textbook.epubFullURL : textbook.pdfFullURL else {
            errorMessage = "该教材没有可下载的文件"
            return false
        }

        // 检查是否正在下载
        guard !downloadingIds.contains(textbook.id) else {
            return false
        }

        downloadingIds.insert(textbook.id)
        downloadProgress[textbook.id] = 0

        do {
            // 创建下载任务
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "TextbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])
            }

            // 移动到本地存储目录
            let localURL = localFilePath(for: textbook)
            // 如果文件已存在，先删除
            try? FileManager.default.removeItem(at: localURL)
            try FileManager.default.moveItem(at: tempURL, to: localURL)

            // 更新状态
            downloadingIds.remove(textbook.id)
            downloadProgress.removeValue(forKey: textbook.id)
            downloadedIds.insert(textbook.id)

            return true
        } catch {
            downloadingIds.remove(textbook.id)
            downloadProgress.removeValue(forKey: textbook.id)
            errorMessage = "下载失败：\(error.localizedDescription)"
            return false
        }
    }

    /// 批量下载教材
    func downloadTextbooks(_ textbooks: [Textbook]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        for textbook in textbooks {
            // 跳过已下载的
            if isDownloaded(textbook) {
                successCount += 1
                continue
            }
            // 跳过没有文件的
            guard textbook.hasPdf || textbook.hasEpub else {
                failedCount += 1
                continue
            }

            let result = await downloadTextbook(textbook)
            if result {
                successCount += 1
            } else {
                failedCount += 1
            }
        }

        return (successCount, failedCount)
    }

    /// 删除本地教材文件
    func deleteLocalTextbook(_ textbook: Textbook) -> Bool {
        let localURL = localFilePath(for: textbook)
        do {
            try FileManager.default.removeItem(at: localURL)
            downloadedIds.remove(textbook.id)
            return true
        } catch {
            return false
        }
    }

    /// 获取本地存储大小
    func localStorageSize() -> String {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: localStorageDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }

        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        let mb = Double(totalSize) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", mb * 1024)
        }
    }
}
