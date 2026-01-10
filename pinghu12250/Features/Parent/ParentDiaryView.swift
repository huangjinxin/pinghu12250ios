//
//  ParentDiaryView.swift
//  pinghu12250
//
//  家长查看孩子的日记AI分析记录（只读，不能删除）
//

import SwiftUI

struct ParentDiaryView: View {
    let childId: String

    @State private var records: [DiaryAnalysisData] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var selectedFilter = ""
    @State private var selectedRecord: DiaryAnalysisData?

    @Environment(\.viewingChild) var child

    private let pageSize = 20

    var body: some View {
        VStack(spacing: 0) {
            // 只读提示
            if let child = child {
                ParentModeBanner(childName: child.displayName)
            }

            // 筛选栏
            filterBar

            // 内容区域
            if isLoading && records.isEmpty {
                loadingView
            } else if let error = error, records.isEmpty {
                errorView(error)
            } else if records.isEmpty {
                emptyView
            } else {
                recordsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadRecords(refresh: true)
        }
        .sheet(item: $selectedRecord) { record in
            ParentDiaryAnalysisDetailSheet(record: record)
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ParentDiaryFilterChip(title: "全部", selected: selectedFilter == "") {
                    selectedFilter = ""
                    loadRecords(refresh: true)
                }
                ParentDiaryFilterChip(title: "单条分析", selected: selectedFilter == "single") {
                    selectedFilter = "single"
                    loadRecords(refresh: true)
                }
                ParentDiaryFilterChip(title: "批量分析", selected: selectedFilter == "batch") {
                    selectedFilter = "batch"
                    loadRecords(refresh: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 列表

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(records) { record in
                    ParentDiaryAnalysisCard(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecord = record
                        }
                }

                // 加载更多
                if hasMore {
                    Button {
                        loadRecords()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("加载更多")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundColor(.appPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(16)
        }
        .refreshable {
            loadRecords(refresh: true)
        }
    }

    // MARK: - 辅助视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
            Button("重试") {
                loadRecords(refresh: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无AI分析记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("孩子还没有进行过日记AI分析")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    private func loadRecords(refresh: Bool = false) {
        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }

        isLoading = true
        error = nil

        Task {
            do {
                var endpoint = "/parent/child/\(childId)/diary/analysis?page=\(currentPage)&limit=\(pageSize)"
                if !selectedFilter.isEmpty {
                    endpoint += "&isBatch=\(selectedFilter == "batch" ? "true" : "false")"
                }

                let response: ParentDiaryAnalysisResponse = try await APIService.shared.get(endpoint)

                await MainActor.run {
                    if refresh {
                        records = response.data.records
                    } else {
                        records.append(contentsOf: response.data.records)
                    }
                    hasMore = currentPage < response.data.pagination.totalPages
                    currentPage += 1
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 筛选芯片

private struct ParentDiaryFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(selected ? .medium : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分析记录卡片

private struct ParentDiaryAnalysisCard: View {
    let record: DiaryAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：类型标签和日期
            HStack {
                // 类型标签
                HStack(spacing: 4) {
                    Image(systemName: record.isBatch ? "doc.on.doc.fill" : "doc.text.fill")
                        .font(.caption2)
                    Text(record.isBatch ? "批量 · \(record.period ?? "")" : "单条")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(record.isBatch ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                .foregroundColor(record.isBatch ? .blue : .green)
                .cornerRadius(12)

                Text("\(record.diaryCount) 篇日记")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 日记标题摘要
            Text(record.diarySnapshot?.titleSummary ?? "无标题")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            // 分析内容预览
            Text(record.analysis.replacingOccurrences(of: "#", with: "").prefix(100) + "...")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .lineSpacing(2)

            // 元数据
            HStack(spacing: 16) {
                if let modelName = record.modelName {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                        Text(modelName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                if let time = record.responseTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", Double(time) / 1000.0))s")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                if let tokens = record.tokensUsed {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(tokens)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 分析详情弹窗（只读）

private struct ParentDiaryAnalysisDetailSheet: View {
    let record: DiaryAnalysisData
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginalDiary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题信息卡片
                    headerCard

                    // 原日记（可折叠）
                    if record.diarySnapshot != nil {
                        originalDiarySection
                    }

                    // AI 分析结果
                    analysisSection

                    // 元数据
                    metadataSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("分析详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - 标题信息卡片

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // 类型标签
                    HStack(spacing: 4) {
                        Image(systemName: record.isBatch ? "doc.on.doc.fill" : "doc.text.fill")
                            .font(.caption2)
                        Text(record.isBatch ? "批量分析" : "单条分析")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(record.isBatch ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundColor(record.isBatch ? .blue : .green)
                    .cornerRadius(12)

                    if record.isBatch, let period = record.period {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(record.diaryCount) 篇日记", systemImage: "doc.plaintext")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(record.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.title)
                .foregroundColor(.purple.opacity(0.6))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 原日记折叠区

    private var originalDiarySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOriginalDiary.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.appPrimary)
                    Text("查看原日记内容")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showOriginalDiary ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            if showOriginalDiary {
                VStack(spacing: 12) {
                    if let snapshot = record.diarySnapshot {
                        switch snapshot {
                        case .single(let item):
                            DiarySnapshotItemView(item: item)
                        case .batch(let items):
                            ForEach(items.indices, id: \.self) { index in
                                DiarySnapshotItemView(item: items[index])
                                if index < items.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .clipped()
    }

    // MARK: - AI 分析结果

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI 分析结果")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            MarkdownView(content: record.analysis, fontSize: 15, lineSpacing: 6)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 元数据

    private var metadataSection: some View {
        HStack(spacing: 20) {
            if let modelName = record.modelName {
                VStack(spacing: 4) {
                    Text("模型")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(modelName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if let time = record.responseTime {
                VStack(spacing: 4) {
                    Text("耗时")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", Double(time) / 1000.0))秒")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if let tokens = record.tokensUsed {
                VStack(spacing: 4) {
                    Text("Token")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(tokens)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 日记快照项视图

private struct DiarySnapshotItemView: View {
    let item: DiarySnapshotItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 心情天气和日期
            HStack(spacing: 8) {
                Text(item.moodEmoji)
                    .font(.title3)
                Text(item.weatherEmoji)
                    .font(.title3)

                if let createdAt = item.createdAt {
                    let isoFormatter = ISO8601DateFormatter()
                    if let date = isoFormatter.date(from: createdAt) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // 标题
            Text(item.title ?? "无标题")
                .font(.subheadline)
                .fontWeight(.semibold)

            // 内容
            if let content = item.content {
                Text(content)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(5)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - API Response Models

struct ParentDiaryAnalysisResponse: Decodable {
    let success: Bool
    let data: ParentDiaryAnalysisData
}

struct ParentDiaryAnalysisData: Decodable {
    let records: [DiaryAnalysisData]
    let pagination: ParentDiaryPagination
}

struct ParentDiaryPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

#Preview {
    ParentDiaryView(childId: "test-child-id")
}
