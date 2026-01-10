//
//  AudioRecorderView.swift
//  pinghu12250
//
//  专业录音组件 - 支持录音、暂停、播放、波形显示
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 录音组件

struct AudioRecorderView: View {
    @StateObject private var recorder = AudioRecorderManager()
    @Binding var recordedURL: URL?
    var maxDuration: TimeInterval = 180 // 最长录音时长（秒）
    var title: String = "录音"
    var onComplete: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 波形显示区
                waveformSection
                    .frame(height: 120)

                Divider()

                // 时间和进度
                timeSection
                    .padding()

                Spacer()

                // 控制按钮区
                controlSection
                    .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        recorder.resetRecording()
                        dismiss()
                    }
                }

                if recorder.state == .stopped {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") {
                            if let url = recorder.recordedFileURL {
                                recordedURL = url
                                onComplete?(url)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .alert("提示", isPresented: .constant(recorder.errorMessage != nil)) {
                Button("确定") { recorder.errorMessage = nil }
            } message: {
                Text(recorder.errorMessage ?? "")
            }
        }
    }

    // MARK: - 波形显示区

    private var waveformSection: some View {
        ZStack {
            // 背景
            Color(.systemBackground)

            if recorder.state == .idle {
                // 空闲状态提示
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("点击下方按钮开始录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 波形显示
                WaveformView(
                    samples: recorder.waveformSamples,
                    currentLevel: recorder.audioLevel,
                    isRecording: recorder.state == .recording
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 时间显示区

    private var timeSection: some View {
        VStack(spacing: 16) {
            // 主时间显示
            Text(timeDisplay)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(timeColor)

            // 播放进度条（录音完成后显示）
            if recorder.state == .stopped || recorder.state == .playing || recorder.state == .playPaused {
                PlaybackProgressBar(
                    currentTime: $recorder.playbackTime,
                    duration: recorder.playbackDuration,
                    onSeek: { time in
                        recorder.seek(to: time)
                    }
                )
            }

            // 状态提示
            HStack {
                statusIndicator

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var timeDisplay: String {
        switch recorder.state {
        case .idle:
            return "00:00"
        case .recording, .paused:
            return AudioRecorderManager.formatTime(recorder.recordingTime)
        case .stopped, .playing, .playPaused:
            return AudioRecorderManager.formatTime(recorder.playbackTime)
        }
    }

    private var timeColor: Color {
        switch recorder.state {
        case .recording: return .red
        case .paused: return .orange
        case .playing: return .appPrimary
        default: return .primary
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch recorder.state {
        case .recording:
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .modifier(PulseAnimation())

        case .paused:
            Image(systemName: "pause.fill")
                .foregroundColor(.orange)
                .font(.caption)

        case .playing:
            Image(systemName: "play.fill")
                .foregroundColor(.appPrimary)
                .font(.caption)

        default:
            EmptyView()
        }
    }

    private var statusText: String {
        switch recorder.state {
        case .idle: return "准备就绪"
        case .recording: return "录音中..."
        case .paused: return "已暂停"
        case .stopped: return "录音完成 · \(AudioRecorderManager.formatTime(recorder.playbackDuration))"
        case .playing: return "播放中..."
        case .playPaused: return "播放暂停"
        }
    }

    // MARK: - 控制按钮区

    private var controlSection: some View {
        VStack(spacing: 24) {
            // 主按钮行
            HStack(spacing: 40) {
                // 左侧按钮：重录/暂停
                if recorder.state != .idle {
                    Button {
                        handleLeftButton()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: leftButtonIcon)
                                .font(.system(size: 24))
                                .frame(width: 56, height: 56)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())

                            Text(leftButtonLabel)
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }

                // 中间主按钮：录音/停止
                Button {
                    handleMainButton()
                } label: {
                    ZStack {
                        Circle()
                            .fill(mainButtonColor)
                            .frame(width: 80, height: 80)

                        Image(systemName: mainButtonIcon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                // 右侧按钮：播放/暂停
                if recorder.state == .stopped || recorder.state == .playing || recorder.state == .playPaused {
                    Button {
                        handleRightButton()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: rightButtonIcon)
                                .font(.system(size: 24))
                                .frame(width: 56, height: 56)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())

                            Text(rightButtonLabel)
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }

            // 时长限制提示
            if recorder.state == .recording || recorder.state == .paused {
                Text("最长录音 \(Int(maxDuration / 60)) 分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 按钮配置

    private var mainButtonIcon: String {
        switch recorder.state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .paused: return "stop.fill"
        case .stopped: return "mic.fill"
        case .playing, .playPaused: return "mic.fill"
        }
    }

    private var mainButtonColor: Color {
        switch recorder.state {
        case .recording: return .red
        case .paused: return .orange
        default: return .appPrimary
        }
    }

    private var leftButtonIcon: String {
        switch recorder.state {
        case .recording: return "pause.fill"
        case .paused: return "play.fill"
        case .stopped, .playing, .playPaused: return "arrow.counterclockwise"
        default: return "pause.fill"
        }
    }

    private var leftButtonLabel: String {
        switch recorder.state {
        case .recording: return "暂停"
        case .paused: return "继续"
        case .stopped, .playing, .playPaused: return "重录"
        default: return ""
        }
    }

    private var rightButtonIcon: String {
        switch recorder.state {
        case .playing: return "pause.fill"
        case .playPaused, .stopped: return "play.fill"
        default: return "play.fill"
        }
    }

    private var rightButtonLabel: String {
        switch recorder.state {
        case .playing: return "暂停"
        default: return "试听"
        }
    }

    // MARK: - 按钮事件

    private func handleMainButton() {
        Task {
            switch recorder.state {
            case .idle, .stopped, .playing, .playPaused:
                // 如果有录音，先停止播放
                if recorder.state == .playing || recorder.state == .playPaused {
                    recorder.stopPlayback()
                }
                // 如果已有录音，需要确认是否重录
                if recorder.state == .stopped {
                    recorder.resetRecording()
                }
                await recorder.startRecording()

            case .recording, .paused:
                recorder.stopRecording()
            }
        }
    }

    private func handleLeftButton() {
        switch recorder.state {
        case .recording:
            recorder.pauseRecording()
        case .paused:
            recorder.resumeRecording()
        case .stopped, .playing, .playPaused:
            recorder.resetRecording()
        default:
            break
        }
    }

    private func handleRightButton() {
        switch recorder.state {
        case .stopped, .playPaused:
            recorder.play()
        case .playing:
            recorder.pausePlayback()
        default:
            break
        }
    }
}

// MARK: - 波形视图

struct WaveformView: View {
    let samples: [Float]
    let currentLevel: Float
    let isRecording: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                // 显示历史波形
                ForEach(Array(samples.enumerated()), id: \.offset) { index, level in
                    WaveformBar(level: level, maxHeight: geometry.size.height * 0.8)
                }

                // 当前音量条（录音时）
                if isRecording {
                    WaveformBar(level: currentLevel, maxHeight: geometry.size.height * 0.8)
                        .foregroundColor(.red)
                }

                Spacer()
            }
        }
    }
}

struct WaveformBar: View {
    let level: Float
    let maxHeight: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.appPrimary.opacity(0.7))
            .frame(width: 3, height: max(4, CGFloat(level) * maxHeight))
    }
}

// MARK: - 播放进度条

struct PlaybackProgressBar: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 4)

                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appPrimary)
                        .frame(width: geometry.size.width * progress, height: 4)

                    // 拖动手柄
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 16, height: 16)
                        .offset(x: geometry.size.width * progress - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                    currentTime = duration * newProgress
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                    onSeek(duration * newProgress)
                                }
                        )
                }
            }
            .frame(height: 16)

            // 时间标签
            HStack {
                Text(AudioRecorderManager.formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(AudioRecorderManager.formatTime(duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}

// MARK: - 脉冲动画

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - 紧凑录音按钮（用于表单中）

struct CompactRecordButton: View {
    @Binding var audioURL: URL?
    var title: String = "录音"
    var maxDuration: TimeInterval = 180

    @State private var showRecorder = false
    @State private var isPlaying = false
    @StateObject private var player = SimpleAudioPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let url = audioURL {
                // 已有录音
                HStack(spacing: 12) {
                    // 播放按钮
                    Button {
                        if player.isPlaying {
                            player.pause()
                        } else {
                            player.play(url: url)
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.appPrimary)
                    }

                    // 进度信息
                    VStack(alignment: .leading, spacing: 4) {
                        // 进度条
                        ProgressView(value: player.progress)
                            .tint(.appPrimary)

                        // 时间
                        HStack {
                            Text(AudioRecorderManager.formatTime(player.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(AudioRecorderManager.formatTime(player.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 重录按钮
                    Button {
                        player.stop()
                        showRecorder = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }

                    // 删除按钮
                    Button {
                        player.stop()
                        audioURL = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // 无录音，显示录音按钮
                Button {
                    showRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 32))
                        Text("点击录音")
                            .font(.headline)
                    }
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
            }
        }
        .sheet(isPresented: $showRecorder) {
            AudioRecorderView(
                recordedURL: $audioURL,
                maxDuration: maxDuration,
                title: title
            )
        }
    }
}

// MARK: - 简单音频播放器

@MainActor
class SimpleAudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func play(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()

            duration = player?.duration ?? 0
            isPlaying = true

            startTimer()
        } catch {
            #if DEBUG
            print("播放失败: \(error)")
            #endif
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = self.player?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension SimpleAudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopTimer()
        }
    }
}

// MARK: - 预览

#Preview("录音组件") {
    struct PreviewWrapper: View {
        @State private var url: URL?

        var body: some View {
            AudioRecorderView(recordedURL: $url, title: "背诗录音")
        }
    }
    return PreviewWrapper()
}

#Preview("紧凑录音按钮") {
    struct PreviewWrapper: View {
        @State private var url: URL?

        var body: some View {
            VStack {
                CompactRecordButton(audioURL: $url, title: "朗读录音")
                    .padding()

                Spacer()
            }
        }
    }
    return PreviewWrapper()
}
