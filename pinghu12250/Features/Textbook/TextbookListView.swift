//
//  TextbookListView.swift
//  pinghu12250
//
//  教材列表页面
//

import SwiftUI
import Combine

struct TextbookListView: View {
    @ObservedObject private var textbookService = TextbookService.shared
    @State private var searchText = ""
    @State private var selectedSubject: String?
    @State private var selectedGrade: Int?
    @State private var showingFilters = false

    // 批量选择模式
    @State private var isSelectionMode = false
    @State private var selectedTextbooks: Set<String> = []

    // 下载状态提示
    @State private var showDownloadAlert = false
    @State private var downloadAlertMessage = ""

    // 默认筛选选项
    private let defaultSubjects = ["语文", "数学", "英语", "科学"]
    private let defaultGrades = Array(1...9)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计栏
                statsBar

                // 搜索栏 + 筛选
                searchAndFilterBar

                // 科目快捷筛选
                subjectFilterBar

                // 批量选择工具栏
                if isSelectionMode {
                    selectionToolbar
                }

                // 教材网格
                if textbookService.isLoading && textbookService.textbooks.isEmpty {
                    loadingView
                } else if textbookService.textbooks.isEmpty {
                    emptyView
                } else {
                    textbookGrid
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("教材库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectionMode ? "完成" : "选择") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedTextbooks.removeAll()
                            }
                        }
                    }
                }
            }
            .refreshable {
                await textbookService.fetchTextbooks(refresh: true)
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await textbookService.fetchFilterOptions()
            await textbookService.fetchTextbooks(refresh: true)
        }
        .alert("下载结果", isPresented: $showDownloadAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(downloadAlertMessage)
        }
    }

    // MARK: - 统计栏

    private var statsBar: some View {
        HStack(spacing: 16) {
            // 总数统计
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.subheadline)
                    .foregroundColor(.appPrimary)
                Text("共 \(textbookService.total) 本")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            // 已下载数量
            let downloadedCount = textbookService.textbooks.filter { textbookService.isDownloaded($0) }.count
            if downloadedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(downloadedCount) 已下载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 有PDF的数量
            let pdfCount = textbookService.textbooks.filter { $0.hasPdf }.count
            HStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("\(pdfCount) 本有PDF")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 待上传数量
            let noPdfCount = textbookService.textbooks.filter { !$0.hasPdf }.count
            if noPdfCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.doc")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(noPdfCount) 待上传")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - 搜索栏和筛选

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索教材...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await searchTextbooks()
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task {
                            await textbookService.fetchTextbooks(refresh: true)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // 年级筛选按钮
            Menu {
                Button("全部年级") {
                    selectedGrade = nil
                    Task {
                        await applyFilters()
                    }
                }
                ForEach(defaultGrades, id: \.self) { grade in
                    Button(gradeName(grade)) {
                        selectedGrade = grade
                        Task {
                            await applyFilters()
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                    Text(selectedGrade.map { gradeName($0) } ?? "年级")
                        .font(.subheadline)
                }
                .foregroundColor(selectedGrade != nil ? .white : .appPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedGrade != nil ? Color.appPrimary : Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 科目筛选条

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                FilterChip(
                    title: "全部",
                    isSelected: selectedSubject == nil
                ) {
                    selectedSubject = nil
                    Task {
                        await applyFilters()
                    }
                }

                // 科目筛选
                ForEach(defaultSubjects, id: \.self) { subject in
                    FilterChip(
                        title: subject,
                        isSelected: selectedSubject == subject
                    ) {
                        selectedSubject = selectedSubject == subject ? nil : subject
                        Task {
                            await applyFilters()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 批量选择工具栏

    private var selectionToolbar: some View {
        HStack {
            // 全选/取消全选
            Button {
                if selectedTextbooks.count == textbookService.textbooks.count {
                    selectedTextbooks.removeAll()
                } else {
                    selectedTextbooks = Set(textbookService.textbooks.map { $0.id })
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedTextbooks.count == textbookService.textbooks.count ? "checkmark.circle.fill" : "circle")
                    Text(selectedTextbooks.count == textbookService.textbooks.count ? "取消全选" : "全选")
                }
                .font(.subheadline)
            }

            Spacer()

            Text("已选 \(selectedTextbooks.count) 项")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // 批量下载按钮
            Button {
                Task {
                    await batchDownload()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("下载")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTextbooks.isEmpty ? Color.gray : Color.appPrimary)
                .cornerRadius(8)
            }
            .disabled(selectedTextbooks.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - 教材网格

    private var textbookGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 16)
            ], spacing: 16) {
                ForEach(textbookService.textbooks) { textbook in
                    if isSelectionMode {
                        // 选择模式：点击选中/取消
                        TextbookGridItemWithSelection(
                            textbook: textbook,
                            isSelected: selectedTextbooks.contains(textbook.id),
                            isDownloaded: textbookService.isDownloaded(textbook),
                            isDownloading: textbookService.downloadingIds.contains(textbook.id)
                        ) {
                            if selectedTextbooks.contains(textbook.id) {
                                selectedTextbooks.remove(textbook.id)
                            } else {
                                selectedTextbooks.insert(textbook.id)
                            }
                        }
                    } else {
                        // 正常模式：导航到详情
                        NavigationLink(destination: TextbookDetailView(textbook: textbook)) {
                            TextbookGridItemWithDownload(
                                textbook: textbook,
                                isDownloaded: textbookService.isDownloaded(textbook),
                                isDownloading: textbookService.downloadingIds.contains(textbook.id),
                                onDownload: {
                                    Task {
                                        await downloadSingle(textbook)
                                    }
                                },
                                onDelete: {
                                    _ = textbookService.deleteLocalTextbook(textbook)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()

            // 加载更多指示器
            if textbookService.isLoading && !textbookService.textbooks.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暂无教材")
                .font(.headline)
                .foregroundColor(.secondary)

            if selectedSubject != nil || selectedGrade != nil || !searchText.isEmpty {
                Button("清除筛选") {
                    selectedSubject = nil
                    selectedGrade = nil
                    searchText = ""
                    Task {
                        await textbookService.fetchTextbooks(refresh: true)
                    }
                }
                .foregroundColor(.appPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 辅助方法

    private func gradeName(_ grade: Int) -> String {
        switch grade {
        case 1...6: return "\(grade)年级"
        case 7: return "初一"
        case 8: return "初二"
        case 9: return "初三"
        default: return "\(grade)年级"
        }
    }

    private func searchTextbooks() async {
        await textbookService.fetchTextbooks(
            subject: selectedSubject,
            grade: selectedGrade,
            keyword: searchText.isEmpty ? nil : searchText,
            refresh: true
        )
    }

    private func applyFilters() async {
        await textbookService.fetchTextbooks(
            subject: selectedSubject,
            grade: selectedGrade,
            keyword: searchText.isEmpty ? nil : searchText,
            refresh: true
        )
    }

    private func downloadSingle(_ textbook: Textbook) async {
        let success = await textbookService.downloadTextbook(textbook)
        if success {
            downloadAlertMessage = "《\(textbook.title)》下载成功"
        } else {
            downloadAlertMessage = textbookService.errorMessage ?? "下载失败"
        }
        showDownloadAlert = true
    }

    private func batchDownload() async {
        let textbooksToDownload = textbookService.textbooks.filter { selectedTextbooks.contains($0.id) }
        let (success, failed) = await textbookService.downloadTextbooks(textbooksToDownload)
        downloadAlertMessage = "下载完成：成功 \(success) 本，失败 \(failed) 本"
        showDownloadAlert = true
        // 退出选择模式
        isSelectionMode = false
        selectedTextbooks.removeAll()
    }
}

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appPrimary : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - 带下载功能的教材网格项

struct TextbookGridItemWithDownload: View {
    let textbook: Textbook
    let isDownloaded: Bool
    let isDownloading: Bool
    let onDownload: () -> Void
    let onDelete: () -> Void

    // 书本封面典型比例 3:4
    private let coverAspectRatio: CGFloat = 3.0 / 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面 - 使用书本比例
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.forSubject(textbook.subject).opacity(0.15))

                        if let coverURL = textbook.coverImageURL {
                            CachedAsyncImage(url: coverURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.forSubject(textbook.subject))
                            }
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.forSubject(textbook.subject))

                                Text(textbook.subjectName)
                                    .font(.caption)
                                    .foregroundColor(Color.forSubject(textbook.subject))
                            }
                        }
                    }
                    .cornerRadius(12)

                    // 状态标签
                    VStack(spacing: 4) {
                        if isDownloaded {
                            // 已下载标签
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .background(Circle().fill(.white).padding(-2))
                        } else if textbook.pdfUrl == nil {
                            // 无PDF提示标签
                            Text("待上传")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(6)
                        }
                    }
                    .padding(6)
                }
            }
            .aspectRatio(coverAspectRatio, contentMode: .fit)

            // 标题
            Text(textbook.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)

            // 信息标签
            HStack(spacing: 4) {
                Text(textbook.gradeName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)

                Text(textbook.semester)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contextMenu {
            if textbook.hasPdf || textbook.hasEpub {
                if isDownloaded {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除本地文件", systemImage: "trash")
                    }
                } else if isDownloading {
                    Button {} label: {
                        Label("下载中...", systemImage: "arrow.down.circle")
                    }
                    .disabled(true)
                } else {
                    Button {
                        onDownload()
                    } label: {
                        Label("保存到本地", systemImage: "arrow.down.circle")
                    }
                }
            }
        }
    }
}

// MARK: - 带选择功能的教材网格项

struct TextbookGridItemWithSelection: View {
    let textbook: Textbook
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let onTap: () -> Void

    // 书本封面典型比例 3:4
    private let coverAspectRatio: CGFloat = 3.0 / 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面 - 使用书本比例
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.forSubject(textbook.subject).opacity(0.15))

                        if let coverURL = textbook.coverImageURL {
                            CachedAsyncImage(url: coverURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.forSubject(textbook.subject))
                            }
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.forSubject(textbook.subject))

                                Text(textbook.subjectName)
                                    .font(.caption)
                                    .foregroundColor(Color.forSubject(textbook.subject))
                            }
                        }
                    }
                    .cornerRadius(12)

                    // 选择指示器
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .appPrimary : .gray)
                        .background(Circle().fill(.white).padding(-2))
                        .padding(8)

                    // 已下载标签（右上角）
                    if isDownloaded {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .background(Circle().fill(.white).padding(-1))
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .aspectRatio(coverAspectRatio, contentMode: .fit)

            // 标题
            Text(textbook.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)

            // 信息标签
            HStack(spacing: 4) {
                Text(textbook.gradeName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)

                Text(textbook.semester)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)

                if !textbook.hasPdf && !textbook.hasEpub {
                    Text("无文件")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    TextbookListView()
}
