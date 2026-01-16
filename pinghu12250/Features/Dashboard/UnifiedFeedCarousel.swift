//
//  UnifiedFeedCarousel.swift
//  pinghu12250
//
//  朋友动态轮播组件 - 对应 Web 端 MomentsCarousel
//

import SwiftUI
import Combine

// MARK: - 轮播组件

struct UnifiedFeedCarousel: View {
    @StateObject private var viewModel = UnifiedFeedViewModel()
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // 自动播放定时器
    @State private var autoPlayTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.pink)
                        .font(.system(size: 18))
                    Text("朋友动态")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                NavigationLink(destination: MomentsListView()) {
                    HStack(spacing: 4) {
                        Text("查看更多")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 内容区
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(height: 200)
            } else if viewModel.items.isEmpty {
                EmptyFeedView()
            } else {
                GeometryReader { geometry in
                    ZStack {
                        // 轮播轨道
                        HStack(spacing: 0) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                FeedItemCard(item: item)
                                    .frame(width: geometry.size.width - 32)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                        .animation(isDragging ? nil : .easeInOut(duration: 0.3), value: currentIndex)
                        .animation(isDragging ? nil : .easeInOut(duration: 0.3), value: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    stopAutoPlay()

                                    // 边界阻尼
                                    var offset = value.translation.width
                                    if (currentIndex == 0 && offset > 0) ||
                                       (currentIndex == viewModel.items.count - 1 && offset < 0) {
                                        offset *= 0.3
                                    }
                                    dragOffset = offset
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let threshold = geometry.size.width * 0.2
                                    let velocity = value.predictedEndLocation.x - value.location.x

                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if value.translation.width < -threshold || velocity < -100 {
                                            // 向左滑 - 下一张
                                            if currentIndex < viewModel.items.count - 1 {
                                                currentIndex += 1
                                            }
                                        } else if value.translation.width > threshold || velocity > 100 {
                                            // 向右滑 - 上一张
                                            if currentIndex > 0 {
                                                currentIndex -= 1
                                            }
                                        }
                                        dragOffset = 0
                                    }

                                    startAutoPlay()
                                }
                        )

                        // 左右导航按钮
                        if viewModel.items.count > 1 {
                            HStack {
                                Button {
                                    withAnimation {
                                        if currentIndex > 0 {
                                            currentIndex -= 1
                                        } else {
                                            currentIndex = viewModel.items.count - 1
                                        }
                                    }
                                    restartAutoPlay()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(width: 28, height: 28)
                                        .background(Color(.systemBackground).opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                }
                                .padding(.leading, 24)

                                Spacer()

                                Button {
                                    withAnimation {
                                        if currentIndex < viewModel.items.count - 1 {
                                            currentIndex += 1
                                        } else {
                                            currentIndex = 0
                                        }
                                    }
                                    restartAutoPlay()
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(width: 28, height: 28)
                                        .background(Color(.systemBackground).opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                }
                                .padding(.trailing, 24)
                            }
                        }
                    }
                }
                .frame(height: 220)

                // 导航点
                if viewModel.items.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<viewModel.items.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.appPrimary : Color.gray.opacity(0.3))
                                .frame(width: index == currentIndex ? 18 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                                .onTapGesture {
                                    withAnimation {
                                        currentIndex = index
                                    }
                                    restartAutoPlay()
                                }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            viewModel.loadFeed()
            startAutoPlay()
        }
        .onDisappear {
            stopAutoPlay()
        }
    }

    // MARK: - 自动播放

    private func startAutoPlay() {
        guard viewModel.items.count > 1 else { return }
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation {
                if currentIndex < viewModel.items.count - 1 {
                    currentIndex += 1
                } else {
                    currentIndex = 0
                }
            }
        }
    }

    private func stopAutoPlay() {
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }

    private func restartAutoPlay() {
        stopAutoPlay()
        startAutoPlay()
    }
}

// MARK: - 动态卡片

struct FeedItemCard: View {
    let item: UnifiedFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 类型标签（非普通动态和照片时显示）
            if item.type != .post && item.type != .photo {
                Text(item.type.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: item.type.color), Color(hex: item.type.color).opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }

            // 作者信息
            HStack(spacing: 10) {
                // 头像
                if let avatar = item.author.avatar, !avatar.isEmpty {
                    AsyncImage(url: URL(string: buildFullURL(avatar))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.appPrimary.opacity(0.2))
                            .overlay(
                                Text(item.author.avatarLetter)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appPrimary)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(item.author.avatarLetter)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimary)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.author.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(item.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 心情
                if let mood = item.mood {
                    Text(MoodHelper.emoji(for: mood))
                        .font(.title3)
                }
            }

            // 标题（作品类型）
            if let title = item.title, item.type != .post && item.type != .photo {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            // 内容预览
            if let content = item.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }

            // 图片预览
            if let imageUrl = item.previewImage {
                AsyncImage(url: URL(string: buildFullURL(imageUrl))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxHeight: 80)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                // 图片数量标签
                                Group {
                                    if let images = item.images, images.count > 1 {
                                        Text("+\(images.count - 1)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(12)
                                            .padding(6)
                                    }
                                },
                                alignment: .bottomTrailing
                            )
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 80)
                            .cornerRadius(8)
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 80)
                            .cornerRadius(8)
                            .overlay(ProgressView())
                    }
                }
            }

            // 互动数据
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.pink.opacity(0.6))
                    Text("\(item.likesCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.commentsCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray6).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }

    private func buildFullURL(_ path: String) -> String {
        if path.hasPrefix("http") {
            return path
        }
        return APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + path
    }
}

// MARK: - 空状态视图

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text("还没有动态")
                .font(.subheadline)
                .foregroundColor(.secondary)
            NavigationLink(destination: MomentsListView()) {
                Text("去发布第一条 →")
                    .font(.caption)
                    .foregroundColor(.appPrimary)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - ViewModel

class UnifiedFeedViewModel: ObservableObject {
    @Published var items: [UnifiedFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadFeed() {
        isLoading = true
        error = nil

        Task {
            do {
                let response: UnifiedFeedResponse = try await APIService.shared.get(
                    APIConfig.Endpoints.unifiedFeed,
                    queryItems: [URLQueryItem(name: "limit", value: "10")]
                )

                await MainActor.run {
                    if response.success, let data = response.data {
                        self.items = data.items
                    } else {
                        self.error = response.error ?? "加载失败"
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - 动态列表页面

struct MomentsListView: View {
    @StateObject private var viewModel = MomentsListViewModel()
    @State private var selectedFilter: MomentsFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // 筛选标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MomentsFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                            Task { await viewModel.loadMoments(filter: filter, refresh: true) }
                        } label: {
                            Text(filter.displayName)
                                .font(.subheadline)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.appPrimary : Color(.systemGray6))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // 动态列表
            if viewModel.isLoading && viewModel.items.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("还没有动态")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.items) { item in
                            MomentFullCard(item: item)
                        }

                        // 加载更多
                        if viewModel.hasMore {
                            Button {
                                Task { await viewModel.loadMore(filter: selectedFilter) }
                            } label: {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("加载更多")
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.loadMoments(filter: selectedFilter, refresh: true)
                }
            }
        }
        .navigationTitle("朋友动态")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadMoments(filter: selectedFilter, refresh: true)
            }
        }
    }
}

// MARK: - 筛选类型

enum MomentsFilter: String, CaseIterable {
    case all = "all"
    case photo = "photo"
    case gallery = "gallery"
    case recitation = "recitation"
    case poetry = "poetry"

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .photo: return "照片"
        case .gallery: return "画廊"
        case .recitation: return "朗诵"
        case .poetry: return "诗词"
        }
    }
}

// MARK: - 完整动态卡片

struct MomentFullCard: View {
    let item: UnifiedFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：作者信息
            HStack(spacing: 12) {
                // 头像
                if let avatar = item.author.avatar, !avatar.isEmpty {
                    AsyncImage(url: URL(string: buildFullURL(avatar))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.author.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(item.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 类型标签
                if item.type != .post && item.type != .photo {
                    Text(item.type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: item.type.color))
                        .cornerRadius(12)
                }

                // 心情
                if let mood = item.mood {
                    Text(MoodHelper.emoji(for: mood))
                        .font(.title2)
                }
            }

            // 标题（作品类型）
            if let title = item.title, !title.isEmpty, item.type != .post && item.type != .photo {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }

            // 内容
            if let content = item.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .lineLimit(4)
                    .foregroundColor(.primary)
            }

            // 图片
            if let images = item.images, !images.isEmpty {
                imageGrid(images: images)
            }

            // 底部：互动数据
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.pink.opacity(0.7))
                    Text("\(item.likesCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(item.commentsCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.appPrimary.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(item.author.avatarLetter)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
            )
    }

    @ViewBuilder
    private func imageGrid(images: [String]) -> some View {
        let count = min(images.count, 9)
        let columns = count == 1 ? 1 : (count <= 4 ? 2 : 3)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                AsyncImage(url: URL(string: buildFullURL(images[index]))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: count == 1 ? 200 : 100)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: count == 1 ? 200 : 100)
                            .cornerRadius(8)
                    default:
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(height: count == 1 ? 200 : 100)
                            .cornerRadius(8)
                            .overlay(ProgressView())
                    }
                }
            }
        }
    }

    private func buildFullURL(_ path: String) -> String {
        if path.hasPrefix("http") { return path }
        return APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + path
    }
}

// MARK: - ViewModel

@MainActor
class MomentsListViewModel: ObservableObject {
    @Published var items: [UnifiedFeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var error: String?

    private var currentPage = 1
    private let pageSize = 20

    func loadMoments(filter: MomentsFilter, refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }
        isLoading = refresh || items.isEmpty

        do {
            var endpoint = APIConfig.Endpoints.unifiedFeed + "?page=\(currentPage)&limit=\(pageSize)"
            if filter != .all {
                endpoint += "&type=\(filter.rawValue)"
            }

            let response: UnifiedFeedResponse = try await APIService.shared.get(endpoint)

            if response.success, let data = response.data {
                if refresh {
                    items = data.items
                } else {
                    items.append(contentsOf: data.items)
                }
                hasMore = currentPage < data.pagination.totalPages
                currentPage += 1
            } else {
                error = response.error ?? "加载失败"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore(filter: MomentsFilter) async {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        await loadMoments(filter: filter, refresh: false)
        isLoadingMore = false
    }
}

#Preview {
    UnifiedFeedCarousel()
        .padding()
}
