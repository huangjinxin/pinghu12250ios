//
//  WalletView.swift
//  pinghu12250
//
//  钱包页面 - 积分和学习币管理、扫码支付
//

import SwiftUI
import AVFoundation
import AudioToolbox
import Combine

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var activeTab = "points"
    @State private var showExchangeSheet = false
    @State private var showScanner = false
    @State private var manualCodeInput = ""
    @State private var showManualInput = false
    @State private var showExchangeInfo = false  // 兑换说明弹窗
    @State private var isLeaderboardExpanded = false  // 排行榜折叠状态

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 四个功能卡片一行
                quickActionCards

                // 兑换说明（问号按钮）
                exchangeInfoButton

                // 积分倒数排行榜（可折叠）
                leaderboardSection

                // 明细标签页
                detailTabs
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.loadAllData()
            await refreshCurrentTab()
        }
        .sheet(isPresented: $showExchangeSheet) {
            ExchangeSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showScanner) {
            QRCodeScannerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showManualInput) {
            ManualCodeInputSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPaymentConfirm) {
            PaymentConfirmSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.paymentSuccess) {
            PaymentSuccessSheet(viewModel: viewModel)
        }
        .alert("兑换说明", isPresented: $showExchangeInfo) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("学习币是稀缺货币，可以通过积分兑换获得。\n\n当前兑换比例：\(viewModel.pointsPerCoin) 积分 = \(viewModel.coinsPerExchange) 学习币\n\n每日兑换上限：\(viewModel.exchangeDailyLimit) 积分\n今日剩余：\(viewModel.exchangeRemainingLimit) 积分")
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadAllData()
            // 初始加载积分明细
            await viewModel.loadPointLogs(refresh: true)
        }
    }

    private func refreshCurrentTab() async {
        switch activeTab {
        case "points":
            await viewModel.loadPointLogs(refresh: true)
        case "transactions":
            await viewModel.loadTransactions(refresh: true)
        case "exchange":
            await viewModel.loadExchangeRecords(refresh: true)
        case "orders":
            await viewModel.loadPayOrders(refresh: true)
        default:
            break
        }
    }

    // MARK: - 四个功能卡片

    private var quickActionCards: some View {
        HStack(spacing: 10) {
            // 扫码支付
            QuickActionCard(
                icon: "qrcode.viewfinder",
                title: "扫码支付",
                color: .appPrimary
            ) {
                showScanner = true
            }

            // 输入码
            QuickActionCard(
                icon: "keyboard",
                title: "输入码",
                color: .blue
            ) {
                showManualInput = true
            }

            // 我的积分
            QuickActionCard(
                icon: "trophy.fill",
                title: "积分",
                value: "\(viewModel.userPoints)",
                color: .purple
            ) {
                activeTab = "points"
            }

            // 学习币
            QuickActionCard(
                icon: "diamond.fill",
                title: "学习币",
                value: String(format: "%.1f", viewModel.walletBalance),
                color: .pink
            ) {
                showExchangeSheet = true
            }
        }
    }

    // MARK: - 兑换说明按钮

    private var exchangeInfoButton: some View {
        Button {
            showExchangeInfo = true
        } label: {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.appInfo)
                Text("查看兑换说明和比例")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }

    // MARK: - 积分倒数排行榜（可折叠）

    private var leaderboardSection: some View {
        VStack(spacing: 0) {
            // 头部（可点击折叠）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isLeaderboardExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.red)
                    Text("积分倒数排行榜 TOP5")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isLeaderboardExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // 展开内容
            if isLeaderboardExpanded {
                Divider()
                if viewModel.isLoadingLeaderboard {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.leaderboard.isEmpty {
                    Text("暂无排行数据")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, user in
                            LeaderboardRow(rank: index + 1, user: user)
                            if index < viewModel.leaderboard.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 明细标签页

    private var detailTabs: some View {
        VStack(spacing: 0) {
            Picker("", selection: $activeTab) {
                Text("积分").tag("points")
                Text("学习币").tag("transactions")
                Text("兑换").tag("exchange")
                Text("支付").tag("orders")
            }
            .pickerStyle(.segmented)
            .padding()

            // 明细列表
            VStack(spacing: 0) {
                if viewModel.isLoading || viewModel.isLoadingTransactions || viewModel.isLoadingPointLogs || viewModel.isLoadingExchangeRecords {
                    ProgressView()
                        .padding(40)
                } else {
                    switch activeTab {
                    case "points":
                        pointLogsList
                    case "transactions":
                        transactionsList
                    case "exchange":
                        exchangeRecordsList
                    default:
                        ordersList
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .onChange(of: activeTab) { _, newValue in
            Task {
                switch newValue {
                case "points":
                    if viewModel.pointLogs.isEmpty {
                        await viewModel.loadPointLogs(refresh: true)
                    }
                case "transactions":
                    if viewModel.transactions.isEmpty {
                        await viewModel.loadTransactions(refresh: true)
                    }
                case "exchange":
                    if viewModel.exchangeRecords.isEmpty {
                        await viewModel.loadExchangeRecords(refresh: true)
                    }
                case "orders":
                    if viewModel.payOrders.isEmpty {
                        await viewModel.loadPayOrders(refresh: true)
                    }
                default:
                    break
                }
            }
        }
    }

    private var pointLogsList: some View {
        Group {
            if viewModel.pointLogs.isEmpty && !viewModel.isLoadingPointLogs {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无积分记录")
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.pointLogs) { log in
                        PointLogRow(log: log)
                            .onAppear {
                                if log.id == viewModel.pointLogs.suffix(3).first?.id {
                                    Task { await viewModel.loadPointLogs() }
                                }
                            }
                        Divider()
                    }

                    // 底部状态
                    if viewModel.isLoadingPointLogs {
                        ProgressView()
                            .padding()
                    } else if !viewModel.pointLogsHasMore && !viewModel.pointLogs.isEmpty {
                        Text("— 没有更多了 —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
    }

    private var transactionsList: some View {
        Group {
            if viewModel.transactions.isEmpty && !viewModel.isLoadingTransactions {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无交易记录")
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.transactions) { transaction in
                        TransactionRow(
                            description: transaction.description ?? transaction.type,
                            amount: transaction.displayAmount,
                            date: transaction.createdAt?.relativeDescription ?? "",
                            isPositive: transaction.isPositive
                        )
                        .onAppear {
                            if transaction.id == viewModel.transactions.suffix(3).first?.id {
                                Task { await viewModel.loadTransactions() }
                            }
                        }
                        Divider()
                    }

                    // 底部状态
                    if viewModel.isLoadingTransactions {
                        ProgressView()
                            .padding()
                    } else if !viewModel.transactionsHasMore && !viewModel.transactions.isEmpty {
                        Text("— 没有更多了 —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
    }

    private var ordersList: some View {
        Group {
            if viewModel.payOrders.isEmpty && !viewModel.isLoadingPayOrders {
                VStack(spacing: 12) {
                    Image(systemName: "bag")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无支付记录")
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.payOrders) { order in
                        PayOrderRowWithCopy(order: order, viewModel: viewModel)
                            .onAppear {
                                if order.id == viewModel.payOrders.suffix(3).first?.id {
                                    Task { await viewModel.loadPayOrders() }
                                }
                            }
                        Divider()
                    }

                    // 底部状态
                    if viewModel.isLoadingPayOrders {
                        ProgressView()
                            .padding()
                    } else if !viewModel.payOrdersHasMore && !viewModel.payOrders.isEmpty {
                        Text("— 没有更多了 —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
    }

    private var exchangeRecordsList: some View {
        Group {
            if viewModel.exchangeRecords.isEmpty && !viewModel.isLoadingExchangeRecords {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无兑换记录")
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.exchangeRecords) { record in
                        ExchangeRecordRow(record: record)
                            .onAppear {
                                if record.id == viewModel.exchangeRecords.suffix(3).first?.id {
                                    Task { await viewModel.loadExchangeRecords() }
                                }
                            }
                        Divider()
                    }

                    // 底部状态
                    if viewModel.isLoadingExchangeRecords {
                        ProgressView()
                            .padding()
                    } else if !viewModel.exchangeRecordsHasMore && !viewModel.exchangeRecords.isEmpty {
                        Text("— 没有更多了 —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
    }
}

// MARK: - 快捷操作卡片

struct QuickActionCard: View {
    let icon: String
    let title: String
    var value: String? = nil
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .cornerRadius(10)

                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - 货币卡片

struct CurrencyCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    var action: (() -> Void)?
    var actionLabel: String = "查看明细"

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.medium)
            }

            Text(value)
                .font(.system(size: 36, weight: .bold))

            Button(actionLabel) {
                action?()
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
    }
}

// MARK: - 交易记录行

struct TransactionRow: View {
    let description: String
    let amount: String
    let date: String
    let isPositive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .fontWeight(.medium)
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(amount)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isPositive ? .green : .red)
        }
        .padding()
    }
}

// MARK: - 支付订单行

struct PayOrderRow: View {
    let order: PayOrder

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .fontWeight(.medium)
                Text("订单号: \(order.orderNo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(order.createdAt?.relativeDescription ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("-\(String(format: "%.2f", order.amountValue))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text(order.status == "completed" ? "已完成" : order.status)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
        .padding()
    }
}

// MARK: - 支付订单行（带复制功能）

struct PayOrderRowWithCopy: View {
    let order: PayOrder
    @ObservedObject var viewModel: WalletViewModel
    @State private var showCopied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .fontWeight(.medium)
                Text("订单号: \(order.orderNo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(order.createdAt?.relativeDescription ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("-\(String(format: "%.2f", order.amountValue))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                HStack(spacing: 8) {
                    Text(order.status == "completed" ? "已完成" : order.status)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)

                    Button {
                        let receipt = viewModel.copyReceipt(for: order, username: "用户")
                        UIPasteboard.general.string = receipt
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Text(showCopied ? "已复制" : "复制凭证")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(showCopied ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(showCopied ? .green : .primary)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - 排行榜行

struct LeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser

    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }

    private var backgroundColor: Color {
        switch rank {
        case 1: return Color.red.opacity(0.1)
        case 2: return Color.orange.opacity(0.1)
        case 3: return Color.yellow.opacity(0.1)
        default: return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 排名徽章
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())

            // 头像
            if let avatar = user.avatar, !avatar.isEmpty {
                AsyncImage(url: URL(string: avatar)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(user.avatarInitial)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Text(user.avatarInitial)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.appPrimary)
                    .clipShape(Circle())
            }

            // 用户名
            Text(user.displayUsername)
                .fontWeight(.medium)

            Spacer()

            // 积分
            Text("\(user.totalPoints ?? 0) 分")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundColor)
    }
}

// MARK: - 积分明细行

struct PointLogRow: View {
    let log: PointLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.displayDescription)
                    .fontWeight(.medium)
                Text(log.createdAt?.relativeDescription ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(log.displayPoints)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(log.isPositive ? .green : .red)
        }
        .padding()
    }
}

// MARK: - 兑换记录行

struct ExchangeRecordRow: View {
    let record: ExchangeRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("积分兑换学习币")
                    .fontWeight(.medium)
                Text(record.createdAt?.relativeDescription ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let rate = record.exchangeRate {
                    Text("兑换比例：\(rate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("-\(record.pointsSpent) 积分")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text("+\(String(format: "%.0f", record.coinsGained)) 学习币")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
}

// MARK: - 手动输入弹窗

struct ManualCodeInputSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "keyboard")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)
                    .padding(.top, 40)

                Text("请输入收款码")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("输入收款码", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding(.horizontal)

                Button {
                    Task {
                        isChecking = true
                        let success = await viewModel.scanPayCode(code)
                        isChecking = false
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("确认")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 支付确认弹窗

struct PaymentConfirmSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPasswordInput = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let payCode = viewModel.scannedPayCode {
                    // 商家信息
                    VStack(spacing: 8) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.appPrimary)

                        Text(payCode.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let desc = payCode.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // 支付金额
                    VStack(spacing: 4) {
                        Text("支付金额")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", payCode.amount))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.appPrimary)
                        Text("学习币")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)

                    // 余额信息
                    HStack {
                        Text("当前余额")
                        Spacer()
                        Text(String(format: "%.2f 学习币", viewModel.walletBalance))
                            .foregroundColor(viewModel.walletBalance >= payCode.amount ? .green : .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Spacer()

                    // 确认按钮
                    Button {
                        showPasswordInput = true
                    } label: {
                        Text("确认支付")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.walletBalance < payCode.amount)
                }
            }
            .padding()
            .navigationTitle("支付确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.resetPaymentState()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPasswordInput) {
                PaymentPasswordSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - 支付密码弹窗

struct PaymentPasswordSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)
                    .padding(.top, 40)

                Text("请输入支付密码")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("默认密码为 123456")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("支付密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .keyboardType(.numberPad)
                    .padding(.horizontal)

                Button {
                    Task {
                        isSubmitting = true
                        let success = await viewModel.submitPayment(password: password)
                        isSubmitting = false
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("确认支付")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || isSubmitting)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("支付验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 支付成功弹窗

struct PaymentSuccessSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .padding(.top, 40)

                Text("支付成功")
                    .font(.title)
                    .fontWeight(.bold)

                if let order = viewModel.lastOrder {
                    VStack(spacing: 12) {
                        HStack {
                            Text("商品")
                            Spacer()
                            Text(order.title)
                        }
                        Divider()
                        HStack {
                            Text("金额")
                            Spacer()
                            Text(String(format: "%.2f 学习币", order.amountValue))
                        }
                        Divider()
                        HStack {
                            Text("订单号")
                            Spacer()
                            Text(order.orderNo)
                                .font(.caption)
                        }
                        Divider()
                        HStack {
                            Text("支付时间")
                            Spacer()
                            Text(order.createdAt?.relativeDescription ?? "")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                Spacer()

                HStack(spacing: 12) {
                    // 复制凭证按钮
                    if let order = viewModel.lastOrder {
                        Button {
                            let receipt = viewModel.copyReceipt(for: order, username: "用户")
                            UIPasteboard.general.string = receipt
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopied = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "已复制" : "复制凭证")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                    }

                    // 完成按钮
                    Button {
                        viewModel.resetPaymentState()
                        dismiss()
                    } label: {
                        Text("完成")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("支付结果")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 兑换弹窗

struct ExchangeSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var exchangePoints: Int = 100
    @State private var isExchanging = false

    var coinsToReceive: Int {
        (exchangePoints / viewModel.pointsPerCoin) * viewModel.coinsPerExchange
    }

    var maxExchangePoints: Int {
        min(viewModel.userPoints, viewModel.exchangeRemainingLimit)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 说明
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.appInfo)
                        Text("兑换比例：\(viewModel.pointsPerCoin) 积分 = \(viewModel.coinsPerExchange) 学习币")
                            .font(.subheadline)
                    }
                    Text("今日剩余额度：\(viewModel.exchangeRemainingLimit) 积分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appInfo.opacity(0.1))
                .cornerRadius(12)

                // 输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("兑换积分")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Stepper(value: $exchangePoints, in: viewModel.pointsPerCoin...max(viewModel.pointsPerCoin, maxExchangePoints), step: viewModel.pointsPerCoin) {
                        Text("\(exchangePoints) 积分")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Text("当前积分: \(viewModel.userPoints)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 预览
                HStack {
                    Text("可获得学习币")
                    Spacer()
                    Text("\(coinsToReceive)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appSuccess)
                }
                .padding()
                .background(Color.appSuccess.opacity(0.1))
                .cornerRadius(12)

                Spacer()

                // 确认按钮
                Button {
                    Task {
                        isExchanging = true
                        let success = await viewModel.exchangePoints(exchangePoints)
                        isExchanging = false
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if isExchanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("确认兑换")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.userPoints < viewModel.pointsPerCoin || isExchanging)
            }
            .padding()
            .navigationTitle("积分兑换学习币")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - QR 码扫描视图

struct QRCodeScannerView: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String?
    @State private var isScanning = true
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermissionDenied {
                    cameraPermissionDeniedView
                } else {
                    CameraPreviewView(scannedCode: $scannedCode, isScanning: $isScanning)
                        .ignoresSafeArea()

                    // 扫描框
                    scannerOverlay
                }
            }
            .navigationTitle("扫描收款码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: scannedCode) { _, newValue in
                if let code = newValue {
                    isScanning = false
                    Task {
                        let success = await viewModel.scanPayCode(code)
                        if success {
                            dismiss()
                        } else {
                            // 重置扫描
                            scannedCode = nil
                            isScanning = true
                        }
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }

    private var scannerOverlay: some View {
        VStack {
            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 250)
                .overlay(
                    VStack {
                        Spacer()
                        Text("将收款码放入框内")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                    }
                )

            Spacer()

            Text("请对准收款码进行扫描")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.bottom, 50)
        }
    }

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("需要相机权限")
                .font(.title2)
                .fontWeight(.bold)

            Text("请在系统设置中允许访问相机")
                .foregroundColor(.secondary)

            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        default:
            cameraPermissionDenied = true
        }
    }
}

// MARK: - 相机预览视图

struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        uiViewController.isScanning = isScanning
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraScannerDelegate {
        var parent: CameraPreviewView

        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            DispatchQueue.main.async {
                self.parent.scannedCode = code
            }
        }
    }
}

// MARK: - 相机扫描控制器

protocol CameraScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class CameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraScannerDelegate?
    var isScanning = true

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 在后台线程初始化相机
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCamera()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRunning()
    }

    private func startRunning() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopRunning() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // 检查相机设备
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            #if DEBUG
            print("无法获取相机设备")
            #endif
            return
        }

        // 创建输入
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            #if DEBUG
            print("无法创建相机输入")
            #endif
            return
        }

        // 添加输入
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            #if DEBUG
            print("无法添加相机输入")
            #endif
            return
        }

        // 添加元数据输出
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .code128]
        } else {
            #if DEBUG
            print("无法添加元数据输出")
            #endif
            return
        }

        captureSession = session
        isSessionConfigured = true

        // 在主线程设置预览层
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = self.view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            self.view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer

            // 开始运行
            self.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning else { return }
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else { return }

        isScanning = false
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didScanCode(code)
    }
}

#Preview {
    WalletView()
}
