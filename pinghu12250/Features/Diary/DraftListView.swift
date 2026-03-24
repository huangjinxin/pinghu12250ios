//
//  DraftListView.swift
//  pinghu12250
//
//  草稿列表
//

import SwiftUI

struct DraftListView: View {
    @StateObject private var manager = DiaryDraftManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if manager.drafts.isEmpty {
                    Text("暂无草稿").foregroundColor(.secondary)
                } else {
                    ForEach(manager.drafts) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(draft.title.isEmpty ? "无标题" : draft.title).font(.headline)
                            Text(draft.content.prefix(50)).font(.subheadline).foregroundColor(.secondary)
                            Text("\(draft.wordCount)字").font(.caption).foregroundColor(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                manager.deleteDraft(id: draft.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("草稿箱")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

