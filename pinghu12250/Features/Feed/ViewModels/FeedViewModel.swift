//
//  FeedViewModel.swift
//  pinghu12250
//
//  学习圈业务逻辑
//

import Foundation
import Combine

class FeedViewModel: ObservableObject {
    @Published var items: [UnifiedFeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    private var page = 1

    func loadFeed() async {
        await MainActor.run {
            isLoading = true
            page = 1
            hasMore = true
        }

        do {
            let response: UnifiedFeedResponse = try await APIService.shared.get("/public/unified-feed?page=1&limit=20")
            await MainActor.run {
                items = response.data?.items ?? []
                hasMore = (response.data?.pagination.page ?? 1) < (response.data?.pagination.totalPages ?? 1)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        await MainActor.run {
            isLoadingMore = true
            page += 1
        }

        do {
            let response: UnifiedFeedResponse = try await APIService.shared.get("/public/unified-feed?page=\(page)&limit=20")
            await MainActor.run {
                items.append(contentsOf: response.data?.items ?? [])
                hasMore = (response.data?.pagination.page ?? 1) < (response.data?.pagination.totalPages ?? 1)
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
}

// MARK: - 图片URL工具

enum ImageURLHelper {
    static func fullURL(_ path: String?) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let server = APIConfig.baseURL.replacingOccurrences(of: "/api", with: "")
        return URL(string: server + path)
    }
}
