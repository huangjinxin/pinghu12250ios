//
//  StrokeRendererView.swift
//  pinghu12250
//
//  笔画渲染视图
//  用于展示草稿和书写练习的笔画内容
//  支持回放动画
//

import SwiftUI

/// 笔画渲染视图
struct StrokeRendererView: View {
    /// 笔画数据（JSON字符串或StrokeData对象）
    let content: Any?
    /// 最大宽度
    var maxWidth: CGFloat = 300
    /// 最大高度
    var maxHeight: CGFloat = 300
    /// 背景色
    var backgroundColor: Color = Color(hex: "FDF5E6")
    /// 是否显示回放按钮
    var showPlayback: Bool = false

    @State private var strokeData: StrokeData?
    @State private var isPlaying = false
    @State private var visibleStrokeCount = 0
    @State private var playbackTimer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            // 画布
            ZStack {
                // 背景
                Rectangle()
                    .fill(backgroundColor)

                // 笔画渲染
                if let data = strokeData, !data.strokes.isEmpty {
                    Canvas { context, size in
                        drawStrokes(context: context, size: size, strokeData: data)
                    }
                } else {
                    // 空状态提示
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .frame(width: renderSize.width, height: renderSize.height)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // 回放控制
            if showPlayback && strokeData != nil && !strokeData!.strokes.isEmpty {
                HStack(spacing: 16) {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appPrimary)
                    }

                    Button {
                        resetPlayback()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Text("\(visibleStrokeCount)/\(strokeData?.strokes.count ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            parseContent()
            // 初始化时显示所有笔画（非回放模式）或准备回放
            DispatchQueue.main.async {
                if !showPlayback {
                    visibleStrokeCount = strokeData?.strokes.count ?? 0
                } else {
                    // 回放模式：初始显示所有笔画，点击播放时重置
                    visibleStrokeCount = strokeData?.strokes.count ?? 0
                }
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    /// 计算渲染尺寸
    private var renderSize: CGSize {
        guard let data = strokeData else {
            return CGSize(width: maxWidth, height: maxHeight)
        }

        let canvasWidth = data.canvas.width
        let canvasHeight = data.canvas.height

        let scaleX = maxWidth / canvasWidth
        let scaleY = maxHeight / canvasHeight
        let scale = min(scaleX, scaleY, 1)

        return CGSize(
            width: canvasWidth * scale,
            height: canvasHeight * scale
        )
    }

    /// 解析内容
    private func parseContent() {
        if let data = content as? StrokeData {
            strokeData = data
            return
        }

        if let json = content as? String {
            strokeData = StrokeData.fromJSON(json)
            return
        }

        if let dict = content as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: jsonData, encoding: .utf8) {
            strokeData = StrokeData.fromJSON(json)
        }
    }

    /// 绘制笔画
    private func drawStrokes(context: GraphicsContext, size: CGSize, strokeData: StrokeData) {
        let canvasWidth = strokeData.canvas.width
        let canvasHeight = strokeData.canvas.height

        let scaleX = size.width / canvasWidth
        let scaleY = size.height / canvasHeight
        let scale = min(scaleX, scaleY)

        // 只绘制可见的笔画
        let strokesToRender = Array(strokeData.strokes.prefix(visibleStrokeCount))

        for stroke in strokesToRender {
            guard stroke.points.count >= 2 else { continue }

            var path = Path()
            let firstPoint = stroke.points[0]
            path.move(to: CGPoint(
                x: firstPoint.x * scale,
                y: firstPoint.y * scale
            ))

            for i in 1..<stroke.points.count {
                let point = stroke.points[i]
                path.addLine(to: CGPoint(
                    x: point.x * scale,
                    y: point.y * scale
                ))
            }

            context.stroke(
                path,
                with: .color(Color(hex: stroke.color.replacingOccurrences(of: "#", with: ""))),
                style: StrokeStyle(
                    lineWidth: stroke.lineWidth * scale,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    /// 切换回放
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    /// 开始回放
    private func startPlayback() {
        guard let data = strokeData, !data.strokes.isEmpty else { return }

        isPlaying = true

        // 每次点击播放都从头开始
        visibleStrokeCount = 0

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if visibleStrokeCount < data.strokes.count {
                withAnimation(.easeInOut(duration: 0.15)) {
                    visibleStrokeCount += 1
                }
            } else {
                stopPlayback()
            }
        }
    }

    /// 停止回放
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// 重置回放
    private func resetPlayback() {
        stopPlayback()
        visibleStrokeCount = 0
    }
}

// MARK: - 草稿预览视图

/// 草稿预览缩略图
struct DrawingPreviewView: View {
    /// 笔记内容
    let content: Any?
    /// 预览尺寸
    var size: CGFloat = 80

    @State private var previewImage: UIImage?

    var body: some View {
        ZStack {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "scribble")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .onAppear {
            loadPreview()
        }
    }

    private func loadPreview() {
        // 尝试从content中获取预览图
        var previewBase64: String?

        if let dict = content as? [String: Any] {
            previewBase64 = dict["preview"] as? String
        } else if let json = content as? String,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            previewBase64 = dict["preview"] as? String
        }

        if let base64 = previewBase64 {
            let cleanBase64 = base64
                .replacingOccurrences(of: "data:image/png;base64,", with: "")
                .replacingOccurrences(of: "data:image/webp;base64,", with: "")
                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")

            if let imageData = Data(base64Encoded: cleanBase64),
               let image = UIImage(data: imageData) {
                previewImage = image
            }
        }
    }
}

// MARK: - 预览

#Preview("笔画渲染") {
    let sampleStrokeData = StrokeData(
        version: 2,
        canvas: StrokeData.CanvasSize(width: 300, height: 300, dpr: 2),
        strokes: [
            StrokeData.Stroke(
                id: "stroke_1",
                color: "#333333",
                lineWidth: 4,
                points: [
                    StrokeData.Point(x: 50, y: 150, t: 1000),
                    StrokeData.Point(x: 150, y: 150, t: 1100),
                    StrokeData.Point(x: 250, y: 150, t: 1200)
                ]
            ),
            StrokeData.Stroke(
                id: "stroke_2",
                color: "#333333",
                lineWidth: 4,
                points: [
                    StrokeData.Point(x: 150, y: 50, t: 2000),
                    StrokeData.Point(x: 150, y: 150, t: 2100),
                    StrokeData.Point(x: 150, y: 250, t: 2200)
                ]
            )
        ]
    )

    return VStack {
        StrokeRendererView(
            content: sampleStrokeData,
            maxWidth: 200,
            maxHeight: 200,
            showPlayback: true
        )
    }
    .padding()
}
