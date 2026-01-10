//
//  RegionSelectorOverlay.swift
//  pinghu12250
//
//  区域选择器覆盖层 - 支持手指/Apple Pencil 框选截图
//

import SwiftUI

// MARK: - 区域选择模式

enum RegionSelectionMode {
    case idle           // 空闲
    case selecting      // 正在选择
    case selected       // 已选择完成
    case adjusting      // 调整中
}

// MARK: - 区域选择覆盖层

struct RegionSelectorOverlay: View {
    @Binding var isSelecting: Bool
    @Binding var selectedRegion: CGRect?
    let onCapture: (UIImage) -> Void
    let getScreenshot: () -> UIImage?

    @State private var mode: RegionSelectionMode = .idle
    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var adjustHandle: AdjustHandle? = nil
    @State private var screenshot: UIImage?

    // 手柄类型
    enum AdjustHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明背景
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // 选择区域（透明窗口）
                if let region = calculatedRegion, region.width > 10, region.height > 10 {
                    // 遮罩层（选区外变暗）
                    maskLayer(geometry: geometry, region: region)

                    // 选区边框
                    selectionBorder(region: region)

                    // 调整手柄
                    if mode == .selected || mode == .adjusting {
                        adjustHandles(region: region)
                    }

                    // 操作按钮
                    if mode == .selected {
                        actionButtons(region: region, geometry: geometry)
                    }
                }

                // 提示文字
                if mode == .idle {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 60))
                            .foregroundColor(.white)

                        Text("拖动选择区域")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("用手指或 Apple Pencil 框选需要的内容")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // 取消按钮
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .gesture(dragGesture)
        }
        .onAppear {
            // 获取当前页面截图
            screenshot = getScreenshot()
        }
    }

    // MARK: - 计算选区

    private var calculatedRegion: CGRect? {
        guard mode != .idle else { return selectedRegion }

        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)

        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    // MARK: - 遮罩层

    private func maskLayer(geometry: GeometryProxy, region: CGRect) -> some View {
        Canvas { context, size in
            // 填充整个区域
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.5))
            )

            // 挖空选区
            context.blendMode = .destinationOut
            context.fill(
                Path(region),
                with: .color(.black)
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - 选区边框

    private func selectionBorder(region: CGRect) -> some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 2)
            .background(Color.clear)
            .frame(width: region.width, height: region.height)
            .position(x: region.midX, y: region.midY)
            .overlay(
                // 网格线
                GridLines()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.midY)
            )
    }

    // MARK: - 调整手柄

    private func adjustHandles(region: CGRect) -> some View {
        let handleSize: CGFloat = 20
        let handles: [(AdjustHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: region.minX, y: region.minY)),
            (.topRight, CGPoint(x: region.maxX, y: region.minY)),
            (.bottomLeft, CGPoint(x: region.minX, y: region.maxY)),
            (.bottomRight, CGPoint(x: region.maxX, y: region.maxY)),
        ]

        return ZStack {
            ForEach(handles, id: \.0.hashValue) { handle, point in
                Circle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(point)
            }
        }
    }

    // MARK: - 操作按钮

    private func actionButtons(region: CGRect, geometry: GeometryProxy) -> some View {
        let buttonY = region.maxY + 60 > geometry.size.height
            ? region.minY - 60
            : region.maxY + 30

        return HStack(spacing: 16) {
            actionButton(icon: "sparkles", label: "问AI解题", color: .purple) {
                captureAndSend(mode: .solve)
            }

            actionButton(icon: "pencil.and.list.clipboard", label: "生成练习", color: .blue) {
                captureAndSend(mode: .practice)
            }

            actionButton(icon: "note.text.badge.plus", label: "存笔记", color: .green) {
                captureAndSend(mode: .note)
            }
        }
        .position(x: region.midX, y: buttonY)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 70)
            .background(color.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 4)
        }
    }

    // MARK: - 拖动手势

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                switch mode {
                case .idle:
                    // 开始新选择
                    mode = .selecting
                    startPoint = value.startLocation
                    currentPoint = value.location

                case .selecting:
                    // 更新选择
                    currentPoint = value.location

                case .selected:
                    // 检查是否点击了手柄
                    if let region = calculatedRegion {
                        let handleRadius: CGFloat = 30
                        let corners: [(AdjustHandle, CGPoint)] = [
                            (.topLeft, CGPoint(x: region.minX, y: region.minY)),
                            (.topRight, CGPoint(x: region.maxX, y: region.minY)),
                            (.bottomLeft, CGPoint(x: region.minX, y: region.maxY)),
                            (.bottomRight, CGPoint(x: region.maxX, y: region.maxY)),
                        ]

                        for (handle, point) in corners {
                            if distance(from: value.startLocation, to: point) < handleRadius {
                                adjustHandle = handle
                                mode = .adjusting
                                break
                            }
                        }

                        if mode != .adjusting {
                            // 重新开始选择
                            mode = .selecting
                            startPoint = value.startLocation
                            currentPoint = value.location
                        }
                    }

                case .adjusting:
                    // 调整选区大小
                    adjustRegion(to: value.location)
                }
            }
            .onEnded { _ in
                if mode == .selecting {
                    if let region = calculatedRegion, region.width > 30, region.height > 30 {
                        mode = .selected
                        selectedRegion = region
                    } else {
                        mode = .idle
                    }
                } else if mode == .adjusting {
                    mode = .selected
                    selectedRegion = calculatedRegion
                    adjustHandle = nil
                }
            }
    }

    // MARK: - 辅助方法

    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }

    private func adjustRegion(to point: CGPoint) {
        guard let handle = adjustHandle else { return }

        switch handle {
        case .topLeft:
            startPoint = point
        case .topRight:
            startPoint.y = point.y
            currentPoint.x = point.x
        case .bottomLeft:
            startPoint.x = point.x
            currentPoint.y = point.y
        case .bottomRight:
            currentPoint = point
        default:
            break
        }
    }

    private func captureAndSend(mode: CaptureMode) {
        guard let region = selectedRegion,
              let fullImage = screenshot else { return }

        // 将选区裁剪为图片
        let scale = UIScreen.main.scale
        let scaledRect = CGRect(
            x: region.origin.x * scale,
            y: region.origin.y * scale,
            width: region.width * scale,
            height: region.height * scale
        )

        if let cgImage = fullImage.cgImage?.cropping(to: scaledRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: scale, orientation: fullImage.imageOrientation)
            onCapture(croppedImage)
        }

        dismiss()
    }

    private func dismiss() {
        isSelecting = false
        selectedRegion = nil
        mode = .idle
    }

    enum CaptureMode {
        case solve      // 解题
        case practice   // 练习
        case note       // 笔记
    }
}

// MARK: - 网格线

struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 三等分线
        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3

        // 垂直线
        path.move(to: CGPoint(x: thirdWidth, y: 0))
        path.addLine(to: CGPoint(x: thirdWidth, y: rect.height))

        path.move(to: CGPoint(x: thirdWidth * 2, y: 0))
        path.addLine(to: CGPoint(x: thirdWidth * 2, y: rect.height))

        // 水平线
        path.move(to: CGPoint(x: 0, y: thirdHeight))
        path.addLine(to: CGPoint(x: rect.width, y: thirdHeight))

        path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
        path.addLine(to: CGPoint(x: rect.width, y: thirdHeight * 2))

        return path
    }
}

// MARK: - 预览

#Preview {
    RegionSelectorOverlay(
        isSelecting: .constant(true),
        selectedRegion: .constant(CGRect(x: 50, y: 100, width: 200, height: 150)),
        onCapture: { _ in },
        getScreenshot: { nil }
    )
}
