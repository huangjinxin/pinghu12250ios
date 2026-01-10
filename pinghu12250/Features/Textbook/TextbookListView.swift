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
            .refreshable {
                await textbookService.fetchTextbooks(refresh: true)
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await textbookService.fetchFilterOptions()
            await textbookService.fetchTextbooks(refresh: true)
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

    // MARK: - 教材网格

    private var textbookGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 16)
            ], spacing: 16) {
                ForEach(textbookService.textbooks) { textbook in
                    NavigationLink(destination: TextbookDetailView(textbook: textbook)) {
                        TextbookGridItem(textbook: textbook)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // 加载更多
                        if textbook.id == textbookService.textbooks.last?.id {
                            Task {
                                await textbookService.loadMore()
                            }
                        }
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

// MARK: - 教材网格项

struct TextbookGridItem: View {
    let textbook: Textbook

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

                    // 无PDF提示标签
                    if textbook.pdfUrl == nil {
                        Text("待上传")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .cornerRadius(6)
                            .padding(6)
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
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    TextbookListView()
}
