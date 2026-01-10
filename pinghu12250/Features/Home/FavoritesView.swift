//
//  FavoritesView.swift
//  pinghu12250
//
//  收藏页面
//

import SwiftUI
import Combine

struct FavoritesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var favorites: [Textbook] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if !authManager.isAuthenticated {
                    notLoggedInView
                } else if isLoading {
                    ProgressView("加载中...")
                } else if favorites.isEmpty {
                    emptyView
                } else {
                    favoritesList
                }
            }
            .navigationTitle("我的收藏")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .task {
            if authManager.isAuthenticated {
                await loadFavorites()
            }
        }
    }

    // MARK: - 未登录视图

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("登录后查看收藏")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("收藏的教材会同步到云端")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有收藏")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("浏览教材时点击收藏按钮")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 收藏列表

    private var favoritesList: some View {
        List {
            ForEach(favorites) { textbook in
                NavigationLink(destination: Text(textbook.title)) {
                    HStack(spacing: 12) {
                        // 封面
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.forSubject(textbook.subject).opacity(0.2))
                            .frame(width: 50, height: 66)
                            .overlay(
                                Image(systemName: "book.fill")
                                    .foregroundColor(Color.forSubject(textbook.subject))
                            )

                        // 信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(textbook.title)
                                .font(.headline)
                                .lineLimit(1)

                            Text("\(textbook.gradeName) · \(textbook.subjectName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadFavorites()
        }
    }

    // MARK: - 方法

    private func loadFavorites() async {
        isLoading = true
        // 加载收藏数据
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
}

#Preview {
    FavoritesView()
}
