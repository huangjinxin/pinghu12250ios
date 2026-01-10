//
//  AssistModeView.swift
//  pinghu12250
//
//  AI辅助模式 - 横屏专用
//  分屏布局：左侧PDF + 右侧AI面板
//  5个Tab与Web端对齐：探索/解析/练习/解题/笔记
//

import SwiftUI
import PDFKit
import UIKit
import Combine
import AVFoundation
import PencilKit

struct AssistModeView: View {
    @ObservedObject var state: ReaderState
    @ObservedObject var layoutManager: ReaderLayoutManager
    let onDismiss: () -> Void

    // 区域选择
    @State private var isSelectingRegion = false
    @State private var selectedRegion: CGRect?
    @State private var showAISelectionMenu = false
    @State private var selectionMenuPosition: CGPoint = .zero

    // 草稿画布
    @State private var showDraftCanvas = false

    // 手写笔记
    @State private var showHandwritingNoteSheet = false

    var body: some View {
        ZStack {
            if state.isFullscreen {
                // 全屏模式：只显示 PDF
                fullscreenPDFView
            } else {
                // 分屏模式
                ResizableSplitView(
                    splitRatio: $layoutManager.splitRatio,
                    minLeadingWidth: 300,
                    minTrailingWidth: 280,
                    leading: {
                        // 左侧 PDF 区域
                        pdfSection
                    },
                    trailing: {
                        // 右侧 AI 面板
                        if layoutManager.isPanelVisible {
                            aiPanelSection
                        }
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .overlay {
            // 区域选择覆盖层 - 使用完整版支持拖动调整
            if isSelectingRegion {
                RegionSelectorOverlay(
                    isSelecting: $isSelectingRegion,
                    selectedRegion: $selectedRegion,
                    onCapture: { image in
                        handleRegionCaptureWithImage(image)
                    },
                    getScreenshot: {
                        state.captureCurrentPage()
                    }
                )
            }

            // 草稿画布覆盖层
            if showDraftCanvas {
                DraftCanvasOverlay(
                    isPresented: $showDraftCanvas,
                    textbookId: state.textbook.id,
                    currentPage: state.currentPage,
                    notesManager: NotesManager.shared
                )
            }
        }
        .sheet(isPresented: $showHandwritingNoteSheet) {
            // 手写笔记提示（批注功能已移至独立界面）
            VStack(spacing: 16) {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)
                Text("使用草稿画布")
                    .font(.headline)
                Text("点击工具栏的草稿按钮，可以使用 Apple Pencil 书写笔记")
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
    }

    // MARK: - 全屏 PDF 视图

    private var fullscreenPDFView: some View {
        VStack(spacing: 0) {
            // 固定导航栏
            fullscreenNavigationBar

            // PDF 阅读区域
            ZStack {
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

                // AI 选择菜单
                if showAISelectionMenu {
                    AISelectionMenu(
                        position: selectionMenuPosition,
                        selection: state.selection,
                        onAnalyze: { handleAIAction(.analyze) },
                        onPractice: { handleAIAction(.practice) },
                        onSolving: { handleAIAction(.solving) },
                        onSaveNote: { handleSaveNote() },
                        onSpeak: { handleSpeak() },
                        onDismiss: {
                            showAISelectionMenu = false
                            state.clearSelection()
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 固定底部工具栏
            fullscreenBottomToolbar
        }
        .background(Color.black)
    }

    // MARK: - 全屏导航栏

    private var fullscreenNavigationBar: some View {
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

            // 标题和页码
            VStack(spacing: 2) {
                Text(state.textbook.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("第 \(state.currentPage) / \(state.totalPages) 页")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // 退出全屏按钮
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    state.isFullscreen = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                    Text("退出全屏")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - 全屏底部工具栏

    private var fullscreenBottomToolbar: some View {
        HStack(spacing: 20) {
            // 翻页控制
            HStack(spacing: 16) {
                Button {
                    state.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(state.currentPage > 1 ? .white : .gray)
                }
                .disabled(state.currentPage <= 1)

                // 页码滑块
                SafeSlider(
                    value: Binding(
                        get: { Double(RangeGuard.guardPage(state.currentPage, totalPages: state.totalPages)) },
                        set: { state.currentPage = Int($0) }
                    ),
                    in: 1...Double(RangeGuard.guardTotalPages(state.totalPages)),
                    step: 1
                )
                .tint(.appPrimary)
                .frame(width: 200)

                Button {
                    state.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(state.currentPage < state.totalPages ? .white : .gray)
                }
                .disabled(state.currentPage >= state.totalPages)
            }

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.3))

            // 目录
            OutlineButton(
                document: state.pdfDocument,
                currentPage: state.currentPage,
                onPageSelected: { page in
                    state.jumpToPage(page)
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - PDF 区域

    private var pdfSection: some View {
        VStack(spacing: 0) {
            // 导航栏（固定显示）
            contentNavigationBar

            // 内容区域（根据类型切换）
            ZStack {
                if state.contentType == .epub {
                    // EPUB 阅读器
                    EPUBReaderView(
                        state: state,
                        onTextSelected: { text, rect in
                            handleTextSelection(text: text, rect: rect)
                        }
                    )
                } else {
                    // PDF 阅读器（纯阅读模式，批注功能在独立界面）
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
                }

                // AI 选择菜单
                if showAISelectionMenu {
                    AISelectionMenu(
                        position: selectionMenuPosition,
                        selection: state.selection,
                        onAnalyze: { handleAIAction(.analyze) },
                        onPractice: { handleAIAction(.practice) },
                        onSolving: { handleAIAction(.solving) },
                        onSaveNote: { handleSaveNote() },
                        onSpeak: { handleSpeak() },
                        onDismiss: {
                            showAISelectionMenu = false
                            state.clearSelection()
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部工具栏（固定显示）
            contentBottomToolbar
        }
        .background(Color.black)
    }

    // MARK: - 内容导航栏（PDF/EPUB 共用）

    private var contentNavigationBar: some View {
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

            // 标题和页码
            VStack(spacing: 2) {
                Text(state.textbook.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("第 \(state.currentPage) / \(state.totalPages) 页")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // 工具按钮
            HStack(spacing: 12) {
                // 全屏按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        state.isFullscreen = true
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.white)
                }

                // 布局预设
                LayoutPresetMenu(layoutManager: layoutManager)

                // 目录
                OutlineButton(
                    document: state.pdfDocument,
                    currentPage: state.currentPage,
                    onPageSelected: { page in
                        state.jumpToPage(page)
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - 内容底部工具栏（PDF/EPUB 共用）

    private var contentBottomToolbar: some View {
        HStack(spacing: 12) {
            // 左侧：草稿画布按钮（仅 PDF）
            if state.contentType == .pdf {
                Button {
                    showDraftCanvas = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "scribble.variable")
                            .font(.title3)
                        Text("草稿")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
            } else {
                // EPUB: 占位或其他功能
                Spacer()
                    .frame(width: 50)
            }

            Spacer()

            // 中间：导航控制（PDF 翻页 / EPUB 切章）
            if state.contentType == .pdf {
                // PDF 翻页控制
                HStack(spacing: 16) {
                    Button {
                        state.previousPage()
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(state.currentPage > 1 ? .white : .gray.opacity(0.5))
                    }
                    .disabled(state.currentPage <= 1)

                    // 页码滑块（使用 SafeSlider 防止崩溃）
                    SafeSlider(
                        value: Binding(
                            get: { Double(RangeGuard.guardPage(state.currentPage, totalPages: state.totalPages)) },
                            set: { state.currentPage = Int($0) }
                        ),
                        in: 1...Double(RangeGuard.guardTotalPages(state.totalPages)),
                        step: 1
                    )
                    .tint(.appPrimary)
                    .frame(width: 120)

                    Button {
                        state.nextPage()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(state.currentPage < state.totalPages ? .white : .gray.opacity(0.5))
                    }
                    .disabled(state.currentPage >= state.totalPages)
                }
            } else {
                // EPUB 章节导航
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await state.previousChapter()
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(state.hasPreviousChapter ? .white : .gray.opacity(0.5))
                    }
                    .disabled(!state.hasPreviousChapter)

                    // 章节进度显示
                    Text("\(state.currentChapterIndex + 1) / \(state.chapters.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(width: 80)

                    Button {
                        Task {
                            await state.nextChapter()
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(state.hasNextChapter ? .white : .gray.opacity(0.5))
                    }
                    .disabled(!state.hasNextChapter)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .onChange(of: state.shouldStartRegionCapture) { _, shouldStart in
            // 响应来自AI面板的区域截图请求
            if shouldStart {
                isSelectingRegion = true
                state.clearRegionCaptureRequest()
            }
        }
    }

    // MARK: - AI 面板区域

    private var aiPanelSection: some View {
        VStack(spacing: 0) {
            // 词典查询面板（仅当选中单个字词时显示）
            if state.showDictionaryPanel, let word = state.dictionaryWord {
                DictionaryPanel(
                    word: word,
                    onSpeak: {
                        state.speak(word)
                    },
                    onSaveNote: {
                        Task {
                            await NotesManager.shared.saveNote(
                                text: word,
                                textbookId: state.textbook.id,
                                page: state.currentPage
                            )
                        }
                    },
                    onDismiss: {
                        state.clearDictionaryWord()
                    }
                )
            }

            // Tab 栏
            aiTabBar

            // Tab 内容（顺序与Tab栏一致：探索-解析-练习-解题-笔记）
            TabView(selection: $state.selectedTab) {
                ExploreTabView(state: state)
                    .tag(AITab.explore)

                AnalyzeTabView(state: state)
                    .tag(AITab.analyze)

                PracticeTabView(state: state)
                    .tag(AITab.practice)

                SolvingTabView(state: state)
                    .tag(AITab.solving)

                NotesTabView(state: state)
                    .tag(AITab.notes)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemBackground))
    }

    // MARK: - AI Tab 栏

    private var aiTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AITab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(state.selectedTab == tab ? .appPrimary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        state.selectedTab == tab ?
                        Color.appPrimary.opacity(0.1) : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemGray6))
    }

    // MARK: - 事件处理

    private func handleTextSelection(text: String, rect: CGRect) {
        state.selectText(text, rect: rect)
        selectionMenuPosition = CGPoint(
            x: rect.midX,
            y: rect.minY - 50
        )
        showAISelectionMenu = true

        // 如果是单个词，自动触发词典查询
        if state.isWord(text) {
            state.setDictionaryWord(text)
        } else {
            state.clearDictionaryWord()
        }
    }

    private func handleAIAction(_ tab: AITab) {
        state.selectedTab = tab
        showAISelectionMenu = false

        // 准备 AI 输入
        if case .text(let text) = state.selection {
            state.pendingInput = text
        }

        // 截取当前页作为上下文
        if let image = state.captureCurrentPage() {
            state.pendingImage = image
        }

        layoutManager.expandPanel()
    }

    private func handleSaveNote() {
        if case .text(let text) = state.selection {
            Task {
                await NotesManager.shared.saveNote(
                    text: text,
                    textbookId: state.textbook.id,
                    page: state.currentPage
                )
            }
        }
        showAISelectionMenu = false
        state.clearSelection()
    }

    private func handleSpeak() {
        if case .text(let text) = state.selection {
            state.speak(text)
        }
        showAISelectionMenu = false
    }

    private func handleRegionCapture(_ rect: CGRect) {
        // 截取选区
        if let image = state.captureCurrentPage() {
            // 裁剪选区
            let scale = UIScreen.main.scale
            let scaledRect = CGRect(
                x: rect.origin.x * scale,
                y: rect.origin.y * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )

            if let cgImage = image.cgImage?.cropping(to: scaledRect) {
                let croppedImage = UIImage(cgImage: cgImage)
                state.selectRegion(croppedImage)
                state.selectedTab = .analyze
                layoutManager.expandPanel()
            }
        }
    }

    // 处理来自 RegionSelectorOverlay 的图片（已裁剪）
    private func handleRegionCaptureWithImage(_ image: UIImage) {
        state.selectRegion(image)
        state.selectedTab = .analyze
        layoutManager.expandPanel()
    }

    private func handlePageCapture() {
        state.selectPage()
        state.selectedTab = .analyze
        layoutManager.expandPanel()
    }
}

// MARK: - 布局预设菜单
// @AI:DEPRECATED AssistModePDFView 和 ChinesePDFView 已删除
// 现在统一使用 PDFAnnotationProvider.swift 中的 AnnotatablePDFViewRepresentable

struct LayoutPresetMenu: View {
    @ObservedObject var layoutManager: ReaderLayoutManager

    var body: some View {
        Menu {
            ForEach(ReaderLayoutManager.LayoutPreset.allCases, id: \.self) { preset in
                Button {
                    layoutManager.applyPreset(preset)
                } label: {
                    HStack {
                        Text(preset.rawValue)
                        if abs(layoutManager.splitRatio - preset.ratio) < 0.05 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "rectangle.split.2x1")
                .foregroundColor(.white)
        }
    }
}

// MARK: - 预览

#Preview {
    Text("AssistModeView Preview")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
}

// MARK: - 词典查询面板

struct DictionaryPanel: View {
    let word: String
    let onSpeak: () -> Void
    let onSaveNote: () -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = true
    @State private var hasDictionary = false
    @State private var showDictionaryView = false
    @State private var dictEntry: DictEntry?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏（可折叠）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.orange)

                    Text("词典")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(word)
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
            }
            .buttonStyle(.plain)

            // 展开内容
            if isExpanded {
                VStack(spacing: 12) {
                    // 词汇和拼音显示
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(word)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                // 拼音（来自API）
                                if let entry = dictEntry, !entry.pinyin.isEmpty {
                                    Text(entry.pinyin)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .italic()
                                }
                            }

                            // 首条解释（来自API）
                            if let entry = dictEntry, !entry.definition.isEmpty {
                                Text(entry.definition)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if isLoading {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("查询中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // 查看详细词典按钮
                        if hasDictionary {
                            Button {
                                showDictionaryView = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "book.fill")
                                    Text("查看释义")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                        }
                    }

                    Divider()

                    // 操作按钮
                    HStack(spacing: 16) {
                        // 朗读
                        Button {
                            onSpeak()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title3)
                                Text("朗读")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                        }

                        // 复制
                        Button {
                            UIPasteboard.general.string = word
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.title3)
                                Text("复制")
                                    .font(.caption2)
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                        }

                        // 保存到笔记
                        Button {
                            onSaveNote()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.title3)
                                Text("保存")
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .onAppear {
            // 检查系统词典是否有该词的定义
            hasDictionary = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
            // 查询API获取拼音和解释
            loadDictEntry()
        }
        .onChange(of: word) { _, newWord in
            hasDictionary = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: newWord)
            loadDictEntry()
        }
        .sheet(isPresented: $showDictionaryView) {
            DictionaryViewWrapper(term: word)
        }
    }

    private func loadDictEntry() {
        // 只查询单个汉字
        guard word.count == 1 else {
            dictEntry = nil
            return
        }

        isLoading = true
        Task {
            let entry = await LocalDictionaryService.shared.lookupCharacter(word)
            await MainActor.run {
                dictEntry = entry
                isLoading = false
            }
        }
    }
}

// MARK: - 系统词典包装器

struct DictionaryViewWrapper: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        return UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {
        // 不需要更新
    }
}

// MARK: - 草稿画布覆盖层

struct DraftCanvasOverlay: View {
    @Binding var isPresented: Bool
    let textbookId: String
    let currentPage: Int
    @ObservedObject var notesManager: NotesManager

    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor = CanvasColor.presets[0]
    @State private var lineWidth: CGFloat = 3
    @State private var isRulerActive = false
    @State private var allowsFingerDrawing = true

    // 退出确认
    @State private var showExitAlert = false
    // 保存成功提示
    @State private var showSaveSuccess = false
    @State private var saveSuccessMessage = ""
    // 收藏状态
    @State private var isFavorite = false

    /// 画布是否有内容
    private var hasContent: Bool {
        !drawing.strokes.isEmpty
    }

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景不关闭，保持绘图状态
                }

            VStack(spacing: 0) {
                // 顶部工具栏
                draftToolbar

                // PencilKit 画布
                PencilKitCanvas(
                    canvasView: $canvasView,
                    drawing: $drawing,
                    tool: selectedTool,
                    color: selectedColor.color,
                    lineWidth: lineWidth,
                    backgroundColor: .clear,
                    isRulerActive: isRulerActive,
                    allowsFingerDrawing: allowsFingerDrawing
                )
                .background(Color.white.opacity(0.1))
                .ignoresSafeArea(edges: .bottom)
            }

            // 保存成功提示
            if showSaveSuccess {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(saveSuccessMessage)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .transition(.opacity)
        .alert("退出草稿", isPresented: $showExitAlert) {
            Button("保存并退出", role: .none) {
                saveToNotes(asFavorite: false)
                closeOverlay()
            }
            Button("放弃草稿", role: .destructive) {
                closeOverlay()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("草稿内容尚未保存，是否保存到笔记？")
        }
    }

    // MARK: - 保存到笔记

    private func saveToNotes(asFavorite: Bool) {
        guard hasContent else { return }

        // 将绘图转换为图片数据
        let drawingData = drawing.dataRepresentation()

        // 创建手写笔记附件
        let attachment = NoteAttachment(
            id: UUID(),
            type: .drawing,
            data: drawingData,
            url: nil
        )

        // 创建笔记
        let note = StudyNote(
            textbookId: textbookId,
            pageIndex: currentPage - 1,  // 转为0-indexed
            title: "手写草稿 P\(currentPage)",
            content: "手写草稿",
            type: .handwriting,
            tags: ["草稿"],
            isFavorite: asFavorite,
            attachments: [attachment]
        )

        notesManager.createNote(note)

        // 显示成功提示
        saveSuccessMessage = asFavorite ? "已收藏到笔记 (P\(currentPage))" : "已保存到笔记 (P\(currentPage))"
        withAnimation(.spring(response: 0.3)) {
            showSaveSuccess = true
        }

        // 2秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }

        // 清空画布
        drawing = PKDrawing()
    }

    private func closeOverlay() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }

    private func handleClose() {
        if hasContent {
            showExitAlert = true
        } else {
            closeOverlay()
        }
    }

    private var draftToolbar: some View {
        HStack(spacing: 10) {
            // 关闭按钮（带确认）
            Button {
                handleClose()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("关闭")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }

            // 页码显示
            Text("P\(currentPage)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(4)

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.3))

            // 工具选择
            ForEach(CanvasTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundColor(selectedTool == tool ? .appPrimary : .white)
                        .frame(width: 32, height: 32)
                        .background(selectedTool == tool ? Color.white : Color.clear)
                        .cornerRadius(6)
                }
            }

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.3))

            // 颜色选择
            Menu {
                ForEach(CanvasColor.presets) { canvasColor in
                    Button {
                        selectedColor = canvasColor
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(canvasColor.color))
                                .frame(width: 16, height: 16)
                            Text(canvasColor.name)
                            if selectedColor.id == canvasColor.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(Color(selectedColor.color))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }

            // 线宽选择
            Menu {
                ForEach([1.0, 3.0, 5.0, 8.0, 12.0], id: \.self) { width in
                    Button {
                        lineWidth = width
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: width / 2)
                                .fill(Color(selectedColor.color))
                                .frame(width: 40, height: width)
                            Text("\(Int(width))pt")
                            if lineWidth == width {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "lineweight")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // 标尺开关
            Button {
                isRulerActive.toggle()
            } label: {
                Image(systemName: "ruler")
                    .font(.system(size: 18))
                    .foregroundColor(isRulerActive ? .appPrimary : .white)
            }

            // 手指绘图开关
            Button {
                allowsFingerDrawing.toggle()
            } label: {
                Image(systemName: allowsFingerDrawing ? "hand.draw.fill" : "hand.draw")
                    .font(.system(size: 18))
                    .foregroundColor(allowsFingerDrawing ? .appPrimary : .white)
            }

            Spacer()

            // 撤销
            Button {
                canvasView.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // 重做
            Button {
                canvasView.undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // 清除
            Button {
                drawing = PKDrawing()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.3))

            // 保存到笔记按钮
            Button {
                saveToNotes(asFavorite: false)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("保存")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(hasContent ? Color.appPrimary : Color.gray.opacity(0.5))
                .cornerRadius(8)
            }
            .disabled(!hasContent)

            // 收藏按钮
            Button {
                saveToNotes(asFavorite: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("收藏")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(hasContent ? Color.orange : Color.gray.opacity(0.5))
                .cornerRadius(8)
            }
            .disabled(!hasContent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
    }
}
