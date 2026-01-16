//
//  WorksGalleryView.swift
//  pinghu12250
//
//  作品广场 - 探索和分享精彩作品
//

import SwiftUI
import Combine
import AVFoundation
import WebKit

struct WorksGalleryView: View {
    @State private var activeTab: WorksTab = .poetry
    @StateObject private var viewModel = WorksViewModel()

    enum WorksTab: String, CaseIterable {
        case gallery = "少儿画廊"
        case recitation = "少儿朗诵"
        case diaryAnalysis = "日记分析"
        case poetry = "唐诗宋词"
        case shopping = "购物广场"

        var icon: String {
            switch self {
            case .gallery: return "photo.artframe"
            case .recitation: return "mic.fill"
            case .diaryAnalysis: return "doc.text.magnifyingglass"
            case .poetry: return "text.book.closed"
            case .shopping: return "cart.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab 选择器
                tabSelector

                // 内容区域
                Group {
                    switch activeTab {
                    case .gallery:
                        GalleryTabView(viewModel: viewModel)
                    case .recitation:
                        RecitationTabView(viewModel: viewModel)
                    case .diaryAnalysis:
                        DiaryAnalysisTabView()
                    case .poetry:
                        PoetryWorksTabView(viewModel: viewModel)
                    case .shopping:
                        ShoppingTabView(viewModel: viewModel)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("创意作品")
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(WorksTab.allCases, id: \.self) { tab in
                    WorksTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: activeTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

struct WorksTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appPrimary : Color(.systemGray5))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 少儿画廊

struct GalleryTabView: View {
    @ObservedObject var viewModel: WorksViewModel
    @State private var selectedWork: GalleryWork?

    var body: some View {
        ScrollView {
            if viewModel.isLoadingGallery && viewModel.galleryWorks.isEmpty {
                ProgressView()
                    .padding(40)
            } else if viewModel.galleryWorks.isEmpty {
                emptyState(icon: "photo.artframe", text: "暂无画作")
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(viewModel.galleryWorks) { work in
                        GalleryWorkCard(work: work)
                            .onTapGesture {
                                selectedWork = work
                            }
                    }
                }
                .padding()

                // 加载更多
                if viewModel.galleryHasMore {
                    Button {
                        Task { await viewModel.loadGalleryWorks() }
                    } label: {
                        if viewModel.isLoadingGallery {
                            ProgressView()
                        } else {
                            Text("加载更多")
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            viewModel.resetPagination()
            await viewModel.loadGalleryWorks(refresh: true)
        }
        .task {
            if viewModel.galleryWorks.isEmpty {
                await viewModel.loadGalleryWorks(refresh: true)
            }
        }
        .sheet(item: $selectedWork) { work in
            GalleryDetailSheet(work: work)
        }
    }
}

struct GalleryWorkCard: View {
    let work: GalleryWork

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作品图片 - 使用完整 URL
            if let imageUrl = work.fullImageURL {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    case .failure:
                        placeholderImage
                    case .empty:
                        ProgressView()
                            .frame(height: 140)
                    @unknown default:
                        placeholderImage
                    }
                }
                .cornerRadius(10)
            } else {
                placeholderImage
            }

            // 模板名称 - 放大字号
            if let template = work.template {
                Text(template.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }

            // 描述内容 - 放大字号
            if let content = work.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // 作者 - 放大字号，移除类型标签
            if let author = work.author {
                Text(author.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.pink.opacity(0.6), .purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 140)
            .overlay(
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.7))
            )
    }
}

struct GalleryDetailSheet: View {
    let work: GalleryWork
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 图片展示 - 使用完整 URL
                    ForEach(work.allFullImageURLs, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                            case .failure, .empty:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                                    .cornerRadius(12)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    // 作者信息
                    if let author = work.author {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(author.avatarLetter)
                                        .foregroundColor(.appPrimary)
                                        .fontWeight(.medium)
                                )

                            VStack(alignment: .leading) {
                                Text(author.displayName)
                                    .fontWeight(.medium)
                                Text(work.createdAt?.relativeDescription ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 标签
                    if let template = work.template {
                        HStack(spacing: 8) {
                            if let typeName = template.type?.name {
                                Text(typeName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            if let standardName = template.standard?.name {
                                Text(standardName)
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }

                    // 描述
                    if let content = work.content, !content.isEmpty {
                        Text(content)
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("作品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 少儿朗诵

struct RecitationTabView: View {
    @ObservedObject var viewModel: WorksViewModel
    @State private var selectedWork: RecitationWork?

    var body: some View {
        ScrollView {
            if viewModel.isLoadingRecitation && viewModel.recitationWorks.isEmpty {
                ProgressView()
                    .padding(40)
            } else if viewModel.recitationWorks.isEmpty {
                emptyState(icon: "mic.fill", text: "暂无朗诵作品")
            } else {
                // 卡片式网格布局
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(viewModel.recitationWorks) { work in
                        RecitationWorkCard(work: work, viewModel: viewModel)
                            .onTapGesture {
                                selectedWork = work
                            }
                    }
                }
                .padding()

                // 加载更多
                if viewModel.recitationHasMore {
                    Button {
                        Task { await viewModel.loadRecitationWorks() }
                    } label: {
                        if viewModel.isLoadingRecitation {
                            ProgressView()
                        } else {
                            Text("加载更多")
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            viewModel.resetPagination()
            await viewModel.loadRecitationWorks(refresh: true)
        }
        .task {
            if viewModel.recitationWorks.isEmpty {
                await viewModel.loadRecitationWorks(refresh: true)
            }
        }
        .sheet(item: $selectedWork) { work in
            RecitationDetailSheet(work: work, viewModel: viewModel)
        }
    }
}

struct RecitationWorkCard: View {
    let work: RecitationWork
    @ObservedObject var viewModel: WorksViewModel

    var isPlaying: Bool {
        viewModel.currentPlayingId == work.id
    }

    /// 获取描述的第一个字符作为预览
    var previewChar: String {
        if let content = work.content, !content.isEmpty {
            return String(content.prefix(1))
        }
        if let name = work.template?.name, !name.isEmpty {
            return String(name.prefix(1))
        }
        return "朗"
    }

    /// 基于作品ID生成稳定的随机颜色
    var cardGradient: [Color] {
        let colorSets: [[Color]] = [
            [.purple.opacity(0.8), .pink.opacity(0.8)],
            [.blue.opacity(0.8), .cyan.opacity(0.8)],
            [.orange.opacity(0.8), .red.opacity(0.8)],
            [.green.opacity(0.8), .teal.opacity(0.8)],
            [.indigo.opacity(0.8), .purple.opacity(0.8)],
            [.pink.opacity(0.8), .orange.opacity(0.8)],
            [.teal.opacity(0.8), .blue.opacity(0.8)],
            [.red.opacity(0.8), .pink.opacity(0.8)]
        ]
        // 使用作品ID的哈希值来选择颜色，保证每次显示颜色一致
        let index = abs(work.id.hashValue) % colorSets.count
        return colorSets[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // 正方形封面区域 - 用首字作为预览
            GeometryReader { geo in
                ZStack {
                    // 渐变背景 - 使用随机颜色
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: cardGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // 首字预览 - 缩小到四分之一
                    Text(previewChar)
                        .font(.system(size: geo.size.width * 0.1, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))

                    // 播放按钮 - 放大
                    Button {
                        if let audioUrl = work.fullAudioURL {
                            viewModel.playAudio(audioUrl, workId: work.id)
                        }
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(cardGradient.first ?? .purple)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            // 底部信息区 - 放大文字
            VStack(alignment: .leading, spacing: 6) {
                // 标题 - 放大
                if let template = work.template {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }

                // 完整描述 - 放大
                if let content = work.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 作者 - 放大
                if let author = work.author {
                    Text(author.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct RecitationDetailSheet: View {
    let work: RecitationWork
    @ObservedObject var viewModel: WorksViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 封面
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.7))
                        )

                    // 标题
                    if let template = work.template {
                        Text(template.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    // 作者
                    if let author = work.author {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(author.avatarLetter)
                                        .foregroundColor(.appPrimary)
                                        .fontWeight(.medium)
                                )
                            Text(author.displayName)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 音频列表
                    VStack(spacing: 12) {
                        ForEach(Array(work.allFullAudioURLs.enumerated()), id: \.offset) { index, audioUrl in
                            HStack {
                                Text("音频 \(index + 1)")
                                    .font(.subheadline)

                                Spacer()

                                Button {
                                    viewModel.playAudio(audioUrl, workId: "\(work.id)-\(index)")
                                } label: {
                                    Image(systemName: viewModel.currentPlayingId == "\(work.id)-\(index)" ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // 描述
                    if let content = work.content, !content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("描述")
                                .font(.headline)
                            Text(content)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("朗诵详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        viewModel.stopCurrentAudio()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 唐诗宋词

struct PoetryWorksTabView: View {
    @ObservedObject var viewModel: WorksViewModel
    @State private var selectedPoetry: PoetryWorkData?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和排序
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索诗词...", text: $searchText)
                        .onSubmit {
                            Task { await viewModel.searchPoetry(searchText) }
                        }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                Menu {
                    Button("最新发布") {
                        viewModel.poetrySortBy = "latest"
                        Task { await viewModel.loadPoetryWorks(refresh: true) }
                    }
                    Button("最多点赞") {
                        viewModel.poetrySortBy = "popular"
                        Task { await viewModel.loadPoetryWorks(refresh: true) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.appPrimary)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
            .padding()

            ScrollView {
                if viewModel.isLoadingPoetry && viewModel.poetryWorks.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.poetryWorks.isEmpty {
                    emptyState(icon: "text.book.closed", text: "暂无诗词作品")
                } else {
                    // 三列卡片式网格布局（增加间距，适应宽卡片）
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 20) {
                        ForEach(viewModel.poetryWorks) { poetry in
                            PoetryWorkCard(poetry: poetry, viewModel: viewModel)
                                .onTapGesture {
                                    selectedPoetry = poetry
                                    // 打开时自动下载缓存
                                    Task { await viewModel.cachePoetry(poetry) }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)

                    // 加载更多
                    if viewModel.poetryHasMore {
                        Button {
                            Task { await viewModel.loadPoetryWorks() }
                        } label: {
                            if viewModel.isLoadingPoetry {
                                ProgressView()
                            } else {
                                Text("加载更多")
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .refreshable {
            viewModel.resetPagination()
            await viewModel.loadPoetryWorks(refresh: true)
        }
        .task {
            if viewModel.poetryWorks.isEmpty {
                await viewModel.loadPoetryWorks(refresh: true)
            }
        }
        .sheet(item: $selectedPoetry) { poetry in
            PoetryDetailSheet(poetry: poetry, viewModel: viewModel)
        }
    }
}

struct PoetryWorkCard: View {
    let poetry: PoetryWorkData
    @ObservedObject var viewModel: WorksViewModel
    @State private var isDownloading = false

    var isCached: Bool {
        viewModel.isPoetryCached(poetry.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 封面区域（使用 WKWebView 直接渲染 HTML）
            ZStack {
                // 渐变边框背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.45, green: 0.45, blue: 0.95),
                                Color(red: 0.55, green: 0.50, blue: 0.90)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 白色内容区域 - 留出边框
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .padding(3)
                    .overlay(
                        Group {
                            if let htmlCode = poetry.htmlCode, !htmlCode.isEmpty {
                                PoetryThumbnailView(htmlCode: htmlCode)
                                    .padding(3)
                            } else {
                                poetryPlaceholder
                                    .padding(3)
                            }
                        }
                        .clipped()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .aspectRatio(1.2, contentMode: .fit)  // 调整为更方正的比例

            // 底部信息区（紧凑布局）
            VStack(spacing: 4) {
                // 标题
                Text(poetry.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 作者和日期
                HStack(spacing: 4) {
                    // 作者头像和名字
                    if let author = poetry.author {
                        HStack(spacing: 3) {
                            // 绿色圆形头像
                            Circle()
                                .fill(Color.green)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Text(author.avatarLetter)
                                        .font(.system(size: 8))
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                )

                            Text(author.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // 日期
                    if let createdAt = poetry.createdAt {
                        Text(formatDate(createdAt))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                // 操作按钮
                HStack(spacing: 8) {
                    // 下载/缓存按钮（左对齐）
                    if isCached {
                        // 已缓存 - 显示绿色勾
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("已缓存")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.green)
                    } else {
                        // 未缓存 - 显示下载按钮
                        Button {
                            Task {
                                isDownloading = true
                                await viewModel.cachePoetry(poetry)
                                isDownloading = false
                            }
                        } label: {
                            HStack(spacing: 2) {
                                if isDownloading {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 10, height: 10)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10))
                                }
                                Text(isDownloading ? "下载中" : "下载")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDownloading)
                    }

                    Spacer()

                    // 分享按钮
                    Button {
                        // 分享
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 9))
                            Text("分享")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(.plain)

                    // 删除按钮
                    Button {
                        // 删除
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                            Text("删除")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // 格式化日期
    private func formatDate(_ dateString: String) -> String {
        // 简单的日期格式化 - 从 ISO 8601 转换为 yyyy/MM/dd
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
        // 尝试不带毫秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
        return dateString.prefix(10).replacingOccurrences(of: "-", with: "/")
    }

    // 占位图（没有封面时显示）
    private var poetryPlaceholder: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.48, blue: 0.92),
                    Color(red: 0.46, green: 0.31, blue: 0.64)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.8))

                Text(poetry.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }
        }
    }
}

// 诗词缩略图预览（使用 WKWebView 渲染 HTML）
struct PoetryThumbnailView: UIViewRepresentable {
    let htmlCode: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.backgroundColor = .white
        webView.isOpaque = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        loadHTML(in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTML(in: webView)
    }

    private func loadHTML(in webView: WKWebView) {
        // htmlCode 已经是完整的 HTML 页面，注入覆盖样式让内容适配缩略图
        let overrideStyles = """
        <style id="thumbnail-override">
            /* 移除渐变背景，使用白色 */
            body {
                background: #fff !important;
                min-height: auto !important;
                padding: 8px !important;
                margin: 0 !important;
            }
            /* 缩小整体内容 */
            .box, .poem-container, .container, .content, .card, .main, .wrapper {
                max-width: none !important;
                width: 100% !important;
                margin: 0 !important;
                padding: 8px !important;
                box-shadow: none !important;
                border-radius: 0 !important;
                background: transparent !important;
            }
            /* 缩小标题 */
            .title, .poem-title, h1, h2 {
                font-size: 14px !important;
                margin-bottom: 4px !important;
            }
            /* 缩小作者 */
            .author, .poem-author {
                font-size: 10px !important;
                margin-bottom: 8px !important;
            }
            /* 缩小诗句 */
            .poem, .poem-content, .content, .text, p {
                font-size: 12px !important;
                line-height: 1.6 !important;
            }
            /* 缩小拼音 */
            rt {
                font-size: 8px !important;
            }
            /* 缩小每个字 */
            .w {
                font-size: 12px !important;
                margin: 1px !important;
                padding: 1px !important;
            }
            .w .py {
                font-size: 8px !important;
            }
        </style>
        """

        var modifiedHTML = htmlCode

        // 在 </head> 前或 <body> 后注入样式
        if modifiedHTML.contains("</head>") {
            modifiedHTML = modifiedHTML.replacingOccurrences(of: "</head>", with: overrideStyles + "</head>")
        } else if modifiedHTML.contains("<body") {
            if let range = modifiedHTML.range(of: "<body[^>]*>", options: .regularExpression) {
                let bodyTag = String(modifiedHTML[range])
                modifiedHTML = modifiedHTML.replacingOccurrences(of: bodyTag, with: bodyTag + overrideStyles)
            }
        } else {
            modifiedHTML = overrideStyles + modifiedHTML
        }

        webView.loadHTMLString(modifiedHTML, baseURL: nil)
    }
}

struct PoetryDetailSheet: View {
    let poetry: PoetryWorkData
    @ObservedObject var viewModel: WorksViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showFullscreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text(poetry.title)
                        .font(.title)
                        .fontWeight(.bold)

                    // 作者
                    if let author = poetry.author {
                        Text("作者: \(author.displayName)")
                            .foregroundColor(.secondary)
                    }

                    // HTML 内容 - 使用 WebView 显示
                    if let htmlCode = poetry.htmlCode, !htmlCode.isEmpty {
                        HTMLPreviewView(htmlCode: htmlCode)
                            .frame(minHeight: 400)
                    }

                    // 操作按钮
                    HStack(spacing: 20) {
                        Button {
                            Task { await viewModel.togglePoetryLike(poetry.id) }
                        } label: {
                            VStack {
                                Image(systemName: viewModel.isPoetryLiked(poetry.id) ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isPoetryLiked(poetry.id) ? .red : .secondary)
                                Text("点赞")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        // 全屏查看按钮
                        if let htmlCode = poetry.htmlCode, !htmlCode.isEmpty {
                            Button {
                                showFullscreen = true
                            } label: {
                                VStack {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.title2)
                                        .foregroundColor(.appPrimary)
                                    Text("全屏")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            // 分享
                        } label: {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.appPrimary)
                                Text("分享")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("诗词详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                DismissibleCover {
                    PoetryFullscreenView(poetry: poetry)
                }
            }
        }
    }
}

// HTML 预览视图 - 使用 WKWebView 渲染
struct HTMLPreviewView: UIViewRepresentable {
    let htmlCode: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = true
        webView.backgroundColor = .white
        webView.isOpaque = false

        // 加载 HTML
        loadHTML(in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTML(in: webView)
    }

    private func loadHTML(in webView: WKWebView) {
        // 包装 HTML 代码，添加基础样式
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    padding: 16px;
                    background: #ffffff;
                    color: #333;
                }
                h1, h2, h3 { margin-bottom: 12px; color: #1a1a1a; }
                p { margin-bottom: 12px; }
                img { max-width: 100%; height: auto; border-radius: 8px; }
                pre { background: #f5f5f5; padding: 12px; border-radius: 8px; overflow-x: auto; }
                code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; }
                /* 诗词特殊样式 */
                .poetry-container {
                    text-align: center;
                    padding: 20px;
                }
                .poetry-title {
                    font-size: 24px;
                    font-weight: bold;
                    margin-bottom: 16px;
                    color: #8B4513;
                }
                .poetry-content {
                    font-size: 18px;
                    line-height: 2;
                    color: #333;
                }
                .poetry-author {
                    color: #666;
                    margin-top: 16px;
                }
            </style>
        </head>
        <body>
            \(htmlCode)
        </body>
        </html>
        """

        webView.loadHTMLString(fullHTML, baseURL: nil)
    }
}

// 增强版诗词详情页，支持全屏预览
struct PoetryFullscreenView: View {
    let poetry: PoetryWorkData
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let htmlCode = poetry.htmlCode, !htmlCode.isEmpty {
                PoetryWebView(htmlCode: htmlCode, isLoading: $isLoading)
                    .ignoresSafeArea(.container, edges: .bottom)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("暂无内容")
                        .foregroundColor(.secondary)
                }
            }

            // 退出全屏按钮 - 固定在右上角
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 50)
            .padding(.trailing, 16)
        }
    }
}

// WKWebView 包装器（支持加载状态回调）
struct PoetryWebView: UIViewRepresentable {
    let htmlCode: String
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.backgroundColor = .white

        loadHTML(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func loadHTML(in webView: WKWebView) {
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Hiragino Sans GB', sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                }
                .container {
                    background: rgba(255,255,255,0.95);
                    border-radius: 16px;
                    padding: 24px;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                }
            </style>
        </head>
        <body>
            <div class="container">
                \(htmlCode)
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PoetryWebView

        init(_ parent: PoetryWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

// MARK: - 购物广场

struct ShoppingTabView: View {
    @ObservedObject var viewModel: WorksViewModel

    var body: some View {
        // 直接显示扫码商品
        QRProductsView(viewModel: viewModel)
    }
}

struct MarketView: View {
    @ObservedObject var viewModel: WorksViewModel
    @State private var selectedWork: MarketWork?

    var body: some View {
        VStack(spacing: 0) {
            // 筛选
            HStack {
                Menu {
                    Button("全部") {
                        viewModel.marketCategory = "all"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                    Button("免费") {
                        viewModel.marketCategory = "free"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                    Button("付费") {
                        viewModel.marketCategory = "paid"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                } label: {
                    HStack {
                        Text(viewModel.marketCategory == "all" ? "全部" : viewModel.marketCategory == "free" ? "免费" : "付费")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()

                Menu {
                    Button("最新") {
                        viewModel.marketSortBy = "latest"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                    Button("热门") {
                        viewModel.marketSortBy = "popular"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                    Button("价格从低到高") {
                        viewModel.marketSortBy = "price_asc"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                    Button("价格从高到低") {
                        viewModel.marketSortBy = "price_desc"
                        Task { await viewModel.loadMarketWorks(refresh: true) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("排序")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            ScrollView {
                if viewModel.isLoadingMarket && viewModel.marketWorks.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.marketWorks.isEmpty {
                    emptyState(icon: "cart.fill", text: "暂无商品")
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(viewModel.marketWorks) { work in
                            MarketWorkCard(work: work, viewModel: viewModel)
                                .onTapGesture {
                                    selectedWork = work
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            viewModel.resetPagination()
            await viewModel.loadMarketWorks(refresh: true)
        }
        .task {
            if viewModel.marketWorks.isEmpty {
                await viewModel.loadMarketWorks(refresh: true)
            }
        }
        .sheet(item: $selectedWork) { work in
            MarketWorkDetailSheet(work: work, viewModel: viewModel)
        }
    }
}

struct MarketWorkCard: View {
    let work: MarketWork
    @ObservedObject var viewModel: WorksViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 预览
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(height: 120)
                .overlay(
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                )

            Text(work.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack {
                // 价格
                HStack(spacing: 2) {
                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(work.price > 0 ? String(format: "%.0f", work.price) : "免费")
                        .fontWeight(.bold)
                        .foregroundColor(work.price > 0 ? .orange : .green)
                }

                Spacer()

                if let sales = work.sales, sales > 0 {
                    Text("已售\(sales)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let seller = work.seller {
                Text(seller.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Button {
                Task {
                    let _ = await viewModel.purchaseWork(work.id)
                }
            } label: {
                Text(work.price > 0 ? "购买" : "获取")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct MarketWorkDetailSheet: View {
    let work: MarketWork
    @ObservedObject var viewModel: WorksViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 预览
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("HTML 作品")
                                    .foregroundColor(.white)
                            }
                        )

                    // 标题和价格
                    VStack(spacing: 8) {
                        Text(work.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(.orange)
                            Text(work.price > 0 ? String(format: "%.0f 学习币", work.price) : "免费")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(work.price > 0 ? .orange : .green)
                        }
                    }

                    // 卖家信息
                    if let seller = work.seller {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(seller.avatarLetter)
                                        .foregroundColor(.appPrimary)
                                        .fontWeight(.medium)
                                )

                            VStack(alignment: .leading) {
                                Text(seller.displayName)
                                    .fontWeight(.medium)
                                Text("卖家")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // 描述
                    if let description = work.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("商品描述")
                                .font(.headline)
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 购买按钮
                    Button {
                        Task {
                            isPurchasing = true
                            let success = await viewModel.purchaseWork(work.id)
                            isPurchasing = false
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text(work.price > 0 ? "立即购买" : "免费获取")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing)
                }
                .padding()
            }
            .navigationTitle("商品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct QRProductsView: View {
    @ObservedObject var viewModel: WorksViewModel
    @State private var showPaymentSheet = false
    @State private var selectedProduct: QRCodeProduct?
    @State private var paymentPassword = ""
    @State private var isProcessing = false
    @State private var showPaymentResult = false
    @State private var paymentSuccess = false
    @State private var paymentMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // 分类筛选 - 类似web的筛选按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    WorksFilterChip(
                        title: "全部",
                        isSelected: viewModel.selectedQRCategory.isEmpty
                    ) {
                        viewModel.selectedQRCategory = ""
                        Task { await viewModel.loadQRProducts() }
                    }

                    ForEach(viewModel.qrCategories, id: \.self) { category in
                        WorksFilterChip(
                            title: category,
                            isSelected: viewModel.selectedQRCategory == category
                        ) {
                            viewModel.selectedQRCategory = category
                            Task { await viewModel.loadQRProducts() }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            ScrollView {
                if viewModel.isLoadingQR && viewModel.qrProducts.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.qrProducts.isEmpty {
                    emptyState(icon: "qrcode", text: "暂无扫码商品")
                } else {
                    // 4列布局
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(viewModel.qrProducts) { product in
                            QRProductCard(product: product) {
                                selectedProduct = product
                                showPaymentSheet = true
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .refreshable {
            await viewModel.loadQRProducts()
        }
        .task {
            if viewModel.qrProducts.isEmpty {
                await viewModel.loadQRCategories()
                await viewModel.loadQRProducts()
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            if let product = selectedProduct {
                QRPaymentSheet(
                    product: product,
                    password: $paymentPassword,
                    isProcessing: $isProcessing,
                    onPay: {
                        processPayment(product)
                    },
                    onCancel: {
                        showPaymentSheet = false
                        paymentPassword = ""
                    }
                )
            }
        }
        .alert(paymentSuccess ? "支付成功" : "支付失败", isPresented: $showPaymentResult) {
            Button("确定") {
                if paymentSuccess {
                    showPaymentSheet = false
                    paymentPassword = ""
                }
            }
        } message: {
            Text(paymentMessage)
        }
    }

    private func processPayment(_ product: QRCodeProduct) {
        Task {
            isProcessing = true

            do {
                // 先扫码获取payCode信息
                let scanSuccess = await viewModel.walletViewModel?.scanPayCode(product.code) ?? false

                if scanSuccess {
                    // 提交支付
                    let paySuccess = await viewModel.walletViewModel?.submitPayment(password: paymentPassword) ?? false

                    if paySuccess {
                        paymentSuccess = true
                        paymentMessage = "支付 \(String(format: "%.2f", product.amount)) 学习币成功！"
                    } else {
                        paymentSuccess = false
                        paymentMessage = viewModel.walletViewModel?.errorMessage ?? "支付失败，请重试"
                    }
                } else {
                    paymentSuccess = false
                    paymentMessage = viewModel.walletViewModel?.errorMessage ?? "获取支付信息失败"
                }
            }

            isProcessing = false
            showPaymentResult = true
        }
    }
}

// 筛选按钮组件
struct WorksFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// 支付弹窗
struct QRPaymentSheet: View {
    let product: QRCodeProduct
    @Binding var password: String
    @Binding var isProcessing: Bool
    let onPay: () -> Void
    let onCancel: () -> Void
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 商品信息
                VStack(spacing: 12) {
                    // 二维码预览
                    if let qrcode = product.fullQRCodeURL {
                        AsyncImage(url: URL(string: qrcode)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(8)
                            default:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "qrcode")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                    }

                    Text(product.title)
                        .font(.headline)

                    Text(String(format: "%.2f 学习币", product.amount))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)

                    if let description = product.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 支付密码输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入支付密码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    SecureField("6位数字密码", text: $password)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($isPasswordFocused)
                }

                Spacer()

                // 支付按钮
                Button {
                    onPay()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("确认支付")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.count < 6 || isProcessing)
            }
            .padding()
            .navigationTitle("确认支付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
            }
            .onAppear {
                isPasswordFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct QRProductCard: View {
    let product: QRCodeProduct
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // QR 码图片 - 正方形
            if let qrcode = product.fullQRCodeURL {
                AsyncImage(url: URL(string: qrcode)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(6)
                    case .failure, .empty:
                        qrPlaceholder
                    @unknown default:
                        qrPlaceholder
                    }
                }
            } else {
                qrPlaceholder
            }

            // 标题
            Text(product.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // 价格
            Text(String(format: "%.0f币", product.amount))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)

            // 支付按钮
            Button(action: onTap) {
                Text("支付")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.appPrimary)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var qrPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - 空状态视图

func emptyState(icon: String, text: String) -> some View {
    VStack(spacing: 16) {
        Image(systemName: icon)
            .font(.system(size: 50))
            .foregroundColor(.secondary)
        Text(text)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(40)
}

// MARK: - 日记分析 Tab（作品广场版本）

struct DiaryAnalysisTabView: View {
    @StateObject private var aiService = DiaryAIService.shared
    @State private var selectedRecord: DiaryAnalysisData?

    var body: some View {
        ScrollView {
            if aiService.isLoadingHistory && aiService.analysisHistory.isEmpty {
                ProgressView()
                    .padding(40)
            } else if aiService.analysisHistory.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", text: "暂无日记分析记录")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(aiService.analysisHistory) { record in
                        WorksDiaryAnalysisCard(record: record)
                            .onTapGesture {
                                selectedRecord = record
                            }
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await aiService.loadAnalysisHistory()
        }
        .task {
            if aiService.analysisHistory.isEmpty {
                await aiService.loadAnalysisHistory()
            }
        }
        .sheet(item: $selectedRecord) { record in
            WorksDiaryAnalysisDetailSheet(record: record)
        }
    }
}

struct WorksDiaryAnalysisCard: View {
    let record: DiaryAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和日期
            HStack {
                Text(record.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(record.relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 分析类型标签
            HStack(spacing: 8) {
                Text(record.analysisTypeLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appPrimary.opacity(0.1))
                    .foregroundColor(.appPrimary)
                    .cornerRadius(6)

                if let score = record.overallScore {
                    Text("评分: \(score)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
            }

            // 摘要
            if let summary = record.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct WorksDiaryAnalysisDetailSheet: View {
    let record: DiaryAnalysisData
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    Text(record.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    // 分析类型和评分
                    HStack(spacing: 12) {
                        Text(record.analysisTypeLabel)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary.opacity(0.1))
                            .foregroundColor(.appPrimary)
                            .cornerRadius(8)

                        if let score = record.overallScore {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                Text("\(score)分")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                        }

                        Spacer()

                        Text(record.relativeTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 分析结果
                    if let result = record.result, !result.isEmpty {
                        Text(result)
                            .font(.body)
                    } else if let summary = record.summary {
                        Text(summary)
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("分析详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WorksGalleryView()
}
