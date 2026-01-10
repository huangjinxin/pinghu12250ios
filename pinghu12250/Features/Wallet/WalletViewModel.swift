//
//  WalletViewModel.swift
//  pinghu12250
//
//  钱包 ViewModel - 钱包和支付功能
//

import Foundation
import SwiftUI
import Combine

@MainActor
class WalletViewModel: ObservableObject {
    // MARK: - 数据

    @Published var userPoints: Int = 0
    @Published var walletBalance: Double = 0
    @Published var transactions: [WalletTransaction] = []
    @Published var payOrders: [PayOrder] = []
    @Published var pointLogs: [PointLog] = []
    @Published var exchangeRecords: [ExchangeRecord] = []
    @Published var leaderboard: [LeaderboardUser] = []

    // MARK: - 状态

    @Published var isLoading = false
    @Published var isLoadingTransactions = false
    @Published var isLoadingPointLogs = false
    @Published var isLoadingExchangeRecords = false
    @Published var isLoadingLeaderboard = false
    @Published var isLoadingPayOrders = false
    @Published var errorMessage: String?

    // MARK: - 分页状态

    private let pageSize = 20

    @Published var pointLogsPage = 1
    @Published var pointLogsHasMore = true

    @Published var transactionsPage = 1
    @Published var transactionsHasMore = true

    @Published var exchangeRecordsPage = 1
    @Published var exchangeRecordsHasMore = true

    @Published var payOrdersPage = 1
    @Published var payOrdersHasMore = true

    // MARK: - 支付相关

    @Published var scannedPayCode: PayCode?
    @Published var isScanning = false
    @Published var showPaymentConfirm = false
    @Published var showPasswordInput = false
    @Published var paymentSuccess = false
    @Published var lastOrder: PayOrder?

    // MARK: - 兑换配置

    @Published var pointsPerCoin: Int = 10
    @Published var coinsPerExchange: Int = 1
    @Published var exchangeDailyLimit: Int = 5000
    @Published var exchangeRemainingLimit: Int = 5000
    @Published var exchangeTodayUsed: Int = 0

    // MARK: - 加载所有数据

    func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadWallet() }
            group.addTask { await self.loadUserPoints() }
            group.addTask { await self.loadExchangeConfig() }
            group.addTask { await self.loadLeaderboard() }
        }
    }

    // MARK: - 加载钱包余额

    func loadWallet() async {
        do {
            let response: WalletResponse = try await APIService.shared.get(
                APIConfig.Endpoints.wallet
            )
            if let wallet = response.wallet {
                walletBalance = wallet.balanceValue
            } else if let balance = response.balance {
                walletBalance = balance.value
            }
            #if DEBUG
            print("加载钱包成功: \(walletBalance)")
            #endif
        } catch {
            #if DEBUG
            print("加载钱包失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载用户积分

    func loadUserPoints() async {
        do {
            struct PointsResponse: Decodable {
                let totalPoints: Int?
                let availablePoints: Int?
            }
            let response: PointsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.pointsMy
            )
            userPoints = response.totalPoints ?? 0
            #if DEBUG
            print("加载积分成功: \(userPoints)")
            #endif
        } catch {
            #if DEBUG
            print("加载积分失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载兑换配置

    func loadExchangeConfig() async {
        do {
            let response: ExchangeConfigResponse = try await APIService.shared.get(
                APIConfig.Endpoints.pointsExchangeConfig
            )
            // 优先使用 rate 中的配置
            if let rate = response.rate {
                pointsPerCoin = rate.points ?? 100
                coinsPerExchange = rate.coins ?? 10
            } else if let ratio = response.pointsPerCoin {
                pointsPerCoin = ratio
            }
            if let limit = response.dailyLimit {
                exchangeDailyLimit = limit
            }
            if let remaining = response.remainingLimit {
                exchangeRemainingLimit = remaining
            }
            if let used = response.todayUsed {
                exchangeTodayUsed = used
            }
        } catch {
            #if DEBUG
            print("加载兑换配置失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载积分明细

    func loadPointLogs(refresh: Bool = false) async {
        if refresh {
            pointLogsPage = 1
            pointLogsHasMore = true
        }

        guard pointLogsHasMore else { return }
        isLoadingPointLogs = true
        defer { isLoadingPointLogs = false }

        do {
            let response: PointLogsResponse = try await APIService.shared.get(
                APIConfig.Endpoints.pointsLogs,
                queryItems: [
                    URLQueryItem(name: "page", value: "\(pointLogsPage)"),
                    URLQueryItem(name: "limit", value: "\(pageSize)")
                ]
            )

            if refresh {
                pointLogs = response.allLogs
            } else {
                pointLogs.append(contentsOf: response.allLogs)
            }

            if let pagination = response.pagination {
                pointLogsHasMore = pointLogsPage < pagination.totalPages
            } else {
                pointLogsHasMore = response.allLogs.count >= pageSize
            }
            pointLogsPage += 1
            #if DEBUG
            print("加载积分明细成功: \(pointLogs.count) 条")
            #endif
        } catch {
            #if DEBUG
            print("加载积分明细失败: \(error)")
            #endif
            if refresh {
                pointLogs = []
            }
        }
    }

    // MARK: - 加载兑换记录

    func loadExchangeRecords(refresh: Bool = false) async {
        if refresh {
            exchangeRecordsPage = 1
            exchangeRecordsHasMore = true
        }

        guard exchangeRecordsHasMore else { return }
        isLoadingExchangeRecords = true
        defer { isLoadingExchangeRecords = false }

        do {
            let response: ExchangeHistoryResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.pointsExchangeHistory)?page=\(exchangeRecordsPage)&limit=\(pageSize)"
            )

            let records = response.exchanges ?? []
            if refresh {
                exchangeRecords = records
            } else {
                exchangeRecords.append(contentsOf: records)
            }

            if let pagination = response.pagination {
                exchangeRecordsHasMore = exchangeRecordsPage < pagination.totalPages
            } else {
                exchangeRecordsHasMore = records.count >= pageSize
            }
            exchangeRecordsPage += 1
        } catch {
            #if DEBUG
            print("加载兑换记录失败: \(error)")
            #endif
            if refresh {
                exchangeRecords = []
            }
        }
    }

    // MARK: - 加载积分排行榜（倒数TOP5）

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            let response: PointsLeaderboardResponse = try await APIService.shared.get(
                APIConfig.Endpoints.pointsLeaderboard,
                queryItems: [
                    URLQueryItem(name: "limit", value: "5"),
                    URLQueryItem(name: "order", value: "asc")
                ]
            )
            leaderboard = response.leaderboard ?? []
        } catch {
            #if DEBUG
            print("加载排行榜失败: \(error)")
            #endif
            leaderboard = []
        }
    }

    // MARK: - 加载交易记录

    func loadTransactions(refresh: Bool = false) async {
        if refresh {
            transactionsPage = 1
            transactionsHasMore = true
        }

        guard transactionsHasMore else { return }
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }

        do {
            let response: WalletTransactionsResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.walletTransactions)?page=\(transactionsPage)&limit=\(pageSize)"
            )

            if refresh {
                transactions = response.transactions
            } else {
                transactions.append(contentsOf: response.transactions)
            }

            if let pagination = response.pagination {
                transactionsHasMore = transactionsPage < pagination.totalPages
            } else {
                transactionsHasMore = response.transactions.count >= pageSize
            }
            transactionsPage += 1
        } catch {
            #if DEBUG
            print("加载交易记录失败: \(error)")
            #endif
            if refresh {
                transactions = []
            }
        }
    }

    // MARK: - 加载支付订单

    func loadPayOrders(refresh: Bool = false) async {
        if refresh {
            payOrdersPage = 1
            payOrdersHasMore = true
        }

        guard payOrdersHasMore else { return }
        isLoadingPayOrders = true
        defer { isLoadingPayOrders = false }

        do {
            let response: PayOrdersResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.payOrders)?page=\(payOrdersPage)&limit=\(pageSize)"
            )

            if refresh {
                payOrders = response.orders
            } else {
                payOrders.append(contentsOf: response.orders)
            }

            if let pagination = response.pagination {
                payOrdersHasMore = payOrdersPage < pagination.totalPages
            } else {
                payOrdersHasMore = response.orders.count >= pageSize
            }
            payOrdersPage += 1
            #if DEBUG
            print("加载支付订单成功: \(payOrders.count) 条")
            #endif
        } catch {
            #if DEBUG
            print("加载支付订单失败: \(error)")
            #endif
            if case let APIError.decodingError(decodingError) = error {
                #if DEBUG
                print("解码错误详情: \(decodingError)")
                #endif
            }
            if refresh {
                payOrders = []
            }
        }
    }

    // MARK: - 扫码支付

    func scanPayCode(_ code: String) async -> Bool {
        do {
            let response: PayCodeResponse = try await APIService.shared.get(
                "\(APIConfig.Endpoints.payScan)/\(code)"
            )
            scannedPayCode = response.payCode
            showPaymentConfirm = true
            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "扫码失败，请重试"
            return false
        }
    }

    // MARK: - 提交支付

    func submitPayment(password: String) async -> Bool {
        guard let payCode = scannedPayCode else {
            errorMessage = "支付信息无效"
            return false
        }

        // 检查余额
        if walletBalance < payCode.amount {
            errorMessage = "学习币余额不足"
            return false
        }

        do {
            let request = PaymentSubmitRequest(
                payCodeId: payCode.id,
                paymentPassword: password
            )
            let response: PaymentSubmitResponse = try await APIService.shared.post(
                APIConfig.Endpoints.paySubmit,
                body: request
            )
            lastOrder = response.order
            paymentSuccess = true
            scannedPayCode = nil
            showPaymentConfirm = false
            showPasswordInput = false

            // 刷新钱包数据
            await loadWallet()
            await loadTransactions()

            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "支付失败，请重试"
            return false
        }
    }

    // MARK: - 积分兑换

    func exchangePoints(_ points: Int) async -> Bool {
        guard points >= pointsPerCoin else {
            errorMessage = "兑换积分不足"
            return false
        }

        guard userPoints >= points else {
            errorMessage = "积分不足"
            return false
        }

        do {
            let request = ExchangeRequest(points: points)
            let response: ExchangeResponse = try await APIService.shared.post(
                APIConfig.Endpoints.pointsExchange,
                body: request
            )
            if let newBalance = response.newBalance {
                walletBalance = newBalance
            }
            userPoints -= points

            // 刷新相关数据
            await loadExchangeConfig()
            await loadExchangeRecords()
            await loadPointLogs()

            return true
        } catch let error as APIError {
            switch error {
            case .serverError(_, let message):
                errorMessage = message
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "兑换失败，请重试"
            return false
        }
    }

    // MARK: - 复制支付凭证

    func copyReceipt(for order: PayOrder, username: String) -> String {
        let dateString = order.createdAt?.toDate?.formattedDateTime ?? order.createdAt ?? ""

        return """
        【支付凭证】
        用户：\(username)
        项目：\(order.title)
        金额：\(String(format: "%.2f", order.amountValue)) 学习币
        订单号：\(order.orderNo)
        支付时间：\(dateString)
        状态：已完成
        """
    }

    // MARK: - 重置状态

    func resetPaymentState() {
        scannedPayCode = nil
        showPaymentConfirm = false
        showPasswordInput = false
        paymentSuccess = false
        lastOrder = nil
        errorMessage = nil
    }
}
