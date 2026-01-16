//
//  TextbookGroupView.swift
//  pinghu12250
//
//  按教材分组视图
//  使用DisclosureGroup折叠展示各教材的笔记
//

import SwiftUI

/// 按教材分组视图
struct TextbookGroupView: View {
    /// 所有笔记（按教材分组）
    let notesByTextbook: [String: [ReadingNote]]
    /// 教材名称映射
    let textbookNames: [String: String]
    /// 加载状态
    var isLoading: Bool = false

    /// 点击笔记回调
    var onNoteSelect: ((ReadingNote) -> Void)?
    /// 删除回调
    var onDelete: ((ReadingNote) -> Void)?
    /// 收藏回调
    var onFavorite: ((ReadingNote) -> Void)?

    @State private var expandedTextbooks: Set<String> = []

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if notesByTextbook.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedTextbookIds, id: \.self) { textbookId in
                        if let notes = notesByTextbook[textbookId], !notes.isEmpty {
                            TextbookSection(
                                textbookId: textbookId,
                                textbookName: textbookNames[textbookId] ?? "未知教材",
                                notes: notes,
                                isExpanded: expandedTextbooks.contains(textbookId),
                                onToggle: { toggleExpanded(textbookId) },
                                onNoteSelect: onNoteSelect,
                                onDelete: onDelete,
                                onFavorite: onFavorite
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    /// 排序后的教材ID列表
    private var sortedTextbookIds: [String] {
        notesByTextbook.keys.sorted { id1, id2 in
            let name1 = textbookNames[id1] ?? ""
            let name2 = textbookNames[id2] ?? ""
            return name1 < name2
        }
    }

    /// 切换展开状态
    private func toggleExpanded(_ textbookId: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedTextbooks.contains(textbookId) {
                expandedTextbooks.remove(textbookId)
            } else {
                expandedTextbooks.insert(textbookId)
            }
        }
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("还没有笔记")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在阅读教材时创建笔记会自动按教材分组")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 教材分组区块

private struct TextbookSection: View {
    let textbookId: String
    let textbookName: String
    let notes: [ReadingNote]
    let isExpanded: Bool
    let onToggle: () -> Void
    var onNoteSelect: ((ReadingNote) -> Void)?
    var onDelete: ((ReadingNote) -> Void)?
    var onFavorite: ((ReadingNote) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 折叠标题
            Button(action: onToggle) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))

                    Text(textbookName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(notes.count)条")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)

            // 展开内容
            if isExpanded {
                Divider()
                    .padding(.leading, 16)

                LazyVStack(spacing: 0) {
                    ForEach(notes) { note in
                        TextbookNoteRow(
                            note: note,
                            onSelect: { onNoteSelect?(note) },
                            onDelete: { onDelete?(note) },
                            onFavorite: { onFavorite?(note) }
                        )

                        if note.id != notes.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
        }
    }
}

// MARK: - 笔记行

private struct TextbookNoteRow: View {
    let note: ReadingNote
    let onSelect: () -> Void
    var onDelete: (() -> Void)?
    var onFavorite: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 类型图标
                Image(systemName: typeIcon)
                    .font(.system(size: 14))
                    .foregroundColor(typeColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    // 标题/查询
                    Text(note.query ?? note.snippet ?? "笔记")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // 类型标签 + 页码
                    HStack(spacing: 8) {
                        Text(note.typeLabel)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(typeColor.opacity(0.1))
                            .foregroundColor(typeColor)
                            .cornerRadius(4)

                        if let page = note.page {
                            Text("P\(page)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // 收藏状态
                if note.isFavorite == true {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 更多菜单
                Menu {
                    Button {
                        onFavorite?()
                    } label: {
                        Label(
                            note.isFavorite == true ? "取消收藏" : "收藏",
                            systemImage: note.isFavorite == true ? "heart.fill" : "heart"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .padding(8)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var typeIcon: String {
        switch note.sourceType {
        case "dict": return "character.book.closed"
        case "search": return "magnifyingglass"
        case "explain", "ai_analysis", "ai_quote": return "sparkles"
        case "pdf_selection", "highlight": return "highlighter"
        case "practice", "exercise": return "checkmark.circle"
        case "solving": return "questionmark.circle"
        case "writing_practice": return "pencil.line"
        case "drawing": return "scribble"
        default: return "note.text"
        }
    }

    private var typeColor: Color {
        switch note.sourceType {
        case "dict": return .blue
        case "search": return .gray
        case "explain", "ai_analysis", "ai_quote": return .purple
        case "pdf_selection", "highlight": return .orange
        case "practice", "exercise": return .green
        case "solving": return .red
        case "writing_practice": return .teal
        case "drawing": return .brown
        default: return .gray
        }
    }
}

// MARK: - 预览

#Preview {
    let sampleNotes: [String: [ReadingNote]] = [
        "tb1": [
            ReadingNote(
                id: "1",
                userId: "user1",
                textbookId: "tb1",
                sessionId: nil,
                sourceType: "dict",
                query: "春",
                content: nil,
                snippet: "春天的故事",
                page: 12,
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
                id: "2",
                userId: "user1",
                textbookId: "tb1",
                sessionId: nil,
                sourceType: "highlight",
                query: nil,
                content: nil,
                snippet: "这是一段摘录内容",
                page: 15,
                isFavorite: false,
                favoriteAt: nil,
                createdAt: nil,
                updatedAt: nil,
                textbook: nil,
                chapterId: nil,
                paragraphId: nil,
                textRange: nil
            )
        ],
        "tb2": [
            ReadingNote(
                id: "3",
                userId: "user1",
                textbookId: "tb2",
                sessionId: nil,
                sourceType: "practice",
                query: "练习题1",
                content: nil,
                snippet: nil,
                page: 20,
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
    ]

    return TextbookGroupView(
        notesByTextbook: sampleNotes,
        textbookNames: [
            "tb1": "语文三年级上册",
            "tb2": "数学三年级上册"
        ]
    )
}
