//
//  NewHomeDashboardView.swift
//  pinghu12250
//
//  新首页视图
//

import SwiftUI
import Combine

struct NewHomeDashboardView: View {
    @StateObject private var viewModel = NewHomeDashboardViewModel()
    @StateObject private var authManager = AuthManager.shared
    @State private var showWebView = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部栏
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting).font(.subheadline).foregroundColor(.secondary)
                            Text(authManager.currentUser?.displayName ?? "同学").font(.title2).bold()
                        }
                        Spacer()
                        Button {
                            showWebView = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("📊")
                                Text("进度看板").font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)

                    // 今日任务大卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🚩 今日任务").font(.headline)
                            Spacer()
                            Text("查看全部 →").font(.system(size: 13)).foregroundColor(.blue)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewModel.tasks) { task in
                                TodayTaskCard(task: task) {
                                    handleTaskTap(task)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 排行榜
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.leaderboards, id: \.key) { board in
                            LeaderboardCard(
                                icon: board.icon,
                                title: board.title,
                                items: board.items,
                                color: board.color
                            ) {
                                showWebView = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            .navigationTitle("苹湖少儿空间")
            .refreshable {
                await viewModel.loadData()
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showWebView) {
            WebViewSheet(url: "http://localhost:12250/leaderboard")
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了" }
        if hour < 9 { return "早上好" }
        if hour < 12 { return "上午好" }
        if hour < 14 { return "中午好" }
        if hour < 18 { return "下午好" }
        if hour < 22 { return "晚上好" }
        return "夜深了"
    }

    private func handleTaskTap(_ task: TaskItem) {
        // TODO: 跳转到对应页面
    }
}
