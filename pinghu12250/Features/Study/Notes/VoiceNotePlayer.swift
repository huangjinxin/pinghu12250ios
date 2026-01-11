//
//  VoiceNotePlayer.swift
//  pinghu12250
//
//  语音笔记播放组件 - iMessage风格
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 语音笔记播放器管理器

@MainActor
class VoiceNotePlayerManager: NSObject, ObservableObject {

    static let shared = VoiceNotePlayerManager()

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPlayingURL: URL?

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private override init() {
        super.init()
    }

    // MARK: - 播放控制

    func play(url: URL) {
        // 如果正在播放其他音频，先停止
        if isPlaying && currentPlayingURL != url {
            stop()
        }

        // 如果是同一个音频，切换播放/暂停
        if currentPlayingURL == url {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }

        do {
            // 配置音频会话
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            currentPlayingURL = url
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            isPlaying = true

            startProgressTimer()

        } catch {
            #if DEBUG
            print("[VoiceNotePlayer] 播放失败: \(error)")
            #endif
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        currentPlayingURL = nil
        stopProgressTimer()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    // MARK: - 进度定时器

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.audioPlayer?.currentTime ?? 0
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension VoiceNotePlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopProgressTimer()
        }
    }
}

// MARK: - iMessage风格语音笔记卡片

struct VoiceNoteCard: View {
    let text: String
    let audioURL: URL?
    let duration: TimeInterval
    let page: Int?
    let createdAt: Date?

    @ObservedObject private var player = VoiceNotePlayerManager.shared
    @State private var isExpanded = false

    private var isCurrentPlaying: Bool {
        player.currentPlayingURL == audioURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))

                Text("语音笔记")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let page = page {
                    Text("· 第\(page)页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let createdAt = createdAt {
                    Text(createdAt.relativeDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 文本内容
            if !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 3)
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }

                if text.count > 100 && !isExpanded {
                    Button("展开全部") {
                        withAnimation {
                            isExpanded = true
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                }
            }

            // 音频播放条
            if audioURL != nil {
                audioPlayerBar
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // 音频播放条
    private var audioPlayerBar: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button {
                if let url = audioURL {
                    player.play(url: url)
                }
            } label: {
                Image(systemName: isCurrentPlaying && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.orange)
                    .clipShape(Circle())
            }

            // 进度条
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)

                        // 进度
                        Capsule()
                            .fill(Color.orange)
                            .frame(
                                width: isCurrentPlaying
                                    ? geometry.size.width * (player.duration > 0 ? player.currentTime / player.duration : 0)
                                    : 0,
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
            }

            // 时长
            Text(formatTime(isCurrentPlaying ? player.currentTime : 0))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()

            Text("/")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatTime(duration))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 紧凑型音频播放条（用于笔记列表）

struct CompactAudioPlayer: View {
    let audioURL: URL?
    let duration: TimeInterval

    @ObservedObject private var player = VoiceNotePlayerManager.shared

    private var isCurrentPlaying: Bool {
        player.currentPlayingURL == audioURL
    }

    var body: some View {
        HStack(spacing: 8) {
            // 播放按钮
            Button {
                if let url = audioURL {
                    player.play(url: url)
                }
            } label: {
                Image(systemName: isCurrentPlaying && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.orange)
                    .clipShape(Circle())
            }

            // 简化进度条
            Capsule()
                .fill(Color(.systemGray5))
                .frame(height: 3)
                .overlay(
                    GeometryReader { geometry in
                        Capsule()
                            .fill(Color.orange)
                            .frame(
                                width: isCurrentPlaying && player.duration > 0
                                    ? geometry.size.width * (player.currentTime / player.duration)
                                    : 0
                            )
                    }
                )

            // 时长
            Text(formatTime(duration))
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .frame(height: 28)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 注意: Date.relativeDescription 已在 Date+Extensions.swift 中定义

// MARK: - 预览

#Preview("VoiceNoteCard") {
    VStack(spacing: 16) {
        VoiceNoteCard(
            text: "这道题的关键是要理解分数的概念，分母表示把整体分成多少份，分子表示取其中多少份。所以三分之二就是把整体分成三份，取其中两份。",
            audioURL: nil,
            duration: 23.5,
            page: 23,
            createdAt: Date()
        )

        VoiceNoteCard(
            text: "短笔记",
            audioURL: nil,
            duration: 5.2,
            page: nil,
            createdAt: Date().addingTimeInterval(-3600)
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("CompactAudioPlayer") {
    CompactAudioPlayer(
        audioURL: nil,
        duration: 15.3
    )
    .padding()
}
