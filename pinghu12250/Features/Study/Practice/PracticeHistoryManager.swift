//
//  PracticeHistoryManager.swift
//  pinghu12250
//
//  练习历史记录管理
//

import Foundation

// MARK: - 练习历史管理器

class PracticeHistoryManager {
    static let shared = PracticeHistoryManager()

    private let storageKey = "practice_history_records"
    private let maxRecords = 100

    private init() {}

    // MARK: - 保存记录

    func saveSession(_ session: PracticeSession, textbookTitle: String) {
        guard session.isCompleted else { return }

        let record = PracticeRecord(from: session, textbookTitle: textbookTitle)
        var records = loadRecords()
        records.insert(record, at: 0)

        // 限制记录数量
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        saveRecords(records)
    }

    // MARK: - 加载记录

    func loadRecords() -> [PracticeRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([PracticeRecord].self, from: data) else {
            return []
        }
        return records
    }

    // MARK: - 获取统计数据

    func getStatistics() -> PracticeStatistics {
        let records = loadRecords()

        let totalSessions = records.count
        let totalQuestions = records.reduce(0) { $0 + $1.questionCount }
        let totalCorrect = records.reduce(0) { $0 + $1.correctCount }
        let totalTime = records.reduce(0) { $0 + $1.totalTime }

        let averageAccuracy = totalQuestions > 0
            ? Double(totalCorrect) / Double(totalQuestions)
            : 0

        // 计算连续天数
        let streak = calculateStreak(records: records)

        // 今日练习
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecords = records.filter {
            Calendar.current.isDate($0.completedAt, inSameDayAs: today)
        }

        return PracticeStatistics(
            totalSessions: totalSessions,
            totalQuestions: totalQuestions,
            totalCorrect: totalCorrect,
            averageAccuracy: averageAccuracy,
            totalTime: totalTime,
            streak: streak,
            todaySessions: todayRecords.count,
            todayQuestions: todayRecords.reduce(0) { $0 + $1.questionCount }
        )
    }

    // MARK: - 按教材获取记录

    func getRecords(for textbookId: String) -> [PracticeRecord] {
        return loadRecords().filter { $0.textbookId == textbookId }
    }

    // MARK: - 清除历史

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func deleteRecord(_ id: UUID) {
        var records = loadRecords()
        records.removeAll { $0.id == id }
        saveRecords(records)
    }

    // MARK: - 私有方法

    private func saveRecords(_ records: [PracticeRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func calculateStreak(records: [PracticeRecord]) -> Int {
        guard !records.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // 检查今天是否有练习
        let hasTodayRecord = records.contains { calendar.isDate($0.completedAt, inSameDayAs: currentDate) }

        if hasTodayRecord {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // 向前检查连续天数
        while let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
            let hasRecord = records.contains { calendar.isDate($0.completedAt, inSameDayAs: currentDate) }
            if hasRecord {
                streak += 1
                currentDate = previousDate
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - 练习统计

struct PracticeStatistics {
    let totalSessions: Int
    let totalQuestions: Int
    let totalCorrect: Int
    let averageAccuracy: Double
    let totalTime: TimeInterval
    let streak: Int
    let todaySessions: Int
    let todayQuestions: Int

    var averageTimePerQuestion: TimeInterval {
        guard totalQuestions > 0 else { return 0 }
        return totalTime / Double(totalQuestions)
    }
}

// MARK: - 练习历史视图

import SwiftUI

struct PracticeHistoryView: View {
    @State private var records: [PracticeRecord] = []
    @State private var statistics: PracticeStatistics?
    @State private var showClearAlert = false

    var body: some View {
        List {
            // 统计卡片
            if let stats = statistics {
                Section {
                    statisticsCard(stats)
                }
            }

            // 历史记录
            Section("练习记录") {
                if records.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("暂无练习记录")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    ForEach(records) { record in
                        recordRow(record)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .navigationTitle("练习历史")
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("确认清空", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                PracticeHistoryManager.shared.clearHistory()
                loadData()
            }
        } message: {
            Text("确定要清空所有练习记录吗？此操作不可恢复。")
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        records = PracticeHistoryManager.shared.loadRecords()
        statistics = PracticeHistoryManager.shared.getStatistics()
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            PracticeHistoryManager.shared.deleteRecord(records[index].id)
        }
        loadData()
    }

    // MARK: - 统计卡片

    private func statisticsCard(_ stats: PracticeStatistics) -> some View {
        VStack(spacing: 16) {
            // 今日进度
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日练习")
                        .font(.headline)
                    Text("\(stats.todayQuestions) 道题")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if stats.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("连续 \(stats.streak) 天")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Divider()

            // 累计统计
            HStack(spacing: 20) {
                statItem(value: "\(stats.totalSessions)", label: "练习次数", icon: "book.fill", color: .blue)
                statItem(value: "\(stats.totalQuestions)", label: "答题总数", icon: "questionmark.circle.fill", color: .purple)
                statItem(value: stats.averageAccuracy.percentageString, label: "平均正确率", icon: "checkmark.circle.fill", color: .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 记录行

    private func recordRow(_ record: PracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.textbookTitle.isEmpty ? "教材练习" : record.textbookTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Text(record.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                // 正确率
                HStack(spacing: 4) {
                    Circle()
                        .fill(record.accuracy >= 0.6 ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(record.accuracy.percentageString)
                        .font(.caption)
                        .foregroundColor(record.accuracy >= 0.6 ? .green : .orange)
                }

                // 题数
                Text("\(record.correctCount)/\(record.questionCount) 题")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 用时
                Text(record.totalTime.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 页码
                if let page = record.pageIndex {
                    Text("P\(page + 1)")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        PracticeHistoryView()
    }
}
