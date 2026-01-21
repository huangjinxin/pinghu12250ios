//
//  CalligraphyGalleryView.swift
//  pinghu12250
//
//  作品库视图 - 与Web端同步
//

import SwiftUI

// MARK: - 图片URL辅助函数

private func buildImageURL(_ path: String?) -> URL? {
    guard let path = path, !path.isEmpty else { return nil }
    // 如果已经是完整URL，直接使用
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return URL(string: path)
    }
    // 相对路径，拼接服务器地址（去掉/api后缀）
    let baseURL = APIConfig.baseURL.replacingOccurrences(of: "/api", with: "")
    return URL(string: baseURL + path)
}

struct CalligraphyGalleryView: View {
    @ObservedObject var viewModel: WritingViewModel
    @State private var selectedWork: CalligraphyWork?
    @EnvironmentObject var authManager: AuthManager

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 筛选栏
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // 作品列表
            ScrollView {
                if viewModel.works.isEmpty && !viewModel.isLoadingWorks {
                    emptyView
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.works) { work in
                            CalligraphyWorkCard(
                                work: work,
                                currentUserId: authManager.currentUser?.id,
                                onTap: { selectedWork = work },
                                onLike: { Task { await viewModel.toggleLike(work) } },
                                onDelete: { Task { await viewModel.deleteWork(work) } }
                            )
                        }
                    }
                    .padding()

                    // 加载更多
                    if viewModel.hasMoreWorks {
                        Button("加载更多") {
                            Task { await viewModel.loadWorks() }
                        }
                        .padding()
                    }
                }
            }
            .refreshable {
                await viewModel.loadWorks(refresh: true)
            }
            .overlay {
                if viewModel.isLoadingWorks && viewModel.works.isEmpty {
                    ProgressView()
                }
            }
        }
        .sheet(item: $selectedWork) { work in
            WorkDetailSheet(work: work, viewModel: viewModel)
        }
        .task {
            if viewModel.works.isEmpty {
                await viewModel.loadWorks(refresh: true)
            }
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            Task { await viewModel.loadWorks(refresh: true) }
        }
        .onChange(of: viewModel.sortBy) { _, _ in
            Task { await viewModel.loadWorks(refresh: true) }
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        HStack {
            // 排序选择
            Picker("排序", selection: $viewModel.sortBy) {
                ForEach(WritingViewModel.SortBy.allCases, id: \.self) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Spacer()

            // 视图模式
            Picker("视图", selection: $viewModel.viewMode) {
                ForEach(WritingViewModel.ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(viewModel.viewMode == .my ? "还没有创作作品" : "暂无作品")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("去\"临摹\"页面创作你的第一个作品吧")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("开始练习") {
                viewModel.selectedTab = .practice
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - 作品卡片（田字格预览样式）

private struct CalligraphyWorkCard: View {
    let work: CalligraphyWork
    let currentUserId: String?
    let onTap: () -> Void
    let onLike: () -> Void
    let onDelete: () -> Void

    var isOwner: Bool {
        guard let userId = currentUserId else { return false }
        return work.authorId == userId
    }

    var body: some View {
        VStack(spacing: 0) {
            // 田字格预览
            ZStack {
                // 2x2田字格
                MiniCopybookView(work: work)

                // 评分徽章
                if let score = work.evaluationScore {
                    ScoreBadge(score: score)
                        .position(x: 150, y: 20)
                }
            }
            .frame(height: 160)
            .background(Color(red: 1, green: 0.996, blue: 0.97))
            .clipped()

            // 作品信息
            VStack(alignment: .leading, spacing: 6) {
                Text(work.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack {
                    // 作者
                    if let author = work.author {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text(String(author.displayName.prefix(1)))
                                        .font(.caption2)
                                )
                            Text(author.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // 点赞
                    Button(action: onLike) {
                        HStack(spacing: 2) {
                            Image(systemName: work.isLiked == true ? "heart.fill" : "heart")
                                .foregroundColor(work.isLiked == true ? .red : .gray)
                            Text("\(work.likeCount)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onTapGesture(perform: onTap)
        .contextMenu {
            if isOwner {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - 2x2田字格预览

private struct MiniCopybookView: View {
    let work: CalligraphyWork

    var contentItems: [(char: String, preview: String?)] {
        if let content = work.content {
            return zip(content.characters, content.previews).map { ($0, $1) }
        }
        // 旧格式：从title获取字符
        return work.displayTitle.map { (String($0), nil as String?) }
    }

    var body: some View {
        let items = Array(contentItems.prefix(4))
        let gridSize = 2

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: gridSize), spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                MiniCell(
                    character: index < items.count ? items[index].char : nil,
                    preview: index < items.count ? items[index].preview : nil,
                    workPreview: work.preview,
                    index: index,
                    totalChars: work.charCount ?? items.count
                )
            }
        }
    }
}

private struct MiniCell: View {
    let character: String?
    let preview: String?
    let workPreview: String?
    let index: Int
    let totalChars: Int

    // 优先使用单字preview，否则在第一格显示整体preview
    var displayPreview: String? {
        if let p = preview, !p.isEmpty { return p }
        if index == 0 { return workPreview }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 田字格边框和十字线
                Rectangle()
                    .stroke(Color.black.opacity(0.8), lineWidth: 1)

                // 十字虚线
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(Color.red.opacity(0.5))

                // 参考字（半透明）
                if let char = character {
                    Text(char)
                        .font(.system(size: geo.size.width * 0.5, design: .serif))
                        .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4).opacity(0.25))
                }

                // 用户书写的字
                if let url = buildImageURL(displayPreview) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 评分徽章

private struct ScoreBadge: View {
    let score: Int

    var color: Color {
        if score >= 85 { return .green }
        if score >= 60 { return .blue }
        return .orange
    }

    var body: some View {
        Text("\(score)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(color.gradient)
            .clipShape(Circle())
    }
}

// MARK: - 作品详情

private struct WorkDetailSheet: View {
    let work: CalligraphyWork
    @ObservedObject var viewModel: WritingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReference = true
    @State private var playingIndex: Int = -1

    var contentItems: [(char: String, preview: String?, strokeData: StrokeDataV2?)] {
        if let content = work.content {
            return zip(zip(content.characters, content.previews), content.strokeDataList).map {
                ($0.0, $0.1, $1)
            }
        }
        return work.displayTitle.map { (String($0), nil as String?, nil as StrokeDataV2?) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 字帖网格预览
                    detailPreview
                        .padding(.horizontal)

                    // 显示参考字开关
                    Toggle("显示临摹参考", isOn: $showReference)
                        .padding(.horizontal)

                    Text("点击田字格播放笔划动画")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 评分展示
                    if let score = work.evaluationScore {
                        evaluationSection(score: score)
                            .padding(.horizontal)
                    }

                    // 作者信息
                    authorSection
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(work.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var detailPreview: some View {
        let items = contentItems

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: min(items.count, 5)),
            spacing: 0
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                DetailCellWithAnimation(
                    character: item.char,
                    preview: item.preview,
                    workPreview: work.preview,
                    index: index,
                    showReference: showReference,
                    strokeData: item.strokeData,
                    isPlaying: playingIndex == index,
                    onTap: {
                        if playingIndex == index {
                            playingIndex = -1
                        } else {
                            playingIndex = index
                        }
                    }
                )
            }
        }
        .background(Color(red: 1, green: 0.996, blue: 0.97))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func evaluationSection(score: Int) -> some View {
        VStack(spacing: 12) {
            // 总分
            HStack {
                VStack {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(score >= 85 ? .green : score >= 60 ? .blue : .orange)
                    Text(score >= 85 ? "优秀" : score >= 60 ? "良好" : "需努力")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)

                if let data = work.evaluationData {
                    VStack(alignment: .leading, spacing: 8) {
                        if let recognition = data.recognition?.score {
                            ScoreRow(label: "字形识别", score: recognition, max: 50)
                        }
                        if let stroke = data.strokeQuality?.score {
                            ScoreRow(label: "笔画质量", score: stroke, max: 30)
                        }
                        if let aesthetics = data.aesthetics?.score {
                            ScoreRow(label: "整体美观", score: aesthetics, max: 20)
                        }
                    }
                }
            }

            if let summary = work.evaluationData?.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var authorSection: some View {
        HStack {
            if let author = work.author {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(author.displayName.prefix(1)))
                            .font(.headline)
                    )

                VStack(alignment: .leading) {
                    Text(author.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(formatDate(work.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.toggleLike(work) }
            } label: {
                Label("\(work.likeCount)", systemImage: work.isLiked == true ? "heart.fill" : "heart")
                    .foregroundColor(work.isLiked == true ? .red : .primary)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - 带动画的详情单元格

private struct DetailCellWithAnimation: View {
    let character: String
    let preview: String?
    let workPreview: String?
    let index: Int
    let showReference: Bool
    let strokeData: StrokeDataV2?
    let isPlaying: Bool
    let onTap: () -> Void

    var displayPreview: String? {
        if let p = preview, !p.isEmpty { return p }
        if index == 0 { return workPreview }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .stroke(Color.black.opacity(0.8), lineWidth: 1)

                // 十字虚线
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Color.red.opacity(0.5))

                // 参考字
                if showReference {
                    Text(character)
                        .font(.system(size: geo.size.width * 0.7, design: .serif))
                        .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4).opacity(0.3))
                }

                // 用户书写
                if let url = buildImageURL(displayPreview) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                }

                // 笔划动画层
                if isPlaying, let data = strokeData {
                    StrokeReplayView(strokeData: data, cellSize: geo.size)
                }

                // 播放提示
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(isPlaying ? Color.red.opacity(0.8) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(2)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 笔划回放视图

private struct StrokeReplayView: View {
    let strokeData: StrokeDataV2
    let cellSize: CGSize
    @State private var currentStrokeIndex: Int = 0
    @State private var currentPointIndex: Int = 0

    var scale: CGFloat {
        min(cellSize.width / strokeData.canvas.width, cellSize.height / strokeData.canvas.height)
    }

    var offsetX: CGFloat {
        (cellSize.width - strokeData.canvas.width * scale) / 2
    }

    var offsetY: CGFloat {
        (cellSize.height - strokeData.canvas.height * scale) / 2
    }

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for (strokeIdx, stroke) in strokeData.strokes.enumerated() {
                if strokeIdx > currentStrokeIndex { break }
                let maxPoints = strokeIdx == currentStrokeIndex ? currentPointIndex : stroke.points.count
                guard maxPoints > 0 else { continue }

                let firstPoint = stroke.points[0]
                path.move(to: CGPoint(
                    x: firstPoint.x * scale + offsetX,
                    y: firstPoint.y * scale + offsetY
                ))

                for i in 1..<min(maxPoints, stroke.points.count) {
                    let point = stroke.points[i]
                    path.addLine(to: CGPoint(
                        x: point.x * scale + offsetX,
                        y: point.y * scale + offsetY
                    ))
                }
            }

            context.stroke(path, with: .color(.red), lineWidth: 2)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        currentStrokeIndex = 0
        currentPointIndex = 0
        animateNextPoint()
    }

    private func animateNextPoint() {
        guard currentStrokeIndex < strokeData.strokes.count else { return }

        let stroke = strokeData.strokes[currentStrokeIndex]
        if currentPointIndex < stroke.points.count {
            currentPointIndex += 1

            let delay: TimeInterval
            if currentPointIndex < stroke.points.count && currentPointIndex > 0 {
                let dt = stroke.points[currentPointIndex].t - stroke.points[currentPointIndex - 1].t
                delay = min(dt, 0.05)
            } else {
                delay = 0.016
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateNextPoint()
            }
        } else {
            currentStrokeIndex += 1
            currentPointIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateNextPoint()
            }
        }
    }
}

private struct ScoreRow: View {
    let label: String
    let score: Int
    let max: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            ProgressView(value: Double(score), total: Double(max))
                .tint(.blue)
            Text("\(score)/\(max)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }
    }
}

#Preview {
    CalligraphyGalleryView(viewModel: WritingViewModel())
        .environmentObject(AuthManager.shared)
}
