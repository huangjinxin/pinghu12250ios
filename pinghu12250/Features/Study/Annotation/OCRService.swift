//
//  OCRService.swift
//  pinghu12250
//
//  OCR 识别服务 - 基于 Vision 框架识别手写文字
//

import Foundation
import Vision
import UIKit
import PencilKit

/// OCR 识别服务（基于 Vision 框架）
class OCRService {
    static let shared = OCRService()

    private init() {}

    // MARK: - Public Methods

    /// 从图片识别文字
    /// - Parameter image: 要识别的图片
    /// - Returns: 识别出的文字，如果识别失败返回 nil
    func recognizeText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            performRecognition(cgImage: cgImage) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// 从 PKDrawing 识别文字
    /// - Parameter drawing: PencilKit 绘图对象
    /// - Returns: 识别出的文字
    func recognizeText(from drawing: PKDrawing) async -> String? {
        guard !drawing.strokes.isEmpty else { return nil }

        // 获取绘图边界并添加边距
        let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        guard bounds.width > 0 && bounds.height > 0 else { return nil }

        // 渲染为图片（2x 分辨率提高识别准确度）
        let image = drawing.image(from: bounds, scale: 2.0)
        return await recognizeText(from: image)
    }

    /// 批量识别多张图片
    /// - Parameter images: 图片数组
    /// - Returns: 识别结果数组（与输入顺序对应）
    func recognizeTextBatch(from images: [UIImage]) async -> [String?] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let text = await self.recognizeText(from: image)
                    return (index, text)
                }
            }

            var results = Array<String?>(repeating: nil, count: images.count)
            for await (index, text) in group {
                results[index] = text
            }
            return results
        }
    }

    // MARK: - Private Methods

    private func performRecognition(cgImage: CGImage, completion: @escaping (String?) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }

            // 提取识别结果
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            let fullText = recognizedStrings.joined(separator: "\n")
            completion(fullText.isEmpty ? nil : fullText)
        }

        // 配置识别选项
        request.recognitionLevel = .accurate  // 使用精确模式
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]  // 支持简繁中文和英文
        request.usesLanguageCorrection = true  // 启用语言校正

        // 执行识别
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                #if DEBUG
                print("[OCR] Recognition failed: \(error.localizedDescription)")
                #endif
                completion(nil)
            }
        }
    }
}
