//
//  ConflictResolutionView.swift
//  pinghu12250
//
//  冲突解决界面 - 显示并解决同步冲突
//

import SwiftUI
import CoreData
import Combine

/// 冲突列表视图
struct ConflictListView: View {
    @StateObject private var viewModel = ConflictListViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if viewModel.conflicts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("没有冲突需要解决")
                        .font(.headline)
                    Text("所有数据已同步")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(viewModel.conflicts, id: \.id) { conflict in
                        NavigationLink(destination: ConflictDetailView(conflict: conflict)) {
                            ConflictRowView(conflict: conflict)
                        }
                    }
                }
            }
        }
        .navigationTitle("同步冲突")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadConflicts()
        }
    }
}

/// 冲突行视图
struct ConflictRowView: View {
    let conflict: ConflictItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(conflict.entityType)
                    .font(.headline)
                Spacer()
                Text(conflict.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("本地版本: v\(conflict.localVersion) vs 服务器版本: v\(conflict.serverVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let title = conflict.localTitle {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 冲突详情视图
struct ConflictDetailView: View {
    let conflict: ConflictItem
    @StateObject private var viewModel: ConflictDetailViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingConfirmation = false
    @State private var selectedResolution: ConflictResolution?

    init(conflict: ConflictItem) {
        self.conflict = conflict
        _viewModel = StateObject(wrappedValue: ConflictDetailViewModel(conflict: conflict))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 冲突说明
                conflictHeader

                // 版本对比
                HStack(alignment: .top, spacing: 16) {
                    // 本地版本
                    versionCard(
                        title: "本地版本",
                        version: conflict.localVersion,
                        data: viewModel.localData,
                        color: .blue
                    )

                    // 服务器版本
                    versionCard(
                        title: "服务器版本",
                        version: conflict.serverVersion,
                        data: viewModel.serverData,
                        color: .green
                    )
                }
                .padding(.horizontal)

                // 解决按钮
                resolutionButtons
            }
            .padding(.vertical)
        }
        .navigationTitle("解决冲突")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认解决方式", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) {
                if let resolution = selectedResolution {
                    Task {
                        await viewModel.resolveConflict(resolution: resolution)
                        dismiss()
                    }
                }
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    private var conflictHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("检测到同步冲突")
                .font(.headline)

            Text("同一内容在不同设备上被修改，请选择保留哪个版本")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func versionCard(title: String, version: Int, data: ConflictVersionData?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text("v\(version)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .cornerRadius(4)
            }

            if let data = data {
                VStack(alignment: .leading, spacing: 8) {
                    if let title = data.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if let content = data.content {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                    }

                    if let updatedAt = data.updatedAt {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(updatedAt, style: .relative)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("无法加载数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var resolutionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                selectedResolution = .keepLocal
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "iphone")
                    Text("保留本地版本")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }

            Button(action: {
                selectedResolution = .keepServer
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "cloud")
                    Text("保留服务器版本")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    private var confirmationMessage: String {
        switch selectedResolution {
        case .keepLocal:
            return "将使用本地版本覆盖服务器版本，此操作不可撤销"
        case .keepServer:
            return "将使用服务器版本覆盖本地版本，此操作不可撤销"
        case .merged:
            return "将合并两个版本的内容"
        case .none:
            return ""
        }
    }
}

// MARK: - View Models

@MainActor
class ConflictListViewModel: ObservableObject {
    @Published var conflicts: [ConflictItem] = []

    func loadConflicts() {
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<LocalSyncConflict> = LocalSyncConflict.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "resolution == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let results = try context.fetch(fetchRequest)
            conflicts = results.map { conflict in
                var localTitle: String?
                if let localData = conflict.localData,
                   let json = try? JSONSerialization.jsonObject(with: localData) as? [String: Any] {
                    localTitle = json["title"] as? String
                }

                return ConflictItem(
                    id: conflict.id ?? UUID(),
                    entityType: conflict.entityType ?? "Diary",
                    entityId: conflict.entityId ?? "",
                    localVersion: Int(conflict.localVersion),
                    serverVersion: Int(conflict.serverVersion),
                    localTitle: localTitle,
                    createdAt: conflict.createdAt ?? Date()
                )
            }
        } catch {
            #if DEBUG
            print("[ConflictListViewModel] 加载冲突失败: \(error)")
            #endif
        }
    }
}

@MainActor
class ConflictDetailViewModel: ObservableObject {
    let conflict: ConflictItem
    @Published var localData: ConflictVersionData?
    @Published var serverData: ConflictVersionData?
    @Published var isResolving = false

    init(conflict: ConflictItem) {
        self.conflict = conflict
        loadVersionData()
    }

    private func loadVersionData() {
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<LocalSyncConflict> = LocalSyncConflict.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conflict.id as CVarArg)

        do {
            if let conflictEntity = try context.fetch(fetchRequest).first {
                // 解析本地数据
                if let localDataBlob = conflictEntity.localData,
                   let json = try? JSONSerialization.jsonObject(with: localDataBlob) as? [String: Any] {
                    localData = ConflictVersionData(
                        title: json["title"] as? String,
                        content: json["content"] as? String,
                        updatedAt: nil
                    )
                }

                // 解析服务器数据
                if let serverDataBlob = conflictEntity.serverData,
                   let json = try? JSONSerialization.jsonObject(with: serverDataBlob) as? [String: Any] {
                    var updatedAt: Date?
                    if let dateStr = json["updatedAt"] as? String {
                        updatedAt = ISO8601DateFormatter().date(from: dateStr)
                    }
                    serverData = ConflictVersionData(
                        title: json["title"] as? String,
                        content: json["content"] as? String,
                        updatedAt: updatedAt
                    )
                }
            }
        } catch {
            #if DEBUG
            print("[ConflictDetailViewModel] 加载数据失败: \(error)")
            #endif
        }
    }

    func resolveConflict(resolution: ConflictResolution) async {
        isResolving = true
        defer { isResolving = false }

        do {
            try await SyncManager.shared.resolveConflict(conflict.id, resolution: resolution)
        } catch {
            #if DEBUG
            print("[ConflictDetailViewModel] 解决冲突失败: \(error)")
            #endif
        }
    }
}

// MARK: - Models

struct ConflictItem: Identifiable {
    let id: UUID
    let entityType: String
    let entityId: String
    let localVersion: Int
    let serverVersion: Int
    let localTitle: String?
    let createdAt: Date
}

struct ConflictVersionData {
    let title: String?
    let content: String?
    let updatedAt: Date?
}

// MARK: - Preview

#Preview {
    NavigationView {
        ConflictListView()
    }
}
