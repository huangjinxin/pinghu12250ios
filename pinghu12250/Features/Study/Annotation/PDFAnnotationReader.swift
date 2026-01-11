//
//  PDFAnnotationReader.swift
//  pinghu12250
//
//  PDF 批注阅读器 - PencilKit 版本
//
//  架构说明：
//  - 输入采集：PencilKit (PKCanvasView) - Apple 官方推荐
//  - 持久化渲染：PDFKit (PDFAnnotation.ink)
//  - 存储格式：XFDF 标准格式
//
//  层级关系：
//  - PDFView（底层）：显示 PDF 和已提交的批注
//  - PKCanvasView（顶层）：临时绘制层，仅响应 Apple Pencil
//
//  输入设备策略：
//  - Apple Pencil → 绘制批注（通过 PKCanvasView.drawingPolicy = .pencilOnly）
//  - Finger → 导航（缩放/滚动，穿透到 PDFView）
//

import SwiftUI
import UIKit
import PDFKit
import PencilKit
import Combine

// MARK: - 批注阅读器主视图

@available(iOS 16.0, *)
struct PDFAnnotationReaderView: View {

    // MARK: - Properties

    let textbook: Textbook
    let initialPageIndex: Int?
    let onDismiss: () -> Void

    @StateObject private var viewModel: AnnotationReaderViewModel

    init(textbook: Textbook, initialPageIndex: Int?, onDismiss: @escaping () -> Void) {
        self.textbook = textbook
        self.initialPageIndex = initialPageIndex
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: AnnotationReaderViewModel(textbook: textbook))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("加载 PDF...")
                    .foregroundColor(.white)
            } else if viewModel.document != nil {
                VStack(spacing: 0) {
                    topBar
                    AnnotatablePDFView(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)
                    bottomToolBar
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("PDF 加载失败")
                        .foregroundColor(.white)
                    Button("返回") { onDismiss() }
                        .foregroundColor(.appPrimary)
                }
            }

            // 保存成功提示
            if viewModel.showSaveSuccess {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("批注已保存")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await viewModel.loadPDF()
            if let page = initialPageIndex {
                viewModel.goToPage(page)
            }
        }
        .onDisappear {
            viewModel.saveAnnotations()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(textbook.displayTitle)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("第 \(viewModel.currentPageIndex + 1) / \(viewModel.totalPages) 页")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                viewModel.toggleAnnotationMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isAnnotationMode ? "pencil.tip.crop.circle.badge.minus" : "pencil.tip.crop.circle")
                    Text(viewModel.isAnnotationMode ? "退出批注" : "批注")
                }
                .font(.subheadline)
                .foregroundColor(viewModel.isAnnotationMode ? .orange : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.isAnnotationMode ? Color.orange.opacity(0.2) : Color.white.opacity(0.2))
                .cornerRadius(8)
            }

            Button {
                viewModel.saveAnnotations()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("保存")
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Bottom Tool Bar

    private var bottomToolBar: some View {
        VStack(spacing: 0) {
            if !viewModel.isAnnotationMode {
                pageNavigationBar
            }
            if viewModel.isAnnotationMode {
                annotationToolBar
            }
        }
    }

    private var pageNavigationBar: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.previousPage()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.canGoPrevious ? .white : .gray)
            }
            .disabled(!viewModel.canGoPrevious)

            Spacer()

            Text("\(viewModel.currentPageIndex + 1) / \(viewModel.totalPages)")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                viewModel.nextPage()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.canGoNext ? .white : .gray)
            }
            .disabled(!viewModel.canGoNext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Annotation Tool Bar

    private var annotationToolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 工具按钮（不含橡皮擦）
                ForEach(InkToolType.allCases.filter { $0 != .eraser }) { tool in
                    toolButton(tool)
                }

                Divider().frame(height: 28).background(Color.gray)

                // 橡皮擦
                toolButton(.eraser)

                Divider().frame(height: 28).background(Color.gray)

                // 颜色选择（非橡皮擦模式显示）
                if viewModel.selectedTool != .eraser {
                    ForEach(InkColorPreset.presets.prefix(5)) { preset in
                        colorButton(preset)
                    }

                    Divider().frame(height: 28).background(Color.gray)

                    // 线宽滑动选择
                    HStack(spacing: 6) {
                        Image(systemName: "lineweight")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        SafeSlider(
                            value: $viewModel.selectedLineWidth,
                            in: 0.5...20,
                            step: 0.5
                        )
                        .frame(width: 100)

                        Text(String(format: "%.1f", viewModel.selectedLineWidth))
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(width: 28)
                    }
                }

                Divider().frame(height: 28).background(Color.gray)

                // 撤销/重做/清除
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(viewModel.canUndo ? .primary : .gray)
                }
                .disabled(!viewModel.canUndo)

                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(viewModel.canRedo ? .primary : .gray)
                }
                .disabled(!viewModel.canRedo)

                Button {
                    viewModel.clearCurrentPageAnnotations()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
        .background(Color(.systemGray6))
    }

    private func toolButton(_ tool: InkToolType) -> some View {
        Button {
            viewModel.selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 18))
                .foregroundColor(viewModel.selectedTool == tool ? .orange : .primary)
                .frame(width: 32, height: 32)
                .background(viewModel.selectedTool == tool ? Color.orange.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
    }

    private func colorButton(_ preset: InkColorPreset) -> some View {
        Button {
            viewModel.selectedColorPreset = preset
        } label: {
            Circle()
                .fill(Color(preset.color))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(
                            viewModel.selectedColorPreset.id == preset.id ? Color.white : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }
}

// MARK: - ViewModel

@available(iOS 16.0, *)
@MainActor
final class AnnotationReaderViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var document: PDFDocument?
    @Published var isLoading = true
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 0

    @Published var isAnnotationMode = false
    @Published var selectedTool: InkToolType = .pen {
        didSet { updatePencilKitTool() }
    }
    @Published var selectedColorPreset = InkColorPreset.presets[1] {
        didSet { updatePencilKitTool() }
    }
    @Published var selectedLineWidth: CGFloat = 3.0 {
        didSet { updatePencilKitTool() }
    }

    @Published var showSaveSuccess = false

    // MARK: - Ink Annotation Manager

    let inkAnnotationManager = InkAnnotationManager()

    // MARK: - PencilKit Controller

    let pencilKitController = PencilKitOverlayController()

    // MARK: - Internal State

    let textbook: Textbook
    private let storageService = AnnotationStorageService.shared
    private let xfdfService = XFDFAnnotationService.shared

    private var userId: String {
        AuthManager.shared.currentUser?.id ?? "guest"
    }

    weak var pdfView: PDFView?

    var canGoPrevious: Bool { currentPageIndex > 0 }
    var canGoNext: Bool { currentPageIndex < totalPages - 1 }
    var canUndo: Bool { inkAnnotationManager.canUndo }
    var canRedo: Bool { inkAnnotationManager.canRedo }

    // MARK: - Init

    init(textbook: Textbook) {
        self.textbook = textbook

        // 设置 PencilKit 控制器的 annotationManager
        pencilKitController.annotationManager = inkAnnotationManager
    }

    // MARK: - PDF Loading

    func loadPDF() async {
        isLoading = true
        guard let url = textbook.pdfFullURL else {
            isLoading = false
            return
        }

        do {
            let localURL = try await DownloadManager.shared.downloadPDF(url: url, textbookId: textbook.id)
            if let doc = PDFDocument(url: localURL) {
                document = doc
                totalPages = doc.pageCount

                // 设置 InkAnnotationManager
                inkAnnotationManager.setup(
                    document: doc,
                    pdfView: nil,
                    userId: userId,
                    textbookId: textbook.id
                )

                // 尝试从 XFDF 加载现有批注
                await loadAnnotations()

                #if DEBUG
                print("[AnnotationReader] 加载 PDF 成功，共 \(totalPages) 页")
                #endif
            }
        } catch {
            print("[AnnotationReader] 加载 PDF 失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - Load Annotations

    private func loadAnnotations() async {
        // 优先尝试 XFDF 格式
        if xfdfService.xfdfExists(userId: userId, textbookId: textbook.id) {
            inkAnnotationManager.loadFromXFDF()
            #if DEBUG
            print("[AnnotationReader] 从 XFDF 加载批注")
            #endif
            return
        }

        // 尝试迁移旧的 JSON 格式
        let jsonDoc = storageService.loadDocument(userId: userId, textbookId: textbook.id)
        if !jsonDoc.annotations.isEmpty,
           let doc = document {
            await migrateFromJSON(jsonDoc, to: doc)
            #if DEBUG
            print("[AnnotationReader] 从 JSON 迁移批注: \(jsonDoc.annotations.count) 条")
            #endif
        }
    }

    /// 从旧 JSON 格式迁移到 XFDF
    private func migrateFromJSON(_ jsonDoc: UserAnnotationDocument, to pdfDoc: PDFDocument) async {
        for strokeData in jsonDoc.annotations {
            guard strokeData.pageIndex < pdfDoc.pageCount,
                  let page = pdfDoc.page(at: strokeData.pageIndex) else {
                continue
            }

            // 创建 PDFAnnotation.ink
            _ = inkAnnotationManager.addInkAnnotation(
                points: strokeData.cgPoints,
                to: page,
                pageIndex: strokeData.pageIndex,
                color: strokeData.uiColor,
                lineWidth: strokeData.lineWidth,
                toolType: strokeData.toolType
            )
        }

        // 保存为 XFDF
        inkAnnotationManager.saveToXFDF()

        #if DEBUG
        print("[AnnotationReader] 迁移完成，已保存为 XFDF")
        #endif
    }

    // MARK: - Page Navigation

    func goToPage(_ pageIndex: Int) {
        guard let doc = document,
              pageIndex >= 0 && pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return }

        // 切换页面前提交当前笔画
        pencilKitController.commitImmediately()

        currentPageIndex = pageIndex
        pencilKitController.updateCurrentPage(pageIndex)
        pdfView?.go(to: page)
    }

    func nextPage() {
        if canGoNext { goToPage(currentPageIndex + 1) }
    }

    func previousPage() {
        if canGoPrevious { goToPage(currentPageIndex - 1) }
    }

    func updateCurrentPage(from pdfView: PDFView) {
        guard let page = pdfView.currentPage,
              let doc = pdfView.document else { return }
        let index = doc.index(for: page)
        if currentPageIndex != index {
            // 切换页面前提交当前笔画
            pencilKitController.commitImmediately()
            currentPageIndex = index
            pencilKitController.updateCurrentPage(index)
        }
    }

    // MARK: - Annotation Mode

    func toggleAnnotationMode() {
        if isAnnotationMode {
            // 退出批注模式前提交未提交的笔画
            pencilKitController.commitImmediately()
        }
        isAnnotationMode.toggle()
        #if DEBUG
        print("[AnnotationReader] 批注模式: \(isAnnotationMode ? "开启" : "关闭")")
        #endif
    }

    // MARK: - PencilKit Tool Update

    private func updatePencilKitTool() {
        pencilKitController.currentToolType = selectedTool
        pencilKitController.currentColor = selectedColorPreset.color
        pencilKitController.currentLineWidth = selectedLineWidth
    }

    // MARK: - Undo/Redo

    func undo() {
        inkAnnotationManager.undo()
        objectWillChange.send()
    }

    func redo() {
        inkAnnotationManager.redo()
        objectWillChange.send()
    }

    // MARK: - Clear Annotations

    func clearCurrentPageAnnotations() {
        // 先清空画布
        pencilKitController.clearCanvas()
        // 再清除已提交的批注
        inkAnnotationManager.clearPageAnnotations(pageIndex: currentPageIndex)
        objectWillChange.send()
    }

    // MARK: - Save

    func saveAnnotations() {
        // 先提交未提交的笔画
        pencilKitController.commitImmediately()
        // 保存到 XFDF
        inkAnnotationManager.saveToXFDF()
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { self.showSaveSuccess = false }
        }
    }
}

// MARK: - AnnotatablePDFView

@available(iOS 16.0, *)
struct AnnotatablePDFView: UIViewRepresentable {
    @ObservedObject var viewModel: AnnotationReaderViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> PencilKitAnnotationContainerView {
        let containerView = PencilKitAnnotationContainerView(viewModel: viewModel)
        context.coordinator.containerView = containerView
        return containerView
    }

    func updateUIView(_ containerView: PencilKitAnnotationContainerView, context: Context) {
        containerView.updateAnnotationMode(viewModel.isAnnotationMode)
    }

    class Coordinator: NSObject {
        let viewModel: AnnotationReaderViewModel
        weak var containerView: PencilKitAnnotationContainerView?

        init(viewModel: AnnotationReaderViewModel) {
            self.viewModel = viewModel
        }
    }
}

// MARK: - PencilKitAnnotationContainerView

@available(iOS 16.0, *)
class PencilKitAnnotationContainerView: UIView {

    // MARK: - Properties

    private let viewModel: AnnotationReaderViewModel
    private let pdfView: PDFView
    private let canvasView: PKCanvasView

    private var pageChangeObserver: NSObjectProtocol?

    // MARK: - Init

    init(viewModel: AnnotationReaderViewModel) {
        self.viewModel = viewModel
        self.pdfView = PDFView()
        self.canvasView = viewModel.pencilKitController.canvasView

        super.init(frame: .zero)

        setupPDFView()
        setupCanvasView()
        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = pageChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup

    private func setupPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true

        let fitScale = pdfView.scaleFactorForSizeToFit
        pdfView.minScaleFactor = fitScale
        pdfView.maxScaleFactor = fitScale * 10.0
        pdfView.backgroundColor = .darkGray

        // 设置 document
        pdfView.document = viewModel.document

        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 更新 ViewModel 的 PDFView 引用
        viewModel.pdfView = pdfView
        viewModel.inkAnnotationManager.updatePDFView(pdfView)
        viewModel.pencilKitController.pdfView = pdfView

        #if DEBUG
        print("[PencilKitContainer] PDFView setup complete")
        #endif
    }

    private func setupCanvasView() {
        canvasView.translatesAutoresizingMaskIntoConstraints = false

        // 初始隐藏（非批注模式）
        canvasView.isHidden = true

        addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 【架构合规】固定 z-order（只在初始化时设置一次）
        // canvasView 必须在 pdfView 之上，以便接收触摸事件
        // 之后不再修改 z-order，确保视图层级稳定
        bringSubviewToFront(canvasView)

        #if DEBUG
        print("[PencilKitContainer] Canvas view setup complete, z-order fixed (canvas on top)")
        #endif
    }

    private func setupObservers() {
        // 【架构合规】配置触摸类型隔离
        // - 分流在 Layer 2 (touchesShouldBegin)，不在 Layer 1 (hitTest)
        // - Pencil 触摸：PencilOnlyCanvasView 跟踪
        // - 手指触摸：自动穿透到 PDFView（滚动/缩放）
        viewModel.pencilKitController.configureTouchTypeIsolation(pdfView: pdfView)

        // 监听页面变化
        pageChangeObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.viewModel.updateCurrentPage(from: self.pdfView)
            }
        }

        // 注意：不在缩放时清空画布
        // 批注模式下允许用户随时用手指缩放，同时保持未提交的笔画
        // lineWidth 补偿会在 commit 时使用最新的 scaleFactor

        #if DEBUG
        print("[PencilKitContainer] Observers configured - architecture-compliant touch isolation")
        #endif
    }

    // MARK: - Annotation Mode

    /// 更新批注模式状态
    ///
    /// 架构合规性：
    /// - 只修改 isHidden 和 firstResponder 状态
    /// - 不修改 z-order（已在 init 时固定）
    /// - 只在用户显式操作时调用（非触摸事件流中）
    func updateAnnotationMode(_ isAnnotationMode: Bool) {
        if isAnnotationMode {
            // 进入批注模式
            // z-order 已在 setupCanvasView 中固定，无需再次调用 bringSubviewToFront
            viewModel.pencilKitController.enterAnnotationMode()
        } else {
            // 退出批注模式
            viewModel.pencilKitController.exitAnnotationMode()
        }

        #if DEBUG
        print("[PencilKitContainer] Annotation mode: \(isAnnotationMode), canvas hidden: \(canvasView.isHidden)")
        #endif
    }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview {
    Text("PDFAnnotationReaderView")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
