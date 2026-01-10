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

    private init() {}

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
}
