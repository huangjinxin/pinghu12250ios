//
//  HandwritingRecognizer.swift
//  pinghu12250
//
//  手写识别服务 - 使用 Vision 框架识别手写文字
//

import Foundation
import Vision
import UIKit
import Combine

// MARK: - 手写识别服务

class HandwritingRecognizer {
    static let shared = HandwritingRecognizer()

    private init() {}

    // MARK: - 识别手写文字

    /// 识别图片中的手写文字
    func recognize(image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }

        return await withCheckedContinuation { continuation in
            recognizeText(in: cgImage) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// 识别图片中的手写文字（带详细结果）
    func recognizeWithDetails(image: UIImage) async -> [RecognizedTextBlock] {
        guard let cgImage = image.cgImage else {
            return []
        }

        return await withCheckedContinuation { continuation in
            recognizeTextBlocks(in: cgImage) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Vision 识别

    private func recognizeText(in cgImage: CGImage, completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                #if DEBUG
                print("文字识别错误: \(error!.localizedDescription)")
                #endif
                completion("")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }

            // 合并所有识别结果
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            completion(recognizedText)
        }

        // 配置识别选项
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
        request.usesLanguageCorrection = true

        // 执行识别
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            #if DEBUG
            print("执行识别请求失败: \(error)")
            #endif
            completion("")
        }
    }

    private func recognizeTextBlocks(in cgImage: CGImage, completion: @escaping ([RecognizedTextBlock]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                #if DEBUG
                print("文字识别错误: \(error!.localizedDescription)")
                #endif
                completion([])
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }

            let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                guard let topCandidate = observation.topCandidates(1).first else {
                    return nil
                }

                // 转换边界框坐标
                let boundingBox = observation.boundingBox

                return RecognizedTextBlock(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: boundingBox
                )
            }

            completion(blocks)
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            #if DEBUG
            print("执行识别请求失败: \(error)")
            #endif
            completion([])
        }
    }

    // MARK: - 实时识别（用于 Apple Pencil）

    /// 创建实时识别请求
    func createRealtimeRequest(
        onProgress: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            let text = observations.compactMap {
                $0.topCandidates(1).first?.string
            }.joined(separator: " ")

            DispatchQueue.main.async {
                onProgress(text)
            }
        }

        request.recognitionLevel = .fast // 实时模式使用快速识别
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
        request.usesLanguageCorrection = false // 实时模式关闭语言校正以提高速度

        return request
    }
}

// MARK: - 识别结果模型

struct RecognizedTextBlock: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect // 归一化坐标 (0-1)

    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

// MARK: - 手写笔画分析

class StrokeAnalyzer {
    /// 分析笔画是否为文字（而非涂鸦）
    static func isLikelyText(strokes: [PKStroke]) -> Bool {
        guard !strokes.isEmpty else { return false }

        // 简单启发式：检查笔画密度和分布
        let bounds = strokes.reduce(CGRect.null) { result, stroke in
            result.union(stroke.renderBounds)
        }

        let strokeDensity = CGFloat(strokes.count) / bounds.area
        let averageStrokeLength = strokes.reduce(0.0) { result, stroke in
            result + stroke.renderBounds.diagonal
        } / CGFloat(strokes.count)

        // 文字通常有适中的笔画密度和长度
        return strokeDensity > 0.001 && averageStrokeLength < 200
    }

    /// 将笔画分组为可能的字符
    static func groupStrokesIntoCharacters(strokes: [PKStroke]) -> [[PKStroke]] {
        guard !strokes.isEmpty else { return [] }

        var groups: [[PKStroke]] = []
        var currentGroup: [PKStroke] = []
        var lastEndPoint: CGPoint?

        for stroke in strokes {
            let startPoint = stroke.path.interpolatedLocation(at: 0)

            if let lastEnd = lastEndPoint {
                let distance = startPoint.distance(to: lastEnd)

                // 如果距离较大，开始新的字符组
                if distance > 50 && !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                }
            }

            currentGroup.append(stroke)
            lastEndPoint = stroke.path.interpolatedLocation(at: CGFloat(stroke.path.count - 1))
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }
}

// MARK: - 扩展

import PencilKit

extension CGRect {
    var area: CGFloat {
        width * height
    }

    var diagonal: CGFloat {
        sqrt(width * width + height * height)
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

extension PKStroke {
    var bounds: CGRect {
        renderBounds
    }
}

// MARK: - 手写输入缓冲区

class HandwritingBuffer: ObservableObject {
    @Published var strokes: [PKStroke] = []
    @Published var recognizedText = ""
    @Published var isRecognizing = false

    private var recognitionTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 1.0 // 停笔1秒后识别

    /// 添加笔画
    func addStroke(_ stroke: PKStroke) {
        strokes.append(stroke)
        scheduleRecognition()
    }

    /// 更新绘图
    func updateDrawing(_ drawing: PKDrawing) {
        strokes = drawing.strokes
        scheduleRecognition()
    }

    /// 清除
    func clear() {
        strokes.removeAll()
        recognizedText = ""
        recognitionTask?.cancel()
    }

    /// 调度识别（防抖）
    private func scheduleRecognition() {
        recognitionTask?.cancel()

        recognitionTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            if !Task.isCancelled && !strokes.isEmpty {
                await performRecognition()
            }
        }
    }

    /// 执行识别
    private func performRecognition() async {
        await MainActor.run {
            isRecognizing = true
        }

        // 将笔画渲染为图片
        let drawing = PKDrawing(strokes: strokes)
        let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        let image = drawing.image(from: bounds, scale: 2.0)

        // 识别
        let text = await HandwritingRecognizer.shared.recognize(image: image)

        await MainActor.run {
            recognizedText = text
            isRecognizing = false
        }
    }
}
