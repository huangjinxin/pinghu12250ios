//
//  HomeView.swift
//  pinghu12250
//
//  首页视图
//

import SwiftUI

struct HomeView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var recentTextbooks: [Textbook] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 欢迎卡片
                    welcomeCard

                    // 快捷入口
                    quickActions

                    // 最近浏览
                    if !recentTextbooks.isEmpty {
                        recentSection
                    }

                    // 学习统计（占位）
                    statsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("苹湖少儿空间")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await loadData()
        }
    }

    // MARK: - 欢迎卡片

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SelectableText.secondary(greeting)

                    SelectableText(
                        text: authManager.currentUser?.displayName ?? "同学",
                        font: .preferredFont(forTextStyle: .title2),
                        textColor: .label
                    )
                }

                Spacer()

                // 头像
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.appPrimary)
                    )
            }

            // 今日一言
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundColor(.appPrimary)
                SelectableText.secondary("学而时习之，不亦说乎")
            }
            .padding(.top, 8)
        }
        .cardStyle()
    }

    // MARK: - 快捷入口

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷入口")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionButton(
                    icon: "book.fill",
                    title: "语文",
                    color: .subjectChinese
                )

                QuickActionButton(
                    icon: "function",
                    title: "数学",
                    color: .subjectMath
                )

                QuickActionButton(
                    icon: "textformat.abc",
                    title: "英语",
                    color: .subjectEnglish
                )

                QuickActionButton(
                    icon: "flask.fill",
                    title: "科学",
                    color: .subjectScience
                )
            }
        }
    }

    // MARK: - 最近浏览

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近浏览")
                    .font(.headline)
                Spacer()
                Button("查看全部") {
                    // Navigate to textbooks
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentTextbooks) { textbook in
                        TextbookCard(textbook: textbook)
                    }
                }
            }
        }
    }

    // MARK: - 学习统计

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习统计")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 16) {
                StatItem(value: "12", label: "已读教材", icon: "book.closed.fill", color: .appPrimary)
                StatItem(value: "56", label: "学习笔记", icon: "note.text", color: .appSecondary)
                StatItem(value: "128", label: "学习时长", icon: "clock.fill", color: .appAccent)
            }
            .cardStyle()
        }
    }

    // MARK: - 计算属性

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<22: return "晚上好"
        default: return "夜深了"
        }
    }

    // MARK: - 方法

    private func loadData() async {
        // 加载首页数据
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
}

// MARK: - 快捷入口按钮

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                )

            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 统计项

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            SelectableText(
                text: value,
                font: .preferredFont(forTextStyle: .title2),
                textColor: .label
            )

            SelectableText.caption(label)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 教材卡片（简版）

struct TextbookCard: View {
    let textbook: Textbook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.forSubject(textbook.subject).opacity(0.2))
                .frame(width: 120, height: 160)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color.forSubject(textbook.subject))
                )

            // 标题
            Text(textbook.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)

            // 科目标签
            Text(textbook.subjectName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HomeView()
}
