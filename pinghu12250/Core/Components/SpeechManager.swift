//
//  SpeechManager.swift
//  pinghu12250
//
//  语音朗读管理器 - 支持暂停/继续/变速/词句高亮
//

import Foundation
import AVFoundation
import Combine

/// 朗读状态
enum SpeechState: Equatable {
    case idle           // 空闲
    case playing        // 播放中
    case paused         // 已暂停
}

/// 语音朗读管理器
@MainActor
final class SpeechManager: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = SpeechManager()

    // MARK: - 发布属性
    @Published var state: SpeechState = .idle
    @Published var rate: Float = 1.0               // 语速 0.5 - 3.0
    @Published var currentRange: NSRange?          // 当前朗读的文本范围（用于高亮）
    @Published var progress: Double = 0            // 朗读进度 0-1

    // MARK: - 私有属性
    private let synthesizer = AVSpeechSynthesizer()
    private var currentText: String = ""
    private var totalCharacters: Int = 0

    // 速度预设
    static let ratePresets: [(label: String, value: Float)] = [
        ("0.5x", 0.5),
        ("0.75x", 0.75),
        ("1x", 1.0),
        ("1.25x", 1.25),
        ("1.5x", 1.5),
        ("2x", 2.0),
        ("2.5x", 2.5),
        ("3x", 3.0)
    ]

    // MARK: - 初始化
    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 公开方法

    /// 开始朗读
    func speak(_ text: String) {
        // 停止当前朗读
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        currentText = text
        totalCharacters = text.count
        currentRange = nil
        progress = 0

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectBestVoice()

        // 应用语速（AVSpeech 的 rate 范围是 0.0-1.0，默认约 0.5）
        // 将用户的 0.5-3.0 映射到 AVSpeech 的范围
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = baseRate * rate

        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        synthesizer.speak(utterance)
        state = .playing
    }

    /// 暂停朗读
    func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    /// 继续朗读
    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .playing
    }

    /// 停止朗读
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        currentRange = nil
        progress = 0
    }

    /// 切换播放/暂停
    func togglePlayPause() {
        switch state {
        case .idle:
            break // 需要先调用 speak
        case .playing:
            pause()
        case .paused:
            resume()
        }
    }

    /// 设置语速并重新应用（如果正在播放）
    func setRate(_ newRate: Float) {
        rate = max(0.5, min(3.0, newRate))
        // 注意：AVSpeechSynthesizer 不支持动态修改语速
        // 如果需要实时修改，需要停止并重新开始
    }

    /// 增加语速
    func increaseRate() {
        let currentIndex = Self.ratePresets.firstIndex { $0.value == rate } ?? 2
        if currentIndex < Self.ratePresets.count - 1 {
            rate = Self.ratePresets[currentIndex + 1].value
        }
    }

    /// 减少语速
    func decreaseRate() {
        let currentIndex = Self.ratePresets.firstIndex { $0.value == rate } ?? 2
        if currentIndex > 0 {
            rate = Self.ratePresets[currentIndex - 1].value
        }
    }

    /// 当前语速标签
    var rateLabel: String {
        Self.ratePresets.first { $0.value == rate }?.label ?? String(format: "%.1fx", rate)
    }

    // MARK: - 私有方法

    private func selectBestVoice() -> AVSpeechSynthesisVoice? {
        // 优先使用增强版中文语音
        let voiceIdentifiers = [
            "com.apple.voice.enhanced.zh-CN.Tingting",
            "com.apple.voice.premium.zh-CN.Tingting",
            "com.apple.ttsbundle.Ting-Ting-compact",
            "com.apple.voice.enhanced.zh-CN.Sinji",
            "com.apple.voice.premium.zh-CN.Sinji"
        ]

        for identifier in voiceIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        // 回退到默认中文语音
        return AVSpeechSynthesisVoice(language: "zh-CN")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .playing
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .idle
            self.currentRange = nil
            self.progress = 1.0
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .idle
            self.currentRange = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .paused
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .playing
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.currentRange = characterRange
            // 计算进度
            if self.totalCharacters > 0 {
                self.progress = Double(characterRange.location + characterRange.length) / Double(self.totalCharacters)
            }
        }
    }
}
