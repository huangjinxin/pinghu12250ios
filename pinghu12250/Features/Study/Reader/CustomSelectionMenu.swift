//
//  CustomSelectionMenu.swift
//  pinghu12250
//
//  自定义选择菜单 - 替代系统长按菜单
//  解决 iPad 长按与系统选择冲突的问题
//
//  功能：
//  - 单字/单词：查询（调用系统词典）
//  - 多字/句子：翻译（调用系统翻译）
//

import SwiftUI

// MARK: - 自定义选择菜单

struct CustomSelectionMenu: View {
    let position: CGPoint
    let selection: SelectionType
    let onDictionary: () -> Void
    let onSpeak: () -> Void
    let onBookmark: () -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var showDictionary = false
    @State private var showTranslation = false

    /// 获取选中的文本
    private var selectedText: String {
        if case .text(let text) = selection {
            return text
        }
        return ""
    }

    /// 判断是否为单词（用于决定显示查询还是翻译）
    private var isSingleWord: Bool {
        LocalDictionaryService.isSingleWord(selectedText)
    }

    var body: some View {
        GeometryReader { geometry in
            // 计算菜单位置，确保不超出屏幕
            let menuWidth: CGFloat = isSingleWord ? 280 : 350
            let menuHeight: CGFloat = 50
            let padding: CGFloat = 16

            let adjustedX = min(
                max(padding, position.x - menuWidth / 2),
                geometry.size.width - menuWidth - padding
            )
            let adjustedY = max(padding, position.y - menuHeight - 10)

            VStack(spacing: 0) {
                // 菜单内容
                HStack(spacing: 0) {
                    if isSingleWord {
                        // 单字/单词：显示查询
                        menuButton(icon: "character.book.closed", label: "查询", color: .blue) {
                            showDictionaryView()
                        }
                    } else {
                        // 多字/句子：显示翻译
                        menuButton(icon: "globe", label: "翻译", color: .green) {
                            showTranslationView()
                        }
                    }

                    menuDivider

                    menuButton(icon: "speaker.wave.2", label: "朗读", color: .orange) {
                        onSpeak()
                    }

                    menuDivider

                    menuButton(icon: "bookmark", label: "书签", color: .purple) {
                        onBookmark()
                    }

                    menuDivider

                    menuButton(icon: "doc.on.doc", label: "复制", color: .gray) {
                        onCopy()
                    }

                    // 如果不是单词，额外显示查询按钮（可选）
                    if !isSingleWord && !selectedText.isEmpty {
                        menuDivider
                        menuButton(icon: "character.book.closed", label: "查询", color: .blue) {
                            showDictionaryView()
                        }
                    }
                }
                .frame(height: menuHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                )

                // 箭头指示器
                MenuTriangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 16, height: 8)
                    .offset(x: position.x - adjustedX - menuWidth / 2)
            }
            .position(x: adjustedX + menuWidth / 2, y: adjustedY + menuHeight / 2)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isVisible = true
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            dismissMenu()
        }
        // 词典弹窗
        .dictionaryPopover(isPresented: $showDictionary, term: selectedText)
        // 翻译弹窗
        .sheet(isPresented: $showTranslation) {
            TranslationActionView(text: selectedText)
        }
    }

    // MARK: - 菜单按钮

    private func menuButton(icon: String, label: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 70, height: 50)
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 30)
    }

    private func dismissMenu() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - 词典和翻译

    private func showDictionaryView() {
        guard !selectedText.isEmpty else { return }
        // 先关闭菜单动画
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
        // 延迟显示词典
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            LocalDictionaryService.shared.showDefinition(for: selectedText)
            onDismiss()
        }
    }

    private func showTranslationView() {
        guard !selectedText.isEmpty else { return }
        showTranslation = true
    }
}

// MARK: - 三角形（菜单箭头）

private struct MenuTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - AI 辅助模式选择菜单（横屏使用）

struct AISelectionMenu: View {
    let position: CGPoint
    let selection: SelectionType
    let onAnalyze: () -> Void      // 解析
    let onPractice: () -> Void     // 练习
    let onSolving: () -> Void      // 解题
    let onSaveNote: () -> Void     // 保存笔记
    let onSpeak: () -> Void        // 朗读
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var showTranslation = false

    /// 获取选中的文本
    private var selectedText: String {
        if case .text(let text) = selection {
            return text
        }
        return ""
    }

    /// 判断是否为单词
    private var isSingleWord: Bool {
        LocalDictionaryService.isSingleWord(selectedText)
    }

    var body: some View {
        GeometryReader { geometry in
            let menuWidth: CGFloat = 432  // 增加宽度以容纳新按钮
            let menuHeight: CGFloat = 50
            let padding: CGFloat = 16

            let adjustedX = min(
                max(padding, position.x - menuWidth / 2),
                geometry.size.width - menuWidth - padding
            )
            let adjustedY = max(padding, position.y - menuHeight - 10)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // 查询/翻译按钮（根据选中内容智能显示）
                    if isSingleWord {
                        aiMenuButton(icon: "character.book.closed", label: "查询", color: .cyan) {
                            showDictionaryView()
                        }
                    } else {
                        aiMenuButton(icon: "globe", label: "翻译", color: .cyan) {
                            showTranslationView()
                        }
                    }

                    menuDivider

                    aiMenuButton(icon: "doc.text.magnifyingglass", label: "解析", color: .blue) {
                        onAnalyze()
                    }

                    menuDivider

                    aiMenuButton(icon: "checklist", label: "练习", color: .green) {
                        onPractice()
                    }

                    menuDivider

                    aiMenuButton(icon: "lightbulb", label: "解题", color: .orange) {
                        onSolving()
                    }

                    menuDivider

                    aiMenuButton(icon: "note.text", label: "笔记", color: .purple) {
                        onSaveNote()
                    }

                    menuDivider

                    aiMenuButton(icon: "speaker.wave.2", label: "朗读", color: .gray) {
                        onSpeak()
                    }
                }
                .frame(height: menuHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                )

                MenuTriangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 16, height: 8)
                    .offset(x: position.x - adjustedX - menuWidth / 2)
            }
            .position(x: adjustedX + menuWidth / 2, y: adjustedY + menuHeight / 2)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isVisible = true
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            dismissMenu()
        }
        // 翻译弹窗
        .sheet(isPresented: $showTranslation) {
            TranslationActionView(text: selectedText)
        }
    }

    private func aiMenuButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 72, height: 50)
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 30)
    }

    private func dismissMenu() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - 词典和翻译

    private func showDictionaryView() {
        guard !selectedText.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            LocalDictionaryService.shared.showDefinition(for: selectedText)
            onDismiss()
        }
    }

    private func showTranslationView() {
        guard !selectedText.isEmpty else { return }
        showTranslation = true
    }
}

// MARK: - 区域选择覆盖层（截图用）

struct RegionSelectionOverlay: View {
    @Binding var isActive: Bool
    let onCapture: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var isDragging = false

    private var selectionRect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // 选择区域（透明）
            if isDragging && selectionRect.width > 10 && selectionRect.height > 10 {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(
                        x: selectionRect.midX,
                        y: selectionRect.midY
                    )
                    .overlay(
                        Rectangle()
                            .stroke(Color.appPrimary, lineWidth: 2)
                    )
                    .background(
                        // 使用 blend mode 让选区透明
                        Rectangle()
                            .blendMode(.destinationOut)
                    )
            }

            // 提示文字
            VStack {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
                Spacer()

                if !isDragging {
                    Text("拖动选择区域")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }

                Spacer()

                if isDragging && selectionRect.width > 50 && selectionRect.height > 50 {
                    Button {
                        onCapture(selectionRect)
                        isActive = false
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("确认选择")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .compositingGroup()
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if !isDragging {
                        startPoint = value.startLocation
                        isDragging = true
                    }
                    currentPoint = value.location
                }
                .onEnded { _ in
                    // 保持选区显示
                }
        )
    }
}

// MARK: - 触摸点指示器

struct TouchIndicator: View {
    let position: CGPoint
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.appPrimary.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Circle()
                    .stroke(Color.appPrimary, lineWidth: 2)
            )
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.5 : 1.0)
            .position(position)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 预览

#Preview("纯阅读菜单") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        CustomSelectionMenu(
            position: CGPoint(x: 200, y: 300),
            selection: .text("测试文本"),
            onDictionary: {},
            onSpeak: {},
            onBookmark: {},
            onCopy: {},
            onDismiss: {}
        )
    }
}

#Preview("AI辅助菜单") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        AISelectionMenu(
            position: CGPoint(x: 200, y: 300),
            selection: .text("测试文本"),
            onAnalyze: {},
            onPractice: {},
            onSolving: {},
            onSaveNote: {},
            onSpeak: {},
            onDismiss: {}
        )
    }
}
