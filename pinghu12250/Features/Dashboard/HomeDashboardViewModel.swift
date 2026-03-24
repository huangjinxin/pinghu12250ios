//
//  HomeDashboardViewModel.swift
//  pinghu12250
//
//  学习统计ViewModel - 今日任务
//

import SwiftUI
import Combine

@MainActor
class HomeDashboardViewModel: ObservableObject {
    @Published var tasks: [HomeTaskItem] = []
    private let api = APIService.shared

    func loadTasks() async {
        tasks = [
            HomeTaskItem(id: "diary", name: "日记", icon: "book.fill", iconColor: .purple, bgColor: Color.purple.opacity(0.1), points: 200),
            HomeTaskItem(id: "math", name: "数学", icon: "function", iconColor: .blue, bgColor: Color.blue.opacity(0.1), points: 60),
            HomeTaskItem(id: "poetry", name: "背诗", icon: "text.quote", iconColor: .orange, bgColor: Color.orange.opacity(0.1), points: 55),
            HomeTaskItem(id: "calligraphy", name: "书写", icon: "pencil", iconColor: .pink, bgColor: Color.pink.opacity(0.1), points: 50),
            HomeTaskItem(id: "moments", name: "分享生活", icon: "camera.fill", iconColor: .teal, bgColor: Color.teal.opacity(0.1), points: 3),
            HomeTaskItem(id: "questions", name: "勤学好问", icon: "questionmark.circle.fill", iconColor: .indigo, bgColor: Color.indigo.opacity(0.1), points: 3)
        ]
        await loadTodayStatus()
    }

    private func loadTodayStatus() async {
        do {
            let tz = -TimeZone.current.secondsFromGMT() / 60
            let response: APIResponse<TodayStatusResponse> = try await api.get(
                "/api/submissions/today-status",
                queryItems: [
                    URLQueryItem(name: "templateNames", value: "日记(审批前提项/日),可汗学院数学进度,背诗"),
                    URLQueryItem(name: "timezoneOffset", value: "\(tz)")
                ]
            )
            if let data = response.data {
                for i in 0..<tasks.count {
                    let task = tasks[i]
                    if task.id == "diary", let status = data.todayStatus["日记(审批前提项/日)"], let item = status {
                        tasks[i].status = item.status
                    } else if task.id == "math", let status = data.todayStatus["可汗学院数学进度"], let item = status {
                        tasks[i].status = item.status
                    } else if task.id == "poetry", let status = data.todayStatus["背诗"], let item = status {
                        tasks[i].status = item.status
                    }
                }
            }
        } catch {}

        do {
            let tz = -TimeZone.current.secondsFromGMT() / 60
            let response: APIResponse<CalligraphyTodayResponse> = try await api.get(
                "/api/calligraphy/today-status",
                queryItems: [URLQueryItem(name: "timezoneOffset", value: "\(tz)")]
            )
            if let status = response.data?.status, let index = tasks.firstIndex(where: { $0.id == "calligraphy" }) {
                tasks[index].status = status
            }
        } catch {}
    }
}

struct HomeTaskItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let iconColor: Color
    let bgColor: Color
    let points: Int
    var status: String = "NOT_SUBMITTED"

    var statusIcon: String {
        switch status {
        case "APPROVED": return "checkmark.circle.fill"
        case "PENDING": return "clock.fill"
        case "REJECTED": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    var statusText: String {
        switch status {
        case "APPROVED": return "已完成"
        case "PENDING": return "审核中"
        case "REJECTED": return "已退回"
        default: return "待提交"
        }
    }

    var statusColor: Color {
        switch status {
        case "APPROVED": return .green
        case "PENDING": return .orange
        case "REJECTED": return .red
        default: return .secondary
        }
    }
}

struct CalligraphyTodayResponse: Codable {
    let status: String
}
