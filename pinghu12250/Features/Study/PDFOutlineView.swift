//
//  PDFOutlineView.swift
//  pinghu12250
//
//  PDF 目录/大纲导航视图
//

import SwiftUI
import PDFKit

// MARK: - 目录项模型

struct PDFOutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int
    let level: Int
    let children: [PDFOutlineItem]

    var hasChildren: Bool { !children.isEmpty }
}

// MARK: - PDF 目录视图

struct PDFOutlineView: View {
    let document: PDFDocument
    let currentPage: Int
    let onPageSelected: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var outlineItems: [PDFOutlineItem] = []
    @State private var expandedItems: Set<UUID> = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在加载目录...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if outlineItems.isEmpty {
                    emptyOutlineView
                } else {
                    outlineList
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task {
            await loadOutline()
        }
    }

    // MARK: - 空目录视图

    private var emptyOutlineView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("此PDF没有目录")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("可以通过滑动页码快速浏览")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 快速页码导航
            pageQuickNavigation
        }
        .padding()
    }

    // MARK: - 快速页码导航

    private var pageQuickNavigation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速跳转")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(quickJumpPages, id: \.self) { page in
                    Button {
                        onPageSelected(page)
                        dismiss()
                    } label: {
                        Text("\(page)")
                            .font(.subheadline)
                            .fontWeight(page == currentPage ? .bold : .regular)
                            .foregroundColor(page == currentPage ? .white : .primary)
                            .frame(width: 50, height: 36)
                            .background(page == currentPage ? Color.appPrimary : Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var quickJumpPages: [Int] {
        let totalPages = document.pageCount
        guard totalPages > 0 else { return [] }

        var pages: [Int] = []

        // 生成间隔均匀的页码
        let step = max(1, totalPages / 10)
        for i in stride(from: 1, to: totalPages + 1, by: step) {
            pages.append(i)
        }

        // 确保包含最后一页
        if let last = pages.last, last != totalPages {
            pages.append(totalPages)
        }

        return pages
    }

    // MARK: - 目录列表

    private var outlineList: some View {
        List {
            ForEach(outlineItems) { item in
                OutlineRowView(
                    item: item,
                    currentPage: currentPage,
                    expandedItems: $expandedItems,
                    onSelect: { pageIndex in
                        onPageSelected(pageIndex + 1)
                        dismiss()
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 加载目录

    private func loadOutline() async {
        isLoading = true

        // 在后台线程解析目录
        let items = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let parsed = self.parseOutline(from: document.outlineRoot, level: 0)
                continuation.resume(returning: parsed)
            }
        }

        await MainActor.run {
            outlineItems = items
            isLoading = false
        }
    }

    // MARK: - 解析PDF目录

    private func parseOutline(from outline: PDFOutline?, level: Int) -> [PDFOutlineItem] {
        guard let outline = outline else { return [] }

        var items: [PDFOutlineItem] = []

        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }

            let title = child.label ?? "未命名"
            var pageIndex = 0

            if let destination = child.destination,
               let page = destination.page {
                pageIndex = document.index(for: page)
            }

            let children = parseOutline(from: child, level: level + 1)

            let item = PDFOutlineItem(
                title: title,
                pageIndex: pageIndex,
                level: level,
                children: children
            )
            items.append(item)
        }

        return items
    }
}

// MARK: - 目录行视图

struct OutlineRowView: View {
    let item: PDFOutlineItem
    let currentPage: Int
    @Binding var expandedItems: Set<UUID>
    let onSelect: (Int) -> Void

    private var isExpanded: Bool {
        expandedItems.contains(item.id)
    }

    private var isCurrentPage: Bool {
        item.pageIndex + 1 == currentPage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行
            Button {
                if item.hasChildren {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedItems.remove(item.id)
                        } else {
                            expandedItems.insert(item.id)
                        }
                    }
                } else {
                    onSelect(item.pageIndex)
                }
            } label: {
                HStack(spacing: 8) {
                    // 缩进
                    if item.level > 0 {
                        Spacer()
                            .frame(width: CGFloat(item.level) * 16)
                    }

                    // 展开/折叠图标
                    if item.hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    } else {
                        Circle()
                            .fill(isCurrentPage ? Color.appPrimary : Color(.systemGray4))
                            .frame(width: 6, height: 6)
                            .frame(width: 16)
                    }

                    // 标题
                    Text(item.title)
                        .font(item.level == 0 ? .headline : .subheadline)
                        .fontWeight(item.level == 0 ? .semibold : .regular)
                        .foregroundColor(isCurrentPage ? .appPrimary : .primary)
                        .lineLimit(2)

                    Spacer()

                    // 页码
                    Text("P\(item.pageIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isCurrentPage ? Color.appPrimary.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(4)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 子项
            if item.hasChildren && isExpanded {
                ForEach(item.children) { child in
                    OutlineRowView(
                        item: child,
                        currentPage: currentPage,
                        expandedItems: $expandedItems,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}

// MARK: - 目录按钮（用于工具栏）

struct OutlineButton: View {
    let document: PDFDocument?
    let currentPage: Int
    let onPageSelected: (Int) -> Void

    @State private var showOutline = false

    var body: some View {
        Button {
            showOutline = true
        } label: {
            Image(systemName: "list.bullet")
                .foregroundColor(.white)
        }
        .sheet(isPresented: $showOutline) {
            if let document = document {
                PDFOutlineView(
                    document: document,
                    currentPage: currentPage,
                    onPageSelected: onPageSelected
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - 预览

#Preview {
    // 创建一个简单的测试文档
    let document = PDFDocument()

    return PDFOutlineView(
        document: document,
        currentPage: 5,
        onPageSelected: { _ in }
    )
}
