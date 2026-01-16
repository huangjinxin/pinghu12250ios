//
//  VocabularyGridView.swift
//  pinghu12250
//
//  生词本列表视图
//  单列展示生词卡片，支持批量选择和练习
//

import SwiftUI

/// 生词本列表视图
struct VocabularyGridView: View {
    /// 生词笔记列表
    let notes: [ReadingNote]
    /// 练习记录映射 (noteId -> count)
    var practiceCountMap: [String: Int] = [:]
    /// 加载状态
    var isLoading: Bool = false

    /// 开始练习回调（批量或单个）
    var onStartPractice: (([ReadingNote]) -> Void)?
    /// 收藏回调
    var onFavorite: ((ReadingNote) -> Void)?
    /// 删除回调
    var onDelete: ((ReadingNote) -> Void)?
    /// 查看详情回调
    var onViewDetail: ((ReadingNote) -> Void)?

    @State private var gridType: GridType = .mi
    @State private var selectedIds: Set<String> = []
    @State private var isSelectMode = false

    /// 已选中的笔记
    private var selectedNotes: [ReadingNote] {
        notes.filter { selectedIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolBar

            // 内容区
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notes.isEmpty {
                emptyView
            } else {
                listContent
            }
        }
    }

    // MARK: - 工具栏

    private var toolBar: some View {
        HStack {
            // 格子类型选择
            Picker("格子", selection: $gridType) {
                Text("米字格").tag(GridType.mi)
                Text("田字格").tag(GridType.tian)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            // 选择模式
            if isSelectMode {
                // 已选计数
                Text("已选 \(selectedIds.count)/\(notes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 全选/取消
                Button {
                    if selectedIds.count == notes.count {
                        selectedIds.removeAll()
                    } else {
                        selectedIds = Set(notes.map { $0.id })
                    }
                } label: {
                    Text(selectedIds.count == notes.count ? "取消全选" : "全选")
                        .font(.caption)
                }

                // 批量练习
                Button {
                    onStartPractice?(selectedNotes)
                } label: {
                    Label("批量练习", systemImage: "pencil.line")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedIds.isEmpty)

                // 退出选择模式
                Button {
                    isSelectMode = false
                    selectedIds.removeAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            } else {
                // 进入选择模式
                Button {
                    isSelectMode = true
                } label: {
                    Label("选择", systemImage: "checkmark.circle")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - 列表内容

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(notes) { note in
                    VocabularyCardView(
                        note: note,
                        gridType: gridType,
                        isSelected: selectedIds.contains(note.id),
                        practiceCount: practiceCountMap[note.id] ?? 0,
                        onTap: {
                            if isSelectMode {
                                toggleSelection(note.id)
                            }
                        },
                        onPractice: {
                            onStartPractice?([note])
                        },
                        onFavorite: {
                            onFavorite?(note)
                        },
                        onDelete: {
                            onDelete?(note)
                        },
                        onViewDetail: {
                            onViewDetail?(note)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("还没有生词")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在阅读时查字典会自动添加到这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 辅助方法

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

// MARK: - 预览

#Preview {
    let sampleNotes = [
        ReadingNote(
            id: "1",
            userId: "user1",
            textbookId: nil,
            sessionId: nil,
            sourceType: "dict",
            query: "春",
            content: AnyCodable(["pinyin": "chūn", "definition": "一年的第一个季节"]),
            snippet: nil,
            page: nil,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        ),
        ReadingNote(
            id: "2",
            userId: "user1",
            textbookId: nil,
            sessionId: nil,
            sourceType: "dict",
            query: "夏",
            content: AnyCodable(["pinyin": "xià", "definition": "一年的第二个季节"]),
            snippet: nil,
            page: nil,
            isFavorite: true,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        ),
        ReadingNote(
            id: "3",
            userId: "user1",
            textbookId: nil,
            sessionId: nil,
            sourceType: "dict",
            query: "秋",
            content: AnyCodable(["pinyin": "qiū", "definition": "一年的第三个季节"]),
            snippet: nil,
            page: nil,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        ),
        ReadingNote(
            id: "4",
            userId: "user1",
            textbookId: nil,
            sessionId: nil,
            sourceType: "dict",
            query: "冬",
            content: AnyCodable(["pinyin": "dōng", "definition": "一年的第四个季节"]),
            snippet: nil,
            page: nil,
            isFavorite: false,
            favoriteAt: nil,
            createdAt: nil,
            updatedAt: nil,
            textbook: nil,
            chapterId: nil,
            paragraphId: nil,
            textRange: nil
        )
    ]

    return VocabularyGridView(
        notes: sampleNotes,
        practiceCountMap: ["1": 3, "2": 1]
    )
}
