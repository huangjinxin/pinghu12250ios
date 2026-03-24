//
//  HomeDashboardView.swift
//  pinghu12250
//
//  学习统计 - 今日任务（简化版）
//

import SwiftUI

struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeDashboardViewModel()
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 问候语
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text(displayName)
                            .font(.system(size: 24, weight: .bold))
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // 今日任务
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.blue)
                        Text("今日任务")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(viewModel.tasks) { task in
                            HomeTaskCard(task: task)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("学习统计")
        .task {
            await viewModel.loadTasks()
        }
        .refreshable {
            await viewModel.loadTasks()
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了" }
        if hour < 9 { return "早上好" }
        if hour < 12 { return "上午好" }
        if hour < 14 { return "中午好" }
        if hour < 18 { return "下午好" }
        if hour < 22 { return "晚上好" }
        return "夜深了"
    }

    private var displayName: String {
        authManager.currentUser?.profile?.nickname ?? authManager.currentUser?.username ?? "同学"
    }
}

private struct HomeTaskCard: View {
    let task: HomeTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.icon)
                    .font(.system(size: 20))
                    .foregroundColor(task.iconColor)
                    .frame(width: 36, height: 36)
                    .background(task.bgColor)
                    .cornerRadius(8)

                Spacer()

                if task.points > 0 {
                    Text("+\(task.points)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Text(task.name)
                .font(.system(size: 15, weight: .medium))

            HStack(spacing: 4) {
                Image(systemName: task.statusIcon)
                    .font(.system(size: 12))
                Text(task.statusText)
                    .font(.system(size: 12))
            }
            .foregroundColor(task.statusColor)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
