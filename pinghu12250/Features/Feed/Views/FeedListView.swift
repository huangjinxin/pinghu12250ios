//
//  FeedListView.swift
//  pinghu12250
//
//  学习圈列表（Instagram单列流风格）
//

import SwiftUI

struct FeedListView: View {
    @StateObject private var viewModel = FeedViewModel()
    @Binding var selectedItem: UnifiedFeedItem?

    var body: some View {
        ScrollView {
            // 容器：最大宽度限制，水平居中
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    let showDate = shouldShowDate(at: index)
                    InstagramRow(item: item, isFirst: index == 0, isSelected: selectedItem?.id == item.id, showDate: showDate)
                        .onTapGesture { selectedItem = item }
                        .onAppear {
                            if index == viewModel.items.count - 3 {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    ProgressView().padding(20)
                }

                if !viewModel.hasMore && !viewModel.items.isEmpty {
                    Text("— 到底了 —")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "AAAAAA"))
                        .padding(.vertical, 20)
                }

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "F3F4F6"))
        .refreshable { await viewModel.loadFeed() }
        .task { await viewModel.loadFeed() }
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("加载中...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            if !viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "CCCCCC"))
                    Text("暂无动态")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                }
            }
        }
    }

    private func shouldShowDate(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.items[index].createdAt.prefix(10)
        let previous = viewModel.items[index - 1].createdAt.prefix(10)
        return current != previous
    }
}

// MARK: - Instagram风格行组件

struct InstagramRow: View {
    let item: UnifiedFeedItem
    let isFirst: Bool
    let isSelected: Bool
    let showDate: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 日期分隔
            if showDate {
                Text(formatDate(item.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "999999"))
                    .padding(.vertical, 16)
            }

            // 卡片
            InstagramCard(item: item, isSelected: isSelected)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let prefix = dateStr.prefix(10)
        return String(prefix)
    }
}

// MARK: - Instagram风格卡片

struct InstagramCard: View {
    let item: UnifiedFeedItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：头像 + 昵称 + 时间
            CardHeader(item: item)
                .padding(16)

            // 正文
            if let content = item.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundColor(Color(hex: "333333"))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // 图片（大尺寸，保持比例）
            if let images = item.images, !images.isEmpty {
                CardImages(images: images)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else if let preview = item.preview {
                CardImages(images: [preview])
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // 底部：交互按钮
            CardFooter(item: item)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "10B981") : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - 卡片头部

struct CardHeader: View {
    let item: UnifiedFeedItem

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            if let avatar = item.author.avatar, let url = URL(string: avatar.hasPrefix("http") ? avatar : APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + avatar) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "E5E7EB")).overlay(
                        Text(String(item.author.name.prefix(1)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle().fill(Color(hex: "E5E7EB"))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(item.author.name.prefix(1)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.author.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "333333"))

                HStack(spacing: 6) {
                    Text(item.formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "999999"))

                    // 类型标签
                    Text(item.type.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "10B981"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "10B981").opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Spacer()

            if let mood = item.mood {
                Text(MoodHelper.emoji(for: mood))
                    .font(.system(size: 20))
            }
        }
    }
}

// MARK: - 卡片图片

struct CardImages: View {
    let images: [String]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(images, id: \.self) { path in
                AsyncImage(url: ImageURLHelper.fullURL(path)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "F5F5F5"))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(Color(hex: "CCCCCC"))
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "F5F5F5"))
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

// MARK: - 卡片底部

struct CardFooter: View {
    let item: UnifiedFeedItem

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "999999"))
                    Text("\(item.likesCount ?? 0)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "666666"))
                }

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "999999"))
                    Text("\(item.commentsCount ?? 0)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "666666"))
                }
            }
        }
    }
}
