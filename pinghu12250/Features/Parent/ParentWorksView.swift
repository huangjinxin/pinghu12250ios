//
//  ParentWorksView.swift
//  pinghu12250
//
//  家长查看孩子作品（只读）
//

import SwiftUI

struct ParentWorksView: View {
    let childId: String

    @State private var works: [ChildWork] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var selectedType = "all"
    @State private var workStats: WorkStats?

    @Environment(\.viewingChild) var child

    private let workTypes = [
        ("all", "全部"),
        ("html", "HTML"),
        ("poetry", "诗词"),
        ("creative", "创意")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 只读提示
            if let child = child {
                ParentModeBanner(childName: child.displayName)
            }

            // 统计卡片
            if let stats = workStats {
                statsCard(stats)
            }

            // 类型筛选
            typeSelector

            // 内容
            if isLoading && works.isEmpty {
                loadingView
            } else if let error = error, works.isEmpty {
                errorView(error)
            } else if works.isEmpty {
                emptyView
            } else {
                worksGrid
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadStats()
            loadWorks()
        }
    }

    // MARK: - 统计卡片

    private func statsCard(_ stats: WorkStats) -> some View {
        HStack(spacing: 0) {
            statItem(value: stats.total, label: "总计", color: .blue)
            Divider().frame(height: 30)
            statItem(value: stats.html, label: "HTML", color: .orange)
            Divider().frame(height: 30)
            statItem(value: stats.poetry, label: "诗词", color: .purple)
            Divider().frame(height: 30)
            statItem(value: stats.creative, label: "创意", color: .pink)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 类型选择器

    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(workTypes, id: \.0) { type in
                    Button {
                        withAnimation {
                            selectedType = type.0
                            resetAndLoad()
                        }
                    } label: {
                        Text(type.1)
                            .font(.subheadline)
                            .fontWeight(selectedType == type.0 ? .semibold : .regular)
                            .foregroundColor(selectedType == type.0 ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedType == type.0 ? Color.appPrimary : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 作品网格

    private var worksGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(works) { work in
                    WorkCard(work: work)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 加载更多
            if hasMore {
                Button {
                    loadMore()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("加载更多")
                            .foregroundColor(.appPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    // MARK: - 作品卡片

    private struct WorkCard: View {
        let work: ChildWork

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // 缩略图
                ZStack {
                    if let thumbnail = work.thumbnail ?? work.coverImage,
                       let url = URL(string: thumbnail.hasPrefix("http") ? thumbnail : APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + thumbnail) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                    } else {
                        placeholderImage
                    }

                    // 类型标签
                    VStack {
                        HStack {
                            Spacer()
                            Text(workTypeLabel)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(workTypeColor)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // 标题
                Text(work.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // 底部信息
                HStack {
                    // 点赞数
                    Label("\(work.likeCount)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.pink)

                    Spacer()

                    // 状态
                    if let status = work.status {
                        Text(statusLabel(status))
                            .font(.caption)
                            .foregroundColor(statusColor(status))
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }

        private var placeholderImage: some View {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: workTypeIcon)
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                )
        }

        private var workTypeLabel: String {
            switch work.workType {
            case "html": return "HTML"
            case "poetry": return "诗词"
            case "creative": return "创意"
            default: return "作品"
            }
        }

        private var workTypeColor: Color {
            switch work.workType {
            case "html": return .orange
            case "poetry": return .purple
            case "creative": return .pink
            default: return .gray
            }
        }

        private var workTypeIcon: String {
            switch work.workType {
            case "html": return "chevron.left.forwardslash.chevron.right"
            case "poetry": return "text.quote"
            case "creative": return "paintbrush.fill"
            default: return "doc.fill"
            }
        }

        private func statusLabel(_ status: String) -> String {
            switch status {
            case "APPROVED": return "已通过"
            case "PENDING": return "待审核"
            case "REJECTED": return "已退回"
            default: return status
            }
        }

        private func statusColor(_ status: String) -> Color {
            switch status {
            case "APPROVED": return .green
            case "PENDING": return .orange
            case "REJECTED": return .red
            default: return .secondary
            }
        }
    }

    // MARK: - 辅助视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
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
                resetAndLoad()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintpalette")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无作品")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    private func resetAndLoad() {
        currentPage = 1
        works = []
        hasMore = true
        loadWorks()
    }

    private func loadMore() {
        currentPage += 1
        loadWorks()
    }

    private func loadStats() {
        Task {
            do {
                let response: WorkStatsResponse = try await APIService.shared.get("/parent/child/\(childId)/works/stats")
                await MainActor.run {
                    workStats = response.data
                }
            } catch {
                print("加载作品统计失败: \(error)")
            }
        }
    }

    private func loadWorks() {
        isLoading = true
        error = nil

        Task {
            do {
                var endpoint = "/parent/child/\(childId)/works?page=\(currentPage)&limit=20"
                if selectedType != "all" {
                    endpoint += "&type=\(selectedType)"
                }

                let response: ChildWorksResponse = try await APIService.shared.get(endpoint)
                await MainActor.run {
                    if currentPage == 1 {
                        works = response.data.works
                    } else {
                        works.append(contentsOf: response.data.works)
                    }
                    hasMore = currentPage < response.data.pagination.totalPages
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

// MARK: - 数据模型

struct WorkStatsResponse: Decodable {
    let success: Bool
    let data: WorkStats
}

struct WorkStats: Decodable {
    let html: Int
    let poetry: Int
    let creative: Int
    let total: Int
}

struct ChildWorksResponse: Decodable {
    let success: Bool
    let data: ChildWorksData
}

struct ChildWorksData: Decodable {
    let works: [ChildWork]
    let pagination: WorkPagination
}

struct ChildWork: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let thumbnail: String?
    let coverImage: String?
    let workType: String
    let status: String?
    let likeCount: Int
    let createdAt: String
}

struct WorkPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

#Preview {
    ParentWorksView(childId: "test-child-id")
}
