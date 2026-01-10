//
//  DismissibleCover.swift
//  pinghu12250
//
//  可下拉关闭的全屏覆盖包装器
//

import SwiftUI

/// 可下拉关闭的全屏内容包装器
struct DismissibleCover<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: Content
    let showCloseButton: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let dismissThreshold: CGFloat = 150

    init(showCloseButton: Bool = false, @ViewBuilder content: () -> Content) {
        self.showCloseButton = showCloseButton
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .offset(y: max(0, dragOffset))
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)

            // 关闭按钮
            if showCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                }
                .padding()
            }

            // 下拉提示指示器
            VStack {
                if isDragging && dragOffset > 20 {
                    Text("下拉关闭")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer()
            }
            .padding(.top, 60)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 只响应向下拖动
                    if value.translation.height > 0 {
                        isDragging = true
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    if value.translation.height > dismissThreshold {
                        dismiss()
                    } else {
                        dragOffset = 0
                    }
                }
        )
        .background(Color(.systemBackground))
    }
}

/// 视图修饰器：添加下拉关闭功能
struct DismissibleModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 150

    func body(content: Content) -> some View {
        content
            .offset(y: max(0, dragOffset))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            dismiss()
                        } else {
                            dragOffset = 0
                        }
                    }
            )
    }
}

extension View {
    /// 添加下拉关闭手势
    func dismissibleByDrag() -> some View {
        modifier(DismissibleModifier())
    }
}

// MARK: - 预览

#Preview {
    DismissibleCover {
        VStack {
            Text("全屏内容")
                .font(.largeTitle)
            Text("向下拖动可关闭")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.1))
    }
}
