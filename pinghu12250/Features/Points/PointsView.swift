//
//  PointsView.swift
//  pinghu12250
//
//  积分系统页面
//

import SwiftUI
import Combine

struct PointsView: View {
    @StateObject private var vm = PointsViewModel()
    @State private var showExchange = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                balanceCard
                historySection
            }
            .padding()
        }
        .navigationTitle("我的积分")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("兑换") {
                    showExchange = true
                }
            }
        }
        .sheet(isPresented: $showExchange) {
            PointExchangeView()
        }
        .task {
            await vm.loadData()
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 16) {
            Text("当前积分")
                .font(.system(size: 16))
                .foregroundColor(.messageSecondaryText)

            Text("\(vm.totalPoints)")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.appPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.messageBorder, lineWidth: 1)
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("积分历史")
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 0) {
                ForEach(vm.logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.displayDescription)
                                .font(.system(size: 15))
                            if let createdAt = log.createdAt {
                                Text(formatDate(createdAt))
                                    .font(.system(size: 13))
                                    .foregroundColor(.messageSecondaryText)
                            }
                        }
                        Spacer()
                        Text(log.displayPoints)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(log.isPositive ? .appSuccess : .appError)
                    }
                    .padding()
                    Divider()
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.messageBorder, lineWidth: 1)
            )
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}

@MainActor
class PointsViewModel: ObservableObject {
    @Published var totalPoints: Int = 0
    @Published var logs: [PointLog] = []
    @Published var isLoading = false

    private let apiService = APIService.shared

    func loadData() async {
        isLoading = true
        await loadLogs()
        isLoading = false
    }

    private func loadLogs() async {
        do {
            let response: APIResponse<PointLogsResponse> = try await apiService.get("/api/points/records")
            if let data = response.data {
                totalPoints = data.totalPoints ?? 0
                logs = data.allLogs
            }
        } catch {}
    }
}
