//
//  DiaryAchievementsTabView.swift
//  pinghu12250
//
//  日记成就 Tab 视图 - 对应 Web 端 DiaryAchievementsTab
//

import SwiftUI
import Combine

// MARK: - 成就 Tab 视图

struct DiaryAchievementsTabView: View {
    @StateObject private var viewModel = DiaryAchievementsViewModel()
    @State private var selectedCategory: AchievementCategory = .streak

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.achievements.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // 成就统计概览
                        statsOverview

                        // 最近解锁
                        if let recentUnlocks = viewModel.stats?.recentUnlocks, !recentUnlocks.isEmpty {
                            recentUnlocksSection(recentUnlocks)
                        }

                        // 成就分类选择器
                        categoryPicker

                        // 分类说明
                        categoryDescription

                        // 成就列表
                        achievementsList
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - 统计概览

    private var statsOverview: some View {
        HStack {
            HStack(spacing: 12) {
                Text("🏆")
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.stats?.unlocked ?? 0)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("/")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.stats?.total ?? 0)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Text("已解锁成就")
                        .font(.subheadline)
                        .foregroundColor(.orange.opacity(0.8))
                }
            }

            Spacer()

            // 圆形进度
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.stats?.progress ?? 0) / 100)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(viewModel.stats?.progress ?? 0)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - 最近解锁

    private func recentUnlocksSection(_ unlocks: [AchievementItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近解锁")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(unlocks) { achievement in
                        HStack(spacing: 8) {
                            Text(achievement.emoji)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appPrimary)
                                if let date = achievement.unlockedAt {
                                    Text(formatDate(date))
                                        .font(.caption2)
                                        .foregroundColor(.appPrimary.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - 分类选择器

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.appPrimary : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 分类说明

    private var categoryDescription: some View {
        HStack(spacing: 8) {
            Text(selectedCategory.icon)
                .font(.title3)
            Text(selectedCategory.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - 成就列表

    private var achievementsList: some View {
        let categoryAchievements = viewModel.achievements.filter { $0.category == selectedCategory.rawValue }

        return VStack(spacing: 12) {
            if categoryAchievements.isEmpty {
                Text("暂无此类成就")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(categoryAchievements) { achievement in
                    AchievementCard(achievement: achievement)
                }
            }
        }
    }

    // MARK: - 格式化日期

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelative(date)
        }
        return formatRelative(date)
    }

    private func formatRelative(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM-dd HH:mm"
        return outputFormatter.string(from: date)
    }
}

// MARK: - 成就卡片

struct AchievementCard: View {
    let achievement: AchievementItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 成就图标
            Text(achievement.emoji)
                .font(.system(size: 32))
                .frame(width: 52, height: 52)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .opacity(achievement.unlocked ? 1 : 0.4)
                .grayscale(achievement.unlocked ? 0 : 1)

            // 成就信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(achievement.unlocked ? .primary : .secondary)

                    if achievement.unlocked {
                        Text("已解锁")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(achievement.unlocked ? .secondary : .secondary.opacity(0.6))
                    .lineLimit(2)

                HStack {
                    if achievement.unlocked, let date = achievement.unlockedAt {
                        Text("\(formatDate(date)) 解锁")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if achievement.rewardPoints > 0 {
                        Text("+\(achievement.rewardPoints) 积分")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            achievement.unlocked
                ? LinearGradient(colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.unlocked ? Color.orange.opacity(0.3) : Color(.systemGray5), lineWidth: 1)
        )
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelative(date)
        }
        return formatRelative(date)
    }

    private func formatRelative(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM-dd HH:mm"
        return outputFormatter.string(from: date)
    }
}

// MARK: - 成就分类枚举

enum AchievementCategory: String, CaseIterable, Identifiable {
    case streak
    case level
    case grade
    case words
    case rank
    case special

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streak: return "连续打卡"
        case .level: return "单篇字数"
        case .grade: return "高分挑战"
        case .words: return "累计字数"
        case .rank: return "段位达成"
        case .special: return "特殊成就"
        }
    }

    var icon: String {
        switch self {
        case .streak: return "🔥"
        case .level: return "📝"
        case .grade: return "⭐"
        case .words: return "📊"
        case .rank: return "🎖️"
        case .special: return "🎁"
        }
    }

    var description: String {
        switch self {
        case .streak: return "坚持每天写日记，连续打卡达到指定天数即可解锁。断签后需重新开始累计。"
        case .level: return "单篇日记达到指定字数等级即可解锁。字数只统计文字，不含标点和空格。"
        case .grade: return "通过 AI 分析获得指定等级评分即可解锁。"
        case .words: return "所有日记的总字数累计达到指定数量即可解锁。"
        case .rank: return "通过持续写作提升段位，达到指定段位即可解锁。"
        case .special: return "完成特殊任务或在特定时间写日记即可解锁。"
        }
    }
}

// MARK: - 数据模型

struct AchievementItem: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let category: String
    let unlocked: Bool
    let unlockedAt: String?
    let rewardPoints: Int

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, description, category, unlocked, unlockedAt, rewardPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🏆"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "special"
        unlocked = try container.decodeIfPresent(Bool.self, forKey: .unlocked) ?? false
        unlockedAt = try container.decodeIfPresent(String.self, forKey: .unlockedAt)
        rewardPoints = try container.decodeIfPresent(Int.self, forKey: .rewardPoints) ?? 0
    }
}

struct AchievementStats: Codable {
    let unlocked: Int
    let total: Int
    let progress: Int
    let recentUnlocks: [AchievementItem]?
}

struct AchievementsResponse: Codable {
    let success: Bool
    let data: [AchievementItem]?
    let error: String?
}

struct AchievementStatsResponse: Codable {
    let success: Bool
    let data: AchievementStats?
    let error: String?
}

// MARK: - ViewModel

class DiaryAchievementsViewModel: ObservableObject {
    @Published var achievements: [AchievementItem] = []
    @Published var stats: AchievementStats?
    @Published var isLoading = false
    @Published var error: String?

    @MainActor
    func loadData() async {
        isLoading = true
        error = nil

        do {
            let achievementsRes: AchievementsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.diaryGameAchievements
            )
            let statsRes: AchievementStatsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.diaryGameAchievementsStats
            )

            if achievementsRes.success, let data = achievementsRes.data {
                achievements = data
            } else if let err = achievementsRes.error {
                error = err
            }

            if statsRes.success, let data = statsRes.data {
                stats = data
            }

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    DiaryAchievementsTabView()
}
