//
//  DiaryService.swift
//  pinghu12250
//
//  日记服务 - 处理日记 API 调用
//

import Foundation
import Combine

@MainActor
class DiaryService: ObservableObject {
    static let shared = DiaryService()

    // MARK: - 状态

    @Published var diaries: [DiaryData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMore = true
    @Published var total = 0

    private let pageSize = 20

    // MARK: - 加载日记列表

    func loadDiaries(refresh: Bool = false, mood: String? = nil) async {
        // 防止重复请求
        if isLoading && !refresh { return }

        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }

        isLoading = true
        errorMessage = nil

        // 捕获当前值用于后台任务
        let page = currentPage
        let limit = pageSize
        let moodFilter = mood

        // 网络请求在后台线程执行，不阻塞 MainActor
        let result: Result<DiaryListResponse, Error> = await Task.detached(priority: .userInitiated) {
            var params: [String: String] = [
                "page": "\(page)",
                "limit": "\(limit)"
            ]
            if let mood = moodFilter {
                params["mood"] = mood
            }

            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endpoint = "\(APIConfig.Endpoints.diaries)?\(queryString)"

            do {
                let response: DiaryListResponse = try await APIService.shared.get(endpoint)
                return .success(response)
            } catch {
                return .failure(error)
            }
        }.value

        // UI 更新在 MainActor 上（当前已在 MainActor）
        switch result {
        case .success(let response):
            if refresh {
                diaries = response.diaries
            } else {
                diaries.append(contentsOf: response.diaries)
            }

            if let pagination = response.pagination {
                total = pagination.total
                hasMore = currentPage < pagination.totalPages
            } else {
                hasMore = response.diaries.count >= pageSize
            }

            currentPage += 1
            errorMessage = nil

        case .failure(let error):
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(_, let message):
                    errorMessage = message
                default:
                    errorMessage = apiError.localizedDescription
                }
            } else {
                errorMessage = "加载失败：\(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // MARK: - 创建日记

    func createDiary(
        title: String,
        content: String,
        mood: String?,
        weather: String?,
        tags: [String]? = nil,
        isPublic: Bool = false
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = CreateDiaryRequest(
                title: title,
                content: content,
                mood: mood,
                weather: weather,
                tags: tags,
                price: nil,
                diaryDate: ISO8601DateFormatter().string(from: Date()).prefix(10).description,
                isPublic: isPublic
            )

            let _: DiaryDetailResponse = try await APIService.shared.post(
                APIConfig.Endpoints.diaries,
                body: request
            )

            // 刷新列表
            await loadDiaries(refresh: true)
            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "创建失败：\(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 更新日记

    func updateDiary(
        id: String,
        title: String?,
        content: String?,
        mood: String?,
        weather: String?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = UpdateDiaryRequest(
                title: title,
                content: content,
                mood: mood,
                weather: weather,
                tags: nil,
                price: nil,
                diaryDate: nil,
                isPublic: nil
            )

            let _: DiaryDetailResponse = try await APIService.shared.put(
                "\(APIConfig.Endpoints.diaries)/\(id)",
                body: request
            )

            // 刷新列表
            await loadDiaries(refresh: true)
            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "更新失败：\(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 删除日记

    func deleteDiary(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let _: EmptyResponse = try await APIService.shared.delete(
                "\(APIConfig.Endpoints.diaries)/\(id)"
            )

            // 从本地列表移除
            diaries.removeAll { $0.id == id }
            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 重置

    func reset() {
        diaries = []
        currentPage = 1
        hasMore = true
        total = 0
        errorMessage = nil
    }
}
