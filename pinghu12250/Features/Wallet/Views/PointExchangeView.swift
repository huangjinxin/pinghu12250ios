//
//  PointExchangeView.swift
//  pinghu12250
//
//  积分兑换视图
//

import SwiftUI

struct PointExchangeView: View {
    @StateObject private var vm = ExchangeViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 积分余额卡片
                VStack(spacing: 12) {
                    Text("当前积分")
                        .font(.system(size: 16))
                        .foregroundColor(.messageSecondaryText)

                    Text("\(vm.currentPoints)")
                        .font(.system(size: 48, weight: .bold))
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
                .padding(.horizontal)
                .padding(.top, 20)

                // 兑换说明
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.appPrimary)
                    Text("兑换比例：10 积分 = 1 虎币")
                        .font(.system(size: 14))
                        .foregroundColor(.messageSecondaryText)
                }
                .padding(.horizontal)

                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("兑换积分数量")
                        .font(.system(size: 14))
                        .foregroundColor(.messageSecondaryText)

                    TextField("请输入积分数量", text: $vm.exchangeAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 18))
                }
                .padding(.horizontal)

                // 预计获得
                if !vm.exchangeAmount.isEmpty {
                    HStack {
                        Text("预计获得：")
                            .foregroundColor(.messageSecondaryText)
                        Text("\(String(format: "%.2f", vm.coinsToReceive)) 虎币")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }

                Spacer()

                // 兑换按钮
                Button {
                    Task { await vm.exchange() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("立即兑换")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(vm.exchangeAmount.isEmpty || vm.isLoading)
                .opacity(vm.exchangeAmount.isEmpty || vm.isLoading ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("积分兑换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .task {
            await vm.loadBalance()
        }
        .alert("兑换成功", isPresented: $vm.exchangeSuccess) {
            Button("完成") { dismiss() }
        }
        .alert("错误", isPresented: .constant(vm.errorMessage != nil)) {
            Button("确定") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
