//
//  ParentNotesView.swift
//  pinghu12250
//
//  家长查看孩子笔记（只读）
//

import SwiftUI

struct ParentNotesView: View {
    let childId: String

    @State private var notes: [ChildNote] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var searchText = ""
    @State private var selectedNote: ChildNote?

    @Environment(\.viewingChild) var child

    var body: some View {
        VStack(spacing: 0) {
            // 只读提示
            if let child = child {
                ParentModeBanner(childName: child.displayName)
            }

            // 搜索栏
            searchBar

            // 内容
            if isLoading && notes.isEmpty {
                loadingView
            } else if let error = error, notes.isEmpty {
                errorView(error)
            } else if notes.isEmpty {
                emptyView
            } else {
                notesList
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadNotes()
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailSheet(note: note)
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索笔记...", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    resetAndLoad()
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    resetAndLoad()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 笔记列表

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notes) { note in
                    NoteCard(note: note)
                        .onTapGesture {
                            selectedNote = note
                        }
                }

                // 加载更多
                if hasMore {
                    Button {
                        loadMore()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("加载更多")
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 笔记卡片

    private struct NoteCard: View {
        let note: ChildNote

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // 标题和类型
                HStack {
                    // 类型图标
                    Image(systemName: noteTypeIcon)
                        .foregroundColor(noteTypeColor)
                        .frame(width: 24)

                    // 查询内容
                    Text(note.query)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // 收藏标记
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }

                // 摘要
                Text(note.snippet)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // 底部信息
                HStack {
                    // 教材名称
                    if let textbook = note.textbook {
                        Text(textbook.title)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 时间
                    Text(formatDate(note.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }

        private var noteTypeIcon: String {
            switch note.sourceType {
            case "dictionary": return "character.book.closed.fill"
            case "search": return "magnifyingglass"
            case "ai": return "sparkles"
            case "annotation": return "pencil.tip"
            default: return "note.text"
            }
        }

        private var noteTypeColor: Color {
            switch note.sourceType {
            case "dictionary": return .blue
            case "search": return .green
            case "ai": return .purple
            case "annotation": return .orange
            default: return .gray
            }
        }

        private func formatDate(_ dateString: String) -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: dateString) else {
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: dateString) else {
                    return dateString
                }
                return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
            }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
    }

    // MARK: - 笔记详情Sheet

    private struct NoteDetailSheet: View {
        let note: ChildNote
        @Environment(\.dismiss) var dismiss

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 查询内容
                        VStack(alignment: .leading, spacing: 4) {
                            Text("查询内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(note.query)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Divider()

                        // 摘要
                        VStack(alignment: .leading, spacing: 4) {
                            Text("笔记摘要")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(note.snippet)
                                .font(.body)
                        }

                        // 教材信息
                        if let textbook = note.textbook {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("来源教材")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(textbook.title)
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }

                        // 页码
                        if note.page > 0 {
                            HStack {
                                Text("页码")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("第 \(note.page) 页")
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("笔记详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 辅助视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
            Button("重试") {
                resetAndLoad()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无笔记")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    private func resetAndLoad() {
        currentPage = 1
        notes = []
        hasMore = true
        loadNotes()
    }

    private func loadMore() {
        currentPage += 1
        loadNotes()
    }

    private func loadNotes() {
        isLoading = true
        error = nil

        Task {
            do {
                var endpoint = "/textbook-notes/child/\(childId)?page=\(currentPage)&limit=20"
                if !searchText.isEmpty {
                    endpoint += "&search=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }

                let response: ChildNotesResponse = try await APIService.shared.get(endpoint)
                await MainActor.run {
                    if currentPage == 1 {
                        notes = response.data.notes
                    } else {
                        notes.append(contentsOf: response.data.notes)
                    }
                    hasMore = currentPage < response.data.pagination.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 数据模型

struct ChildNotesResponse: Decodable {
    let success: Bool
    let data: ChildNotesData
}

struct ChildNotesData: Decodable {
    let notes: [ChildNote]
    let pagination: NotePagination
}

struct ChildNote: Decodable, Identifiable {
    let id: String
    let query: String
    let snippet: String
    let sourceType: String
    let page: Int
    let isFavorite: Bool
    let createdAt: String
    let textbook: NoteTextbook?
}

struct NoteTextbook: Decodable {
    let id: String
    let title: String
    let subject: String?
    let grade: String?
}

struct NotePagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

#Preview {
    ParentNotesView(childId: "test-child-id")
}
