//
//  ExchangeViewModel.swift
//  pinghu12250
//
//  积分兑换视图模型
//

import Foundation
import Combine

@MainActor
class ExchangeViewModel: ObservableObject {
    @Published var currentPoints: Int = 0
    @Published var exchangeAmount: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var exchangeSuccess = false

    private let apiService = APIService.shared
    private let exchangeRate = 10 // 10积分 = 1虎币

    var coinsToReceive: Double {
        Double(exchangeAmount) ?? 0 / Double(exchangeRate)
    }

    func loadBalance() async {
        isLoading = true
        do {
            let response: APIResponse<PointLogsResponse> = try await apiService.get("/api/points/records")
            if let totalPoints = response.data?.totalPoints {
                currentPoints = totalPoints
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func exchange() async {
        guard let points = Int(exchangeAmount), points > 0 else {
            errorMessage = "请输入有效的积分数量"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = ExchangeRequest(points: points)
            let response: APIResponse<ExchangeResponse> = try await apiService.post("/api/wallet/exchange", body: request)

            if response.success == true {
                exchangeSuccess = true
            } else {
                errorMessage = response.error ?? response.message ?? "兑换失败"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
