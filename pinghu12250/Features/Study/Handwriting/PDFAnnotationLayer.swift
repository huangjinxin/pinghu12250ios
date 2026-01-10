//
//  PDFAnnotationLayer.swift
//  pinghu12250
//
//  PDF 标注层 - 在 PDF 上添加手写标注
//

import SwiftUI
import PencilKit
import PDFKit
import Combine

// MARK: - 标注模式

enum AnnotationMode {
    case none       // 无标注（正常阅读）
    case drawing    // 自由绘制
    case highlight  // 荧光笔
    case underline  // 下划线
    case text       // 文字标注
}

// MARK: - 页面标注数据

struct PageAnnotation: Codable, Identifiable {
    let id: UUID
    let pageIndex: Int
    var drawingData: Data?  // PKDrawing 序列化数据
    var textAnnotations: [TextAnnotation]
    var updatedAt: Date

    init(pageIndex: Int) {
        self.id = UUID()
        self.pageIndex = pageIndex
        self.drawingData = nil
        self.textAnnotations = []
        self.updatedAt = Date()
    }

    var drawing: PKDrawing? {
        get {
            guard let data = drawingData else { return nil }
            return try? PKDrawing(data: data)
        }
        set {
            drawingData = newValue?.dataRepresentation()
            updatedAt = Date()
        }
    }
}

struct TextAnnotation: Codable, Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint
    var color: String  // 颜色名称
    var fontSize: CGFloat

    init(text: String, position: CGPoint, color: String = "yellow", fontSize: CGFloat = 14) {
        self.id = UUID()
        self.text = text
        self.position = position
        self.color = color
        self.fontSize = fontSize
    }
}

// MARK: - PDF 标注层视图

struct PDFAnnotationLayer: View {
    let pageSize: CGSize
    let pageIndex: Int
    @Binding var annotation: PageAnnotation
    @Binding var annotationMode: AnnotationMode
    @Binding var selectedColor: CanvasColor
    @Binding var lineWidth: CGFloat

    @AppStorage("pencilOnlyMode") private var pencilOnlyMode = false

    @State private var canvasView = PKCanvasView()
    @State private var drawing: PKDrawing

    init(
        pageSize: CGSize,
        pageIndex: Int,
        annotation: Binding<PageAnnotation>,
        annotationMode: Binding<AnnotationMode>,
        selectedColor: Binding<CanvasColor>,
        lineWidth: Binding<CGFloat>
    ) {
        self.pageSize = pageSize
        self.pageIndex = pageIndex
        self._annotation = annotation
        self._annotationMode = annotationMode
        self._selectedColor = selectedColor
        self._lineWidth = lineWidth
        self._drawing = State(initialValue: annotation.wrappedValue.drawing ?? PKDrawing())
    }

    var body: some View {
        ZStack {
            // 绘图层
            if annotationMode != .none {
                PencilKitCanvas(
                    canvasView: $canvasView,
                    drawing: $drawing,
                    tool: currentTool,
                    color: selectedColor.color,
                    lineWidth: lineWidth,
                    backgroundColor: .clear,
                    allowsFingerDrawing: !pencilOnlyMode,
                    onDrawingChanged: { newDrawing in
                        annotation.drawing = newDrawing
                    }
                )
                .allowsHitTesting(annotationMode != .none)
            } else {
                // 只显示已有标注（只读）
                if let existingDrawing = annotation.drawing {
                    DrawingView(drawing: existingDrawing)
                }
            }

            // 文字标注
            ForEach(annotation.textAnnotations) { textAnnotation in
                TextAnnotationView(annotation: textAnnotation)
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .onChange(of: annotation.drawing) { oldDrawing, newDrawing in
            if let newDrawing = newDrawing, drawing != newDrawing {
                drawing = newDrawing
            }
        }
    }

    private var currentTool: CanvasTool {
        switch annotationMode {
        case .highlight:
            return .marker
        case .drawing, .underline:
            return .pen
        default:
            return .pen
        }
    }
}

// MARK: - 只读绘图视图

struct DrawingView: UIViewRepresentable {
    let drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.isUserInteractionEnabled = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
}

// MARK: - 文字标注视图

struct TextAnnotationView: View {
    let annotation: TextAnnotation

    var body: some View {
        Text(annotation.text)
            .font(.system(size: annotation.fontSize))
            .foregroundColor(annotationColor)
            .padding(4)
            .background(annotationColor.opacity(0.2))
            .cornerRadius(4)
            .position(annotation.position)
    }

    private var annotationColor: Color {
        switch annotation.color {
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        default: return .yellow
        }
    }
}

// MARK: - 标注管理器

class AnnotationManager: ObservableObject {
    @Published var annotations: [Int: PageAnnotation] = [:]  // pageIndex: annotation

    private let textbookId: String
    private let storageKey: String

    init(textbookId: String) {
        self.textbookId = textbookId
        self.storageKey = "pdf_annotations_\(textbookId)"
        loadAnnotations()
    }

    // MARK: - 获取/创建标注

    func getAnnotation(for pageIndex: Int) -> PageAnnotation {
        if let existing = annotations[pageIndex] {
            return existing
        }
        let newAnnotation = PageAnnotation(pageIndex: pageIndex)
        annotations[pageIndex] = newAnnotation
        return newAnnotation
    }

    func updateAnnotation(_ annotation: PageAnnotation) {
        annotations[annotation.pageIndex] = annotation
        saveAnnotations()
    }

    // MARK: - 清除标注

    func clearAnnotation(for pageIndex: Int) {
        annotations[pageIndex] = PageAnnotation(pageIndex: pageIndex)
        saveAnnotations()
    }

    func clearAllAnnotations() {
        annotations.removeAll()
        saveAnnotations()
    }

    // MARK: - 持久化

    private func loadAnnotations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Int: PageAnnotation].self, from: data) else {
            return
        }
        annotations = decoded
    }

    private func saveAnnotations() {
        guard let data = try? JSONEncoder().encode(annotations) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - 导出

    func exportAnnotatedPage(pdfDocument: PDFDocument, pageIndex: Int) -> UIImage? {
        guard let page = pdfDocument.page(at: pageIndex) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        let annotation = getAnnotation(for: pageIndex)

        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { context in
            // 绘制 PDF 页面
            UIColor.white.setFill()
            context.fill(pageRect)

            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)

            // 恢复坐标系
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.translateBy(x: 0, y: -pageRect.height)

            // 绘制标注
            if let drawing = annotation.drawing {
                let drawingImage = drawing.image(from: pageRect, scale: 1.0)
                drawingImage.draw(in: pageRect)
            }
        }
    }
}

// MARK: - 标注工具栏

struct AnnotationToolbar: View {
    @Binding var annotationMode: AnnotationMode
    @Binding var selectedColor: CanvasColor
    @Binding var lineWidth: CGFloat
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 模式选择
            ForEach(annotationModes, id: \.self) { mode in
                modeButton(mode)
            }

            Divider()
                .frame(height: 28)

            // 颜色选择
            ForEach(CanvasColor.presets.prefix(4)) { color in
                colorButton(color)
            }

            Divider()
                .frame(height: 28)

            // 线宽（使用 SafeSlider）
            SafeSlider(value: $lineWidth, in: 1...10, step: 1)
                .frame(width: 80)

            Spacer()

            // 操作按钮
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }

            Button(action: onClear) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }

            Divider()
                .frame(height: 28)

            Button("完成", action: onDone)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }

    private var annotationModes: [AnnotationMode] {
        [.drawing, .highlight, .underline]
    }

    private func modeButton(_ mode: AnnotationMode) -> some View {
        Button {
            annotationMode = mode
        } label: {
            Image(systemName: modeIcon(mode))
                .font(.system(size: 18))
                .foregroundColor(annotationMode == mode ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(annotationMode == mode ? Color.appPrimary : Color(.systemGray5))
                .cornerRadius(8)
        }
    }

    private func modeIcon(_ mode: AnnotationMode) -> String {
        switch mode {
        case .none: return "hand.point.up"
        case .drawing: return "pencil.tip"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .text: return "textformat"
        }
    }

    private func colorButton(_ color: CanvasColor) -> some View {
        Button {
            selectedColor = color
        } label: {
            Circle()
                .fill(Color(color.color))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(
                            selectedColor.id == color.id ? Color.appPrimary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        AnnotationToolbar(
            annotationMode: .constant(.drawing),
            selectedColor: .constant(CanvasColor.presets[0]),
            lineWidth: .constant(3),
            onUndo: {},
            onRedo: {},
            onClear: {},
            onDone: {}
        )

        Spacer()
    }
}
