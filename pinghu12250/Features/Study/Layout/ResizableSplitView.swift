//
//  ResizableSplitView.swift
//  pinghu12250
//
//  可调整分屏视图 - 支持横屏分屏布局和拖拽调整
//  优化：使用 GestureState 防止拖拽过程中跳动
//

import SwiftUI
import Combine

// MARK: - 可调整分屏视图

struct ResizableSplitView<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    @Binding var splitRatio: CGFloat

    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0  // 拖拽偏移量

    init(
        splitRatio: Binding<CGFloat>,
        minLeadingWidth: CGFloat = 200,
        minTrailingWidth: CGFloat = 250,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._splitRatio = splitRatio
        self.minLeadingWidth = minLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dividerWidth: CGFloat = 12
            let availableWidth = totalWidth - dividerWidth

            // 计算当前显示的比例（基础比例 + 拖拽偏移）
            let displayRatio = clampRatio(
                splitRatio + (dragOffset / totalWidth),
                totalWidth: totalWidth
            )

            HStack(spacing: 0) {
                // 左侧内容（PDF阅读器）
                leading
                    .frame(width: availableWidth * displayRatio)

                // 分隔条
                SplitDivider(isDragging: $isDragging)
                    .frame(width: dividerWidth)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                                DispatchQueue.main.async {
                                    isDragging = true
                                }
                            }
                            .onEnded { value in
                                // 只在拖拽结束时更新实际比例
                                let finalRatio = clampRatio(
                                    splitRatio + (value.translation.width / totalWidth),
                                    totalWidth: totalWidth
                                )
                                splitRatio = finalRatio
                                isDragging = false
                            }
                    )

                // 右侧内容（AI面板）
                trailing
                    .frame(width: availableWidth * (1 - displayRatio))
            }
        }
    }

    private func clampRatio(_ ratio: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let minLeadingRatio = minLeadingWidth / totalWidth
        let maxLeadingRatio = (totalWidth - minTrailingWidth) / totalWidth
        return min(max(ratio, minLeadingRatio), maxLeadingRatio)
    }
}

// MARK: - 分隔条

struct SplitDivider: View {
    @Binding var isDragging: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))

            // 拖拽手柄
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isDragging ? Color.appPrimary : Color(.systemGray3))
                        .frame(width: 4, height: 16)
                }
            }
        }
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - 横屏布局管理器

class LandscapeLayoutManager: ObservableObject {
    @Published var splitRatio: CGFloat = 0.55
    @Published var isPanelVisible: Bool = true
    @Published var isPanelMinimized: Bool = false

    private let defaultRatio: CGFloat = 0.55
    private let minimizedRatio: CGFloat = 0.85

    // 预设布局
    enum LayoutPreset: String, CaseIterable {
        case balanced = "平衡"
        case focusReading = "专注阅读"
        case focusPanel = "专注面板"

        var ratio: CGFloat {
            switch self {
            case .balanced: return 0.55
            case .focusReading: return 0.7
            case .focusPanel: return 0.4
            }
        }

        var icon: String {
            switch self {
            case .balanced: return "square.split.2x1"
            case .focusReading: return "book"
            case .focusPanel: return "bubble.left.and.bubble.right"
            }
        }
    }

    func applyPreset(_ preset: LayoutPreset) {
        withAnimation(.easeInOut(duration: 0.3)) {
            splitRatio = preset.ratio
            isPanelVisible = true
            isPanelMinimized = false
        }
    }

    func togglePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if isPanelMinimized {
                splitRatio = defaultRatio
                isPanelMinimized = false
            } else {
                splitRatio = minimizedRatio
                isPanelMinimized = true
            }
        }
    }

    func hidePanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPanelVisible = false
        }
    }

    func showPanel() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPanelVisible = true
            isPanelMinimized = false
            splitRatio = defaultRatio
        }
    }
}

// MARK: - 横屏布局预设选择器

struct LayoutPresetPicker: View {
    @ObservedObject var layoutManager: LandscapeLayoutManager

    var body: some View {
        Menu {
            ForEach(LandscapeLayoutManager.LayoutPreset.allCases, id: \.self) { preset in
                Button {
                    layoutManager.applyPreset(preset)
                } label: {
                    Label(preset.rawValue, systemImage: preset.icon)
                }
            }

            Divider()

            Button {
                layoutManager.togglePanel()
            } label: {
                Label(
                    layoutManager.isPanelMinimized ? "展开面板" : "收起面板",
                    systemImage: layoutManager.isPanelMinimized ? "arrow.left.to.line" : "arrow.right.to.line"
                )
            }
        } label: {
            Image(systemName: "sidebar.right")
                .font(.title3)
                .foregroundColor(.appPrimary)
        }
    }
}

// MARK: - 自适应布局容器

struct AdaptiveLayoutView<Portrait: View, Landscape: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    let portrait: Portrait
    let landscape: Landscape

    init(
        @ViewBuilder portrait: () -> Portrait,
        @ViewBuilder landscape: () -> Landscape
    ) {
        self.portrait = portrait()
        self.landscape = landscape()
    }

    var body: some View {
        Group {
            if isLandscape {
                landscape
            } else {
                portrait
            }
        }
    }

    private var isLandscape: Bool {
        // iPad 横屏或大屏设备
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return true
        }
        // iPad 横屏（两边都是 regular）
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            // 检测设备方向
            return UIScreen.main.bounds.width > UIScreen.main.bounds.height
        }
        return false
    }
}

// MARK: - 预览

#Preview("ResizableSplitView") {
    ResizableSplitView(
        splitRatio: .constant(0.55),
        leading: {
            Color.blue.opacity(0.3)
                .overlay(Text("PDF 阅读区"))
        },
        trailing: {
            Color.green.opacity(0.3)
                .overlay(Text("AI 面板区"))
        }
    )
}
