//
//  SpeechPlayerView.swift
//  pinghu12250
//
//  朗读播放器组件 - 支持整篇内容朗读、暂停、继续
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 朗读服务

@MainActor
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var progress: Double = 0
    @Published var currentText: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var totalLength: Int = 0
    private var spokenLength: Int = 0

    override init() {
        super.init()
        synthesizer.delegate = self

        // 配置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }

    /// 开始朗读
    func speak(_ text: String) {
        stop()

        currentText = text
        totalLength = text.count
        spokenLength = 0
        progress = 0

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9  // 稍慢一点，适合儿童
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("激活音频会话失败: \(error)")
        }

        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }

    /// 暂停朗读
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
            isPlaying = false
        }
    }

    /// 继续朗读
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isPlaying = true
        }
    }

    /// 停止朗读
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        progress = 0
        spokenLength = 0
    }

    /// 切换播放/暂停
    func toggle() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
            isPaused = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
            isPaused = false
            progress = 1.0
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
            isPaused = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
            isPaused = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            spokenLength = characterRange.location + characterRange.length
            if totalLength > 0 {
                progress = Double(spokenLength) / Double(totalLength)
            }
        }
    }
}

// MARK: - 朗读播放器视图

struct SpeechPlayerView: View {
    let text: String
    let title: String

    @StateObject private var speechService = SpeechService.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 主控制栏
            HStack(spacing: 16) {
                // 播放/暂停按钮
                Button {
                    if speechService.isPlaying {
                        speechService.pause()
                    } else if speechService.isPaused {
                        speechService.resume()
                    } else {
                        speechService.speak(text)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 44, height: 44)

                        Image(systemName: playButtonIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                // 信息和进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.appPrimary)

                        Text(statusText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if isActive {
                            Text(progressText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }

                    // 进度条
                    if isActive {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(Color.appPrimary)
                                    .frame(width: geometry.size.width * speechService.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    } else {
                        Text("点击播放按钮开始朗读")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 停止按钮
                if isActive {
                    Button {
                        speechService.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .onDisappear {
            // 离开页面时停止朗读
            if speechService.currentText == text {
                speechService.stop()
            }
        }
    }

    // MARK: - 计算属性

    private var isActive: Bool {
        speechService.isPlaying || speechService.isPaused
    }

    private var playButtonIcon: String {
        if speechService.isPlaying {
            return "pause.fill"
        } else if speechService.isPaused {
            return "play.fill"
        } else {
            return "play.fill"
        }
    }

    private var statusText: String {
        if speechService.isPlaying {
            return "正在朗读..."
        } else if speechService.isPaused {
            return "已暂停"
        } else {
            return "朗读全文"
        }
    }

    private var progressText: String {
        let percent = Int(speechService.progress * 100)
        return "\(percent)%"
    }
}

// MARK: - 紧凑版朗读播放器（用于空间有限的地方）

struct CompactSpeechPlayerView: View {
    let text: String

    @StateObject private var speechService = SpeechService.shared

    var body: some View {
        HStack(spacing: 12) {
            // 播放/暂停按钮
            Button {
                if speechService.isPlaying {
                    speechService.pause()
                } else if speechService.isPaused {
                    speechService.resume()
                } else {
                    speechService.speak(text)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: playButtonIcon)
                        .font(.system(size: 14, weight: .semibold))

                    Text(buttonText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appPrimary)
                .cornerRadius(20)
            }

            // 停止按钮（仅在播放中显示）
            if isActive {
                Button {
                    speechService.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }

            // 进度
            if isActive {
                Text("\(Int(speechService.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .onDisappear {
            if speechService.currentText == text {
                speechService.stop()
            }
        }
    }

    private var isActive: Bool {
        speechService.isPlaying || speechService.isPaused
    }

    private var playButtonIcon: String {
        if speechService.isPlaying {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }

    private var buttonText: String {
        if speechService.isPlaying {
            return "暂停"
        } else if speechService.isPaused {
            return "继续"
        } else {
            return "朗读"
        }
    }
}

// MARK: - 预览

#Preview("朗读播放器") {
    VStack(spacing: 20) {
        SpeechPlayerView(
            text: "这是一段测试文本，用于展示朗读播放器的功能。朗读功能可以帮助小朋友更好地理解文章内容。",
            title: "测试文章"
        )
        .padding()

        CompactSpeechPlayerView(
            text: "这是紧凑版的朗读按钮。"
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
