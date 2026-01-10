//
//  TimelineView.swift
//  pinghu12250
//
//  心路历程 - 动态发布和浏览
//

import SwiftUI
import Combine

struct TimelineView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var newPostContent = ""
    @State private var isPublic = false
    @State private var isPosting = false
    @State private var activeTab = "personal"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 发布框
                postComposer

                // Tab 切换
                Picker("", selection: $activeTab) {
                    Text("我的动态").tag("personal")
                    Text("公共广场").tag("public")
                }
                .pickerStyle(.segmented)
                .padding()

                // 动态列表
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if posts.isEmpty {
                    emptyView
                } else {
                    postsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("心路历程")
            .refreshable {
                await loadPosts()
            }
        }
        .task {
            await loadPosts()
        }
        .onChange(of: activeTab) { _, _ in
            Task { await loadPosts() }
        }
    }

    // MARK: - 发布框

    private var postComposer: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.appPrimary)
                    )

                VStack(spacing: 8) {
                    TextField("分享你的想法...", text: $newPostContent, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)

                    HStack {
                        Toggle("公开到广场", isOn: $isPublic)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Text("公开到广场")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            Task { await createPost() }
                        } label: {
                            if isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("发布")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPostContent.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 动态列表

    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(posts) { post in
                    PostCard(post: post, onLike: { toggleLike(post) })
                }
            }
            .padding()
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(activeTab == "personal" ? "还没有发布动态" : "暂无公开动态")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 方法

    private func loadPosts() async {
        isLoading = true
        // 使用模拟数据
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Mock data
        posts = [
            Post(id: 1, content: "今天学习了新的知识，感觉收获满满！", authorName: "小明", createdAt: Date(), likesCount: 5, commentsCount: 2, isLiked: false),
            Post(id: 2, content: "完成了一篇很长的日记，写了1500字，超过优秀等级了！", authorName: "小红", createdAt: Date().addingTimeInterval(-3600), likesCount: 12, commentsCount: 3, isLiked: true),
        ]
        isLoading = false
    }

    private func createPost() async {
        guard !newPostContent.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isPosting = true
        // 发布动态
        try? await Task.sleep(nanoseconds: 500_000_000)
        newPostContent = ""
        await loadPosts()
        isPosting = false
    }

    private func toggleLike(_ post: Post) {
        // 切换点赞状态
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isLiked.toggle()
            posts[index].likesCount += posts[index].isLiked ? 1 : -1
        }
    }
}

// MARK: - 动态模型

struct Post: Identifiable {
    let id: Int
    var content: String
    var authorName: String
    var createdAt: Date
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
}

// MARK: - 动态卡片

struct PostCard: View {
    let post: Post
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息
            HStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorName.prefix(1)))
                            .foregroundColor(.appPrimary)
                            .fontWeight(.medium)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .fontWeight(.medium)
                    Text(post.createdAt.relativeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 内容
            Text(post.content)
                .font(.body)

            // 操作栏
            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .secondary)
                        Text("\(post.likesCount)")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.secondary)
                    Text("\(post.commentsCount)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    TimelineView()
}
