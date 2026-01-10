//
//  DailyChallengeDetailView.swift
//  pinghu12250
//
//  每日挑战详情弹窗

import SwiftUI

struct DailyChallengeDetailView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRewardInfo = false
    @State private var claimScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部横幅
                    heroBanner

                    // 奖励规则说明
                    rewardInfoCard

                    // 今日总览
                    statsRow

                    // 领取奖励区域
                    rewardClaimSection

                    // 三项挑战
                    challengeCards
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("每日挑战")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .alert("领取成功", isPresented: $viewModel.showClaimSuccess) {
            Button("太棒了！", role: .cancel) { }
        } message: {
            if let data = viewModel.claimedRewardData {
                Text("恭喜获得 \(data.totalPoints) 积分！\n基础奖励 \(data.basePoints) + 连续\(data.streakDays)天奖励 \(data.streakPoints)")
            }
        }
    }

    // MARK: - 顶部横幅

    private var heroBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("每日挑战")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("完成三项挑战，收获成长积分")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 倒计时
            VStack(spacing: 2) {
                Text("距离刷新")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                Text(countdownText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var countdownText: String {
        let now = Date()
        var next8am = Calendar.current.startOfDay(for: now)
        next8am = Calendar.current.date(byAdding: .hour, value: 8, to: next8am)!

        if now >= next8am {
            next8am = Calendar.current.date(byAdding: .day, value: 1, to: next8am)!
        }

        let diff = next8am.timeIntervalSince(now)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - 奖励规则说明

    private var rewardInfoCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showRewardInfo.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("完成奖励规则")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showRewardInfo ? 180 : 0))
                }
                .padding()
            }

            if showRewardInfo, let config = viewModel.rewardStatus?.config {
                VStack(spacing: 12) {
                    // 奖励公式
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("基础奖励")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(config.basePoints)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("积分")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text("+")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)

                        VStack(spacing: 4) {
                            Text("连续奖励")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(config.streakBonus)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("× 连续天数")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(12)

                    Text("每日完成3项审核通过后可领取奖励，连续天数最高计算\(config.streakMaxDays)天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    let examplePoints = config.basePoints + config.streakBonus * 10
                    Text("例：连续完成10天，可获得 \(config.basePoints) + \(config.streakBonus) × 10 = **\(examplePoints)** 积分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 今日总览

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatItemView(
                icon: "🎯",
                value: "\(viewModel.completedCount)/3",
                label: "今日完成"
            )

            StatItemView(
                icon: "⭐",
                value: "+\(viewModel.todayPoints)",
                label: "今日积分"
            )

            StatItemView(
                icon: "🔥",
                value: "\(viewModel.approvalStreak)天",
                label: "连续完成"
            )
        }
    }

    // MARK: - 领取奖励区域

    @ViewBuilder
    private var rewardClaimSection: some View {
        if let status = viewModel.rewardStatus {
            if status.claimed {
                // 已领取
                HStack(spacing: 12) {
                    Text("🎉")
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日奖励已领取")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)

                        if let reward = status.claimedReward {
                            Text("获得 \(reward.totalPoints) 积分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            + Text(reward.streakDays > 0 ? " (含连续\(reward.streakDays)天奖励)" : "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)

            } else if status.canClaim {
                // 可领取
                Button {
                    Task {
                        await viewModel.claimReward()
                    }
                } label: {
                    HStack(spacing: 16) {
                        Text("🎁")
                            .font(.system(size: 40))
                            .scaleEffect(claimScale)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                    claimScale = 1.1
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("点击领取今日奖励")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.57, green: 0.25, blue: 0.05))

                            if let reward = status.estimatedReward {
                                HStack(spacing: 4) {
                                    Text("可获得")
                                        .font(.caption)
                                    Text("\(reward.totalPoints)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("积分")
                                        .font(.caption)
                                }
                                .foregroundColor(Color(red: 0.7, green: 0.35, blue: 0.05))
                            }
                        }

                        Spacer()

                        if viewModel.isClaimingReward {
                            ProgressView()
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(viewModel.isClaimingReward)

            } else {
                // 未满足条件
                HStack(spacing: 12) {
                    Text("📝")
                        .font(.title)

                    Text("还需完成 \(3 - status.approvedCount) 项审核通过后可领取奖励")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 挑战卡片

    private var challengeCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日挑战")
                .font(.headline)

            ForEach(CheckInItem.allItems) { item in
                ChallengeCardView(
                    item: item,
                    status: viewModel.getStatus(for: item)
                )
            }
        }
    }
}

// MARK: - 子视图

struct StatItemView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ChallengeCardView: View {
    let item: CheckInItem
    let status: CheckInStatus

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [item.color, item.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: item.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 积分
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(item.points)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("积分")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            status == .approved
                ? LinearGradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color(.systemBackground), Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    status == .approved ? Color.green.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .overlay(alignment: .bottomTrailing) {
            // 状态标签
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 10))
                Text(status.displayText)
                    .font(.caption2)
            }
            .foregroundColor(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusBackgroundColor)
            .cornerRadius(12)
            .padding(8)
        }
        .overlay(
            // 左侧彩色边条
            Rectangle()
                .fill(item.color)
                .frame(width: 4)
                .cornerRadius(2),
            alignment: .leading
        )
    }

    private var statusBackgroundColor: Color {
        switch status {
        case .notSubmitted:
            return Color(.systemGray6)
        case .pending:
            return Color.orange.opacity(0.15)
        case .approved:
            return Color.green.opacity(0.15)
        case .rejected:
            return Color.red.opacity(0.15)
        }
    }
}

#Preview {
    DailyChallengeDetailView(viewModel: DashboardViewModel())
}
