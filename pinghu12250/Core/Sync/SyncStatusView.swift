//
//  SyncStatusView.swift
//  pinghu12250
//
//  同步状态指示器 - 显示当前同步状态
//

import SwiftUI
import Combine

/// 同步状态指示器（用于导航栏）
struct SyncStatusIndicator: View {
    @ObservedObject var syncManager = SyncManager.shared

    var body: some View {
        Button(action: handleTap) {
            statusIcon
                .font(.system(size: 18))
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncManager.status {
        case .idle:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.secondary)

        case .syncing(let progress, _):
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 18, height: 18)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
            }

        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

        case .conflict(let count):
            ZStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 8, y: -8)
                    .background(
                        Circle()
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                            .offset(x: 8, y: -8)
                    )
            }

        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundColor(.secondary)
        }
    }

    private func handleTap() {
        switch syncManager.status {
        case .conflict:
            // 打开冲突解决界面
            NotificationCenter.default.post(name: .showConflictResolution, object: nil)
        case .idle, .failed:
            // 触发手动同步
            syncManager.triggerSync()
        default:
            break
        }
    }
}

/// 同步状态详情视图
struct SyncStatusView: View {
    @ObservedObject var syncManager = SyncManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // 当前状态
                Section("同步状态") {
                    HStack {
                        statusIcon
                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle)
                                .font(.headline)
                            Text(statusSubtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // 统计信息
                Section("数据统计") {
                    HStack {
                        Text("待同步变更")
                        Spacer()
                        Text("\(syncManager.pendingChangesCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("未解决冲突")
                        Spacer()
                        Text("\(syncManager.conflictsCount)")
                            .foregroundColor(syncManager.conflictsCount > 0 ? .red : .secondary)
                    }

                    if let lastSync = syncManager.lastSyncTime {
                        HStack {
                            Text("上次同步")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 操作按钮
                Section {
                    Button(action: {
                        syncManager.triggerSync()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("立即同步")
                        }
                    }
                    .disabled(syncManager.status.isSyncing || !syncManager.isOnline)

                    if syncManager.conflictsCount > 0 {
                        NavigationLink(destination: ConflictListView()) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text("解决冲突 (\(syncManager.conflictsCount))")
                            }
                        }
                    }
                }

                // 网络状态
                Section("网络状态") {
                    HStack {
                        Image(systemName: syncManager.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(syncManager.isOnline ? .green : .red)
                        Text(syncManager.isOnline ? "已连接" : "离线模式")
                        Spacer()
                    }
                }
            }
            .navigationTitle("同步中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncManager.status {
        case .idle:
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        case .syncing:
            ProgressView()
                .scaleEffect(1.5)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
        case .conflict:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
        case .offline:
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }

    private var statusTitle: String {
        switch syncManager.status {
        case .idle:
            return "就绪"
        case .syncing(_, let message):
            return message
        case .success:
            return "同步成功"
        case .failed(let error):
            return "同步失败: \(error)"
        case .conflict(let count):
            return "存在 \(count) 个冲突"
        case .offline:
            return "离线模式"
        }
    }

    private var statusSubtitle: String {
        switch syncManager.status {
        case .idle:
            return "点击立即同步按钮开始同步"
        case .syncing(let progress, _):
            return "进度: \(Int(progress * 100))%"
        case .success:
            return "所有数据已同步到最新"
        case .failed:
            return "请检查网络后重试"
        case .conflict:
            return "需要手动解决冲突"
        case .offline:
            return "连接网络后自动同步"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showConflictResolution = Notification.Name("showConflictResolution")
    static let showSyncStatus = Notification.Name("showSyncStatus")
}

// MARK: - Preview

#Preview {
    SyncStatusView()
}
