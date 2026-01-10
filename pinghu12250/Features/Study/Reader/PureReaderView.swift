//
//  PureReaderView.swift
//  pinghu12250
//
//  纯阅读模式 - 竖屏专用
//  无AI功能，专注阅读体验
//  使用 Apple 官方 PDFPageOverlayViewProvider 方案
//

import SwiftUI
import PDFKit
import UIKit
import Combine
import AVFoundation
import PencilKit

struct PureReaderView: View {
    @ObservedObject var state: ReaderState
    let onDismiss: () -> Void

    // 本地状态
    @State private var showOutline = false
    @State private var showPageJump = false
    @State private var isSelectingText = false
    @State private var touchStartPoint: CGPoint = .zero

    // 选择菜单
    @State private var showSelectionMenu = false
    @State private var selectionMenuPosition: CGPoint = .zero

    // 书签状态
    @State private var isBookmarked = false
    @State private var showBookmarkToast = false
    @State private var bookmarkToastMessage = ""

    // EPUB 朗读状态
    @StateObject private var speechManager = SpeechManager.shared
    @State private var showSpeechControl = false

    // 手写笔记
    @State private var showHandwritingNoteSheet = false

    // 初始化
    init(state: ReaderState, onDismiss: @escaping () -> Void) {
        self.state = state
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏（非全屏时显示）
                if !state.isFullscreen {
                    topNavigationBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 阅读区域 - 根据内容类型切换
                if state.contentType == .epub {
                    // EPUB 阅读区域
                    epubContentArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // PDF 阅读区域
                    pdfContentArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // 底部工具栏（非全屏时显示）
                if !state.isFullscreen {
                    if state.contentType == .epub {
                        epubBottomToolbar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        bottomToolbar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            // 全屏模式下的退出按钮
            if state.isFullscreen {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                state.isFullscreen = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text("退出全屏")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 50)
                    }
                    Spacer()
                }
            }

            // 书签 Toast
            if showBookmarkToast {
                VStack {
                    Spacer()
                    Text(bookmarkToastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, state.isFullscreen ? 50 : 150)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showBookmarkToast)
            }
        }
        .sheet(isPresented: $showOutline) {
            if state.contentType == .epub {
                EPUBOutlineSheet(
                    chapters: state.chapters,
                    currentChapterIndex: state.currentChapterIndex,
                    onChapterSelected: { chapterId in
                        Task {
                            await state.goToChapter(chapterId)
                        }
                        showOutline = false
                    }
                )
            } else {
                OutlineSheet(
                    document: state.pdfDocument,
                    currentPage: state.currentPage,
                    onPageSelected: { page in
                        state.jumpToPage(page)
                        showOutline = false
                    }
                )
            }
        }
        .sheet(isPresented: $showPageJump) {
            PageJumpSheet(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onJump: { page in
                    state.jumpToPage(page)
                    showPageJump = false
                }
            )
        }
        .sheet(isPresented: $showHandwritingNoteSheet) {
            // 手写笔记提示（批注功能已移至独立界面）
            VStack(spacing: 16) {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)
                Text("使用批注模式")
                    .font(.headline)
                Text("返回教材列表，选择「批注模式」打开教材，即可使用 Apple Pencil 书写批注")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("知道了") {
                    showHandwritingNoteSheet = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .presentationDetents([.medium])
        }
        .onAppear {
            updateBookmarkState()
        }
        .onDisappear {
            // 退出时停止朗读
            speechManager.stop()
        }
        .onChange(of: state.currentPage) { _, _ in
            updateBookmarkState()
        }
    }

    // MARK: - PDF 内容区域（纯阅读模式）

    private var pdfContentArea: some View {
        ZStack {
            // 简单的 PDF 视图
            SimplePDFViewWrapper(
                document: state.pdfDocument,
                currentPage: Binding(
                    get: { state.currentPage },
                    set: { state.currentPage = $0 }
                ),
                onTextSelected: { text, rect in
                    handleTextSelection(text: text, rect: rect)
                }
            )

            // 选择菜单
            if showSelectionMenu {
                CustomSelectionMenu(
                    position: selectionMenuPosition,
                    selection: state.selection,
                    onDictionary: handleDictionary,
                    onSpeak: handleSpeak,
                    onBookmark: handleBookmark,
                    onCopy: handleCopy,
                    onDismiss: {
                        showSelectionMenu = false
                        state.clearSelection()
                    }
                )
            }
        }
    }

    // MARK: - EPUB 内容区域

    private var epubContentArea: some View {
        ZStack {
            EPUBWebView(
                html: state.currentChapterHtml,
                onTextSelected: { text, rect in
                    handleTextSelection(text: text, rect: rect)
                }
            )
            .background(Color.white)

            if state.isLoadingChapter {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.9))
            }

            if showSelectionMenu {
                CustomSelectionMenu(
                    position: selectionMenuPosition,
                    selection: state.selection,
                    onDictionary: handleDictionary,
                    onSpeak: handleSpeak,
                    onBookmark: handleBookmark,
                    onCopy: handleCopy,
                    onDismiss: {
                        showSelectionMenu = false
                        state.clearSelection()
                    }
                )
            }
        }
    }

    // MARK: - EPUB 底部工具栏

    private var epubBottomToolbar: some View {
        VStack(spacing: 0) {
            // 如果正在朗读，显示朗读控制栏
            if showSpeechControl || speechManager.state != .idle {
                SpeechControlBar(
                    speechManager: speechManager,
                    text: extractPlainText(from: state.currentChapterHtml),
                    onClose: {
                        showSpeechControl = false
                    }
                )
            } else {
                // 章节进度
                HStack(spacing: 16) {
                    Text("\(state.currentChapterIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 30)

                    SafeSlider(
                        value: Binding(
                            get: { Double(state.currentChapterIndex + 1) },
                            set: { newValue in
                                let index = Int(newValue) - 1
                                if index >= 0 && index < state.chapters.count {
                                    Task {
                                        await state.goToChapter(state.chapters[index].id)
                                    }
                                }
                            }
                        ),
                        in: 1...Double(max(1, state.chapters.count)),
                        step: 1
                    )
                    .tint(.appPrimary)

                    Text("\(state.chapters.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 30)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // 工具按钮行
                HStack(spacing: 24) {
                    ToolbarButton(icon: "chevron.left", label: "上一章") {
                        Task { await state.previousChapter() }
                    }
                    .disabled(!state.hasPreviousChapter)
                    .opacity(state.hasPreviousChapter ? 1 : 0.4)

                    ToolbarButton(icon: "list.bullet", label: "目录") {
                        showOutline = true
                    }

                    // 朗读按钮
                    ToolbarButton(
                        icon: "speaker.wave.2",
                        label: "朗读"
                    ) {
                        showSpeechControl = true
                        // 自动开始朗读
                        let text = extractPlainText(from: state.currentChapterHtml)
                        if !text.isEmpty {
                            speechManager.speak(text)
                        }
                    }

                    ToolbarButton(
                        icon: isBookmarked ? "bookmark.fill" : "bookmark",
                        label: isBookmarked ? "已标记" : "书签"
                    ) {
                        handleBookmark()
                    }

                    ToolbarButton(icon: "chevron.right", label: "下一章") {
                        Task { await state.nextChapter() }
                    }
                    .disabled(!state.hasNextChapter)
                    .opacity(state.hasNextChapter ? 1 : 0.4)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.black.opacity(0.6))
        .onChange(of: state.currentChapterId) { _, _ in
            // 切换章节时停止朗读
            if speechManager.state != .idle {
                speechManager.stop()
            }
        }
    }

    /// 从 HTML 中提取纯文本用于朗读
    private func extractPlainText(from html: String) -> String {
        // 移除 HTML 标签
        var text = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        // 合并多个空白字符
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 顶部导航栏

    private var topNavigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(.white)
            }

            Spacer()

            // 标题
            VStack(spacing: 2) {
                Text(state.textbook.displayTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if state.contentType == .epub {
                    Text(state.currentChapterTitle.isEmpty ? "第 \(state.currentChapterIndex + 1) / \(state.chapters.count) 章" : state.currentChapterTitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text("第 \(state.currentPage) / \(state.totalPages) 页")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            // 工具按钮
            HStack(spacing: 16) {
                // 目录
                Button {
                    showOutline = true
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                }

                // 全屏按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.isFullscreen = true
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            // 页码滑块
            HStack(spacing: 16) {
                Text("\(state.currentPage)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 30)

                SafeSlider(
                    value: Binding(
                        get: { Double(RangeGuard.guardPage(state.currentPage, totalPages: state.totalPages)) },
                        set: { state.currentPage = Int($0) }
                    ),
                    in: 1...Double(RangeGuard.guardTotalPages(state.totalPages)),
                    step: 1
                )
                .tint(.appPrimary)

                Text("\(state.totalPages)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 30)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // 工具按钮行
            HStack(spacing: 32) {
                // 上一页
                ToolbarButton(icon: "chevron.left", label: "上一页") {
                    state.previousPage()
                }
                .disabled(state.currentPage <= 1)
                .opacity(state.currentPage <= 1 ? 0.4 : 1)

                // 跳页
                ToolbarButton(icon: "arrow.right.doc.on.clipboard", label: "跳页") {
                    showPageJump = true
                }

                // 书签（根据状态显示实心/空心）
                ToolbarButton(
                    icon: isBookmarked ? "bookmark.fill" : "bookmark",
                    label: isBookmarked ? "已标记" : "书签"
                ) {
                    handleBookmark()
                }

                // 下一页
                ToolbarButton(icon: "chevron.right", label: "下一页") {
                    state.nextPage()
                }
                .disabled(state.currentPage >= state.totalPages)
                .opacity(state.currentPage >= state.totalPages ? 0.4 : 1)
            }
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.6))
    }

    // MARK: - 书签状态更新

    private func updateBookmarkState() {
        isBookmarked = BookmarkManager.shared.isBookmarked(
            textbookId: state.textbook.id,
            page: state.currentPage
        )
    }

    // MARK: - 选择处理

    private func handleTextSelection(text: String, rect: CGRect) {
        state.selectText(text, rect: rect)
        selectionMenuPosition = CGPoint(
            x: rect.midX,
            y: rect.minY - 50  // 菜单显示在选区上方
        )
        showSelectionMenu = true
    }

    // MARK: - 本地操作（无网络依赖）

    private func handleDictionary() {
        if case .text(let text) = state.selection {
            // 调用系统词典
            let referenceLibraryController = UIReferenceLibraryViewController(term: text)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(referenceLibraryController, animated: true)
            }
        }
        showSelectionMenu = false
    }

    private func handleSpeak() {
        if case .text(let text) = state.selection {
            state.speak(text)
        }
        showSelectionMenu = false
    }

    private func handleBookmark() {
        let wasBookmarked = isBookmarked
        BookmarkManager.shared.toggleBookmark(
            textbookId: state.textbook.id,
            page: state.currentPage
        )
        updateBookmarkState()

        // 显示 Toast
        bookmarkToastMessage = wasBookmarked ? "已取消书签" : "已添加书签"
        withAnimation {
            showBookmarkToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showBookmarkToast = false
            }
        }

        showSelectionMenu = false
    }

    private func handleCopy() {
        if case .text(let text) = state.selection {
            UIPasteboard.general.string = text
        }
        showSelectionMenu = false
        state.clearSelection()
    }
}

// MARK: - AnnotatablePDFViewRepresentable 已移动到 PDFAnnotationProvider.swift
// @AI:DEPRECATED 此处原有定义已删除，使用 PDFAnnotationProvider.swift 中的统一定义

// MARK: - 工具栏按钮

private struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - 目录弹窗

private struct OutlineSheet: View {
    let document: PDFDocument?
    let currentPage: Int
    let onPageSelected: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            if let document = document {
                PDFOutlineView(
                    document: document,
                    currentPage: currentPage,
                    onPageSelected: onPageSelected
                )
            } else {
                ContentUnavailableView("暂无目录", systemImage: "list.bullet")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 跳页弹窗

private struct PageJumpSheet: View {
    let currentPage: Int
    let totalPages: Int
    let onJump: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var inputPage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("当前第 \(currentPage) / \(totalPages) 页")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("跳转到")
                    TextField("页码", text: $inputPage)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    Text("页")
                }

                Button {
                    if let page = Int(inputPage), page >= 1, page <= totalPages {
                        onJump(page)
                    }
                } label: {
                    Text("确定")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }
                .disabled(Int(inputPage) == nil || Int(inputPage)! < 1 || Int(inputPage)! > totalPages)

                Spacer()
            }
            .padding()
            .navigationTitle("跳转页码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
        .onAppear {
            inputPage = String(currentPage)
        }
    }
}

// MARK: - 书签管理器

class BookmarkManager {
    static let shared = BookmarkManager()

    private let key = "textbook_bookmarks"

    private init() {}

    func isBookmarked(textbookId: String, page: Int) -> Bool {
        let bookmarks = getBookmarks(for: textbookId)
        return bookmarks.contains(page)
    }

    func toggleBookmark(textbookId: String, page: Int) {
        var bookmarks = getBookmarks(for: textbookId)
        if bookmarks.contains(page) {
            bookmarks.remove(page)
        } else {
            bookmarks.insert(page)
        }
        saveBookmarks(bookmarks, for: textbookId)
    }

    private func getBookmarks(for textbookId: String) -> Set<Int> {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [Int]] ?? [:]
        return Set(dict[textbookId] ?? [])
    }

    private func saveBookmarks(_ bookmarks: Set<Int>, for textbookId: String) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [Int]] ?? [:]
        dict[textbookId] = Array(bookmarks)
        UserDefaults.standard.set(dict, forKey: key)
    }
}

// MARK: - EPUB 目录弹窗

private struct EPUBOutlineSheet: View {
    let chapters: [EPUBChapter]
    let currentChapterIndex: Int
    let onChapterSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            if chapters.isEmpty {
                ContentUnavailableView("暂无目录", systemImage: "list.bullet")
            } else {
                List(chapters) { chapter in
                    Button {
                        onChapterSelected(chapter.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)

                                if chapter.order + 1 == currentChapterIndex + 1 {
                                    Text("当前章节")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if chapter.order == currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        chapter.order == currentChapterIndex
                            ? Color.appPrimary.opacity(0.1)
                            : Color.clear
                    )
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("目录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 预览

#Preview {
    Text("PureReaderView Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
