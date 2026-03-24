//
//  TodayTaskCard.swift
//  pinghu12250
//
//  今日任务卡片
//

import SwiftUI

enum TaskStatus {
    case pending, reviewing, completed, rejected

    var text: String {
        switch self {
        case .pending: return "待提交"
        case .reviewing: return "待审核"
        case .completed: return "已完成"
        case .rejected: return "已退回"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .reviewing: return .orange
        case .completed: return .green
        case .rejected: return .red
        }
    }
}

struct TaskItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let points: Int
    let status: TaskStatus
    let bgColor: Color
}

struct TodayTaskCard: View {
    let task: TaskItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle().fill(task.bgColor).frame(width: 50, height: 50)
                        .overlay(Text(task.icon).font(.system(size: 24)))

                    if task.points > 0 {
                        Text("+\(task.points)").font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1)).cornerRadius(8)
                    }
                }

                Text(task.name).font(.system(size: 14, weight: .medium))

                HStack(spacing: 4) {
                    Circle().fill(task.status.color).frame(width: 6, height: 6)
                    Text(task.status.text).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
