//
//  DiaryAIService.swift
//  pinghu12250
//
//  日记 AI 分析服务 - 处理 AI 分析相关的 API 调用
//

import Foundation
import SwiftUI
import Combine

@MainActor
class DiaryAIService: ObservableObject {
    static let shared = DiaryAIService()

    // MARK: - Published Properties

    /// 分析历史记录列表
    @Published var analysisHistory: [DiaryAnalysisData] = []

    /// 是否正在加载历史
    @Published var isLoadingHistory = false

    /// 是否正在进行 AI 分析
    @Published var isAnalyzing = false

    /// 当前分析的类型（用于显示加载状态）
    @Published var analyzingType: AnalyzingType?

    /// 当前的加载文本
    @Published var loadingText: String = "AI 正在分析中..."

    /// 错误信息
    @Published var errorMessage: String?

    /// 当前分析结果
    @Published var currentAnalysisResult: AnalysisResult?

    /// 分页信息
    @Published var historyPage = 1
    @Published var historyTotal = 0
    @Published var historyHasMore = true

    // MARK: - Types

    enum AnalyzingType: Equatable {
        case single(diaryId: String)
        case thisWeek
        case lastWeek
    }

    struct AnalysisResult {
        let isBatch: Bool
        let diary: DiaryData?
        let analysis: String
        let period: String?
        let diaryCount: Int
        let responseTime: Int?
        let modelName: String?
        let tokensUsed: Int?
    }

    // MARK: - Private Properties

    private let pageSize = 20
    private var loadingTextTimer: Timer?

    private init() {}

    // MARK: - Loading Text Animation

    func startLoadingTextAnimation() {
        loadingText = DiaryAILoadingTexts.random()
        loadingTextTimer?.invalidate()
        loadingTextTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadingText = DiaryAILoadingTexts.random()
            }
        }
    }

    func stopLoadingTextAnimation() {
        loadingTextTimer?.invalidate()
        loadingTextTimer = nil
    }

    // MARK: - Single Diary Analysis

    /// 分析单条日记
    func analyzeDiary(_ diary: DiaryData) async -> Bool {
        isAnalyzing = true
        analyzingType = .single(diaryId: diary.id)
        errorMessage = nil
        startLoadingTextAnimation()

        defer {
            isAnalyzing = false
            analyzingType = nil
            stopLoadingTextAnimation()
        }

        do {
            let request = AnalyzeDiaryRequest(
                diaryId: diary.id,
                content: diary.content,
                title: diary.title,
                mood: diary.mood,
                weather: diary.weather,
                createdAt: diary.createdAt
            )

            // 使用长超时的请求方法（AI推理需要较长时间）
            let response: DiaryAnalysisResponse = try await APIService.shared.postWithLongTimeout(
                "/ai-analysis/diary/analyze",
                body: request
            )

            if response.success, let data = response.data {
                currentAnalysisResult = AnalysisResult(
                    isBatch: false,
                    diary: diary,
                    analysis: data.analysis,
                    period: nil,
                    diaryCount: 1,
                    responseTime: data.responseTime,
                    modelName: data.modelName,
                    tokensUsed: data.tokensUsed
                )

                // 自动保存到历史记录
                await saveAnalysisRecord(
                    isBatch: false,
                    period: nil,
                    diaryId: diary.id,
                    diaryIds: nil,
                    diaryCount: 1,
                    snapshot: DiarySnapshotItem(
                        title: diary.title,
                        content: diary.content,
                        mood: diary.mood,
                        weather: diary.weather,
                        createdAt: diary.createdAt
                    ),
                    analysis: data.analysis,
                    modelName: data.modelName,
                    tokensUsed: data.tokensUsed,
                    responseTime: data.responseTime
                )

                return true
            } else {
                errorMessage = response.error ?? "分析失败"
                return false
            }
        } catch {
            errorMessage = "分析请求失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Batch Diary Analysis

    /// 批量分析日记（本周/上周）
    func analyzeBatch(period: String, diaries: [DiaryData]) async -> Bool {
        guard !diaries.isEmpty else {
            errorMessage = period == "this_week" ? "本周还没有日记" : "上周没有日记"
            return false
        }

        isAnalyzing = true
        analyzingType = period == "this_week" ? .thisWeek : .lastWeek
        errorMessage = nil
        startLoadingTextAnimation()

        defer {
            isAnalyzing = false
            analyzingType = nil
            stopLoadingTextAnimation()
        }

        do {
            let batchItems = diaries.map { diary in
                DiaryBatchItem(
                    title: diary.title,
                    content: diary.content,
                    mood: diary.mood,
                    weather: diary.weather,
                    createdAt: diary.createdAt
                )
            }

            let request = AnalyzeDiariesBatchRequest(diaries: batchItems, period: period)

            // 使用长超时的请求方法（批量AI分析需要较长时间）
            let response: DiaryAnalysisResponse = try await APIService.shared.postWithLongTimeout(
                "/ai-analysis/diary/analyze-batch",
                body: request
            )

            if response.success, let data = response.data {
                let periodText = period == "this_week" ? "本周" : "上周"

                currentAnalysisResult = AnalysisResult(
                    isBatch: true,
                    diary: nil,
                    analysis: data.analysis,
                    period: periodText,
                    diaryCount: diaries.count,
                    responseTime: data.responseTime,
                    modelName: data.modelName,
                    tokensUsed: data.tokensUsed
                )

                // 自动保存到历史记录
                let snapshots = diaries.map { diary in
                    DiarySnapshotItem(
                        title: diary.title,
                        content: diary.content,
                        mood: diary.mood,
                        weather: diary.weather,
                        createdAt: diary.createdAt
                    )
                }

                await saveAnalysisRecord(
                    isBatch: true,
                    period: periodText,
                    diaryId: nil,
                    diaryIds: diaries.map { $0.id },
                    diaryCount: diaries.count,
                    snapshots: snapshots,
                    analysis: data.analysis,
                    modelName: data.modelName,
                    tokensUsed: data.tokensUsed,
                    responseTime: data.responseTime
                )

                return true
            } else {
                errorMessage = response.error ?? "分析失败"
                return false
            }
        } catch {
            errorMessage = "分析请求失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Save Analysis Record

    /// 保存单条分析记录
    private func saveAnalysisRecord(
        isBatch: Bool,
        period: String?,
        diaryId: String?,
        diaryIds: [String]?,
        diaryCount: Int,
        snapshot: DiarySnapshotItem,
        analysis: String,
        modelName: String?,
        tokensUsed: Int?,
        responseTime: Int?
    ) async {
        do {
            let request = SaveDiaryAnalysisRequest(
                isBatch: isBatch,
                period: period,
                diaryId: diaryId,
                diaryIds: diaryIds,
                diaryCount: diaryCount,
                diarySnapshot: AnyCodable(snapshot.toDictionary()),
                analysis: analysis,
                modelName: modelName,
                tokensUsed: tokensUsed,
                responseTime: responseTime
            )

            let _: SaveDiaryAnalysisResponse = try await APIService.shared.post(
                "/ai-analysis/diary/save",
                body: request
            )
        } catch {
            print("保存分析记录失败: \(error)")
        }
    }

    /// 保存批量分析记录
    private func saveAnalysisRecord(
        isBatch: Bool,
        period: String?,
        diaryId: String?,
        diaryIds: [String]?,
        diaryCount: Int,
        snapshots: [DiarySnapshotItem],
        analysis: String,
        modelName: String?,
        tokensUsed: Int?,
        responseTime: Int?
    ) async {
        do {
            // 将 DiarySnapshotItem 数组转换为字典数组
            let snapshotDicts = snapshots.map { $0.toDictionary() }

            let request = SaveDiaryAnalysisRequest(
                isBatch: isBatch,
                period: period,
                diaryId: diaryId,
                diaryIds: diaryIds,
                diaryCount: diaryCount,
                diarySnapshot: AnyCodable(snapshotDicts),
                analysis: analysis,
                modelName: modelName,
                tokensUsed: tokensUsed,
                responseTime: responseTime
            )

            let _: SaveDiaryAnalysisResponse = try await APIService.shared.post(
                "/ai-analysis/diary/save",
                body: request
            )
        } catch {
            print("保存分析记录失败: \(error)")
        }
    }

    // MARK: - Analysis History

    /// 加载分析历史记录
    func loadAnalysisHistory(refresh: Bool = false, filterType: String? = nil) async {
        // 防止重复请求，但允许刷新中断当前加载
        if isLoadingHistory && !refresh {
            return
        }

        if refresh {
            historyPage = 1
            historyHasMore = true
        }

        guard historyHasMore else { return }

        isLoadingHistory = true
        errorMessage = nil

        // 捕获当前值用于后台任务
        let page = historyPage
        let limit = pageSize
        let filter = filterType

        // 网络请求在后台线程执行，不阻塞 MainActor
        let result: Result<DiaryAnalysisHistoryResponse, Error> = await Task.detached(priority: .userInitiated) {
            var endpoint = "/ai-analysis/diary/history?page=\(page)&limit=\(limit)"
            if let filterType = filter, !filterType.isEmpty {
                endpoint += "&isBatch=\(filterType == "batch" ? "true" : "false")"
            }

            do {
                let response: DiaryAnalysisHistoryResponse = try await APIService.shared.get(endpoint)
                return .success(response)
            } catch {
                return .failure(error)
            }
        }.value

        // UI 更新在 MainActor 上（当前已在 MainActor）
        switch result {
        case .success(let response):
            if response.success, let data = response.data {
                if refresh {
                    analysisHistory = data.records
                } else {
                    // 去重：只添加不存在的记录
                    let existingIds = Set(analysisHistory.map { $0.id })
                    let newRecords = data.records.filter { !existingIds.contains($0.id) }
                    analysisHistory.append(contentsOf: newRecords)
                }
                historyTotal = data.pagination.total
                historyHasMore = historyPage < data.pagination.totalPages
                historyPage += 1
                errorMessage = nil
            } else {
                errorMessage = response.error ?? "加载历史记录失败"
            }

        case .failure(let error):
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoadingHistory = false
    }

    /// 删除分析记录
    func deleteAnalysisRecord(id: String) async -> Bool {
        do {
            let response: DeleteDiaryAnalysisResponse = try await APIService.shared.delete(
                "/ai-analysis/diary/history/\(id)"
            )

            if response.success {
                analysisHistory.removeAll { $0.id == id }
                historyTotal -= 1
                return true
            } else {
                errorMessage = response.error ?? "删除失败"
                return false
            }
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 重置服务状态
    func reset() {
        analysisHistory = []
        historyPage = 1
        historyTotal = 0
        historyHasMore = true
        currentAnalysisResult = nil
        errorMessage = nil
        isAnalyzing = false
        isLoadingHistory = false
        analyzingType = nil
        stopLoadingTextAnimation()
    }
}
