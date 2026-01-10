//
//  SpeechControlBar.swift
//  pinghu12250
//
//  朗读控制栏 - 用于 EPUB 章节朗读
//

import SwiftUI

/// 朗读控制栏
struct SpeechControlBar: View {
    @ObservedObject var speechManager: SpeechManager
    let text: String
    let onClose: () -> Void

    @State private var showRateMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color.appPrimary)
                        .frame(width: geometry.size.width * speechManager.progress, height: 3)
                }
            }
            .frame(height: 3)

            // 控制按钮区
            HStack(spacing: 20) {
                // 关闭按钮
                Button {
                    speechManager.stop()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                Spacer()

                // 减速按钮
                Button {
                    speechManager.decreaseRate()
                    restartIfPlaying()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(speechManager.rate > 0.5 ? 1 : 0.4))
                }
                .disabled(speechManager.rate <= 0.5)

                // 语速显示
                Button {
                    showRateMenu = true
                } label: {
                    Text(speechManager.rateLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 50)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .popover(isPresented: $showRateMenu) {
                    rateMenuContent
                }

                // 加速按钮
                Button {
                    speechManager.increaseRate()
                    restartIfPlaying()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(speechManager.rate < 3.0 ? 1 : 0.4))
                }
                .disabled(speechManager.rate >= 3.0)

                Spacer()

                // 播放/暂停按钮
                Button {
                    if speechManager.state == .idle {
                        speechManager.speak(text)
                    } else {
                        speechManager.togglePlayPause()
                    }
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                }

                Spacer()

                // 重新开始按钮
                Button {
                    speechManager.speak(text)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                Spacer()

                // 占位，保持对称
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.85))
    }

    private var playPauseIcon: String {
        switch speechManager.state {
        case .idle, .paused:
            return "play.fill"
        case .playing:
            return "pause.fill"
        }
    }

    private var rateMenuContent: some View {
        VStack(spacing: 0) {
            ForEach(SpeechManager.ratePresets, id: \.value) { preset in
                Button {
                    speechManager.rate = preset.value
                    showRateMenu = false
                    restartIfPlaying()
                } label: {
                    HStack {
                        Text(preset.label)
                            .font(.body)
                        Spacer()
                        if speechManager.rate == preset.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .foregroundColor(.primary)

                if preset.value != SpeechManager.ratePresets.last?.value {
                    Divider()
                }
            }
        }
        .frame(width: 120)
        .presentationCompactAdaptation(.popover)
    }

    /// 如果正在播放，则以新语速重新开始
    private func restartIfPlaying() {
        if speechManager.state == .playing {
            speechManager.speak(text)
        }
    }
}

/// 紧凑版朗读控制按钮（用于工具栏）
struct CompactSpeechButton: View {
    @ObservedObject var speechManager: SpeechManager
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))

                    // 播放中的动画指示器
                    if speechManager.state == .playing {
                        Circle()
                            .stroke(Color.appPrimary, lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .opacity(0.6)
                    }
                }
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isActive ? .appPrimary : .white)
        }
    }

    private var icon: String {
        switch speechManager.state {
        case .idle:
            return "speaker.wave.2"
        case .playing:
            return "speaker.wave.3.fill"
        case .paused:
            return "speaker.slash"
        }
    }

    private var label: String {
        switch speechManager.state {
        case .idle:
            return "朗读"
        case .playing:
            return "朗读中"
        case .paused:
            return "已暂停"
        }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()
        SpeechControlBar(
            speechManager: SpeechManager.shared,
            text: "这是一段测试文本，用于演示朗读功能。",
            onClose: {}
        )
    }
    .background(Color.gray)
}
