//
//  VoiceNoteRecordingSheet.swift
//  pinghu12250
//
//  语音笔记录制面板 - 用于笔记Tab
//

import SwiftUI
import Combine

// MARK: - 语音笔记录制Sheet

struct VoiceNoteRecordingSheet: View {
    @ObservedObject var service: VoiceInputService
    let onSave: (VoiceNoteResult, String) -> Void
    let onCancel: () -> Void

    @State private var editedText: String = ""
    @State private var showPreview = false
    @State private var voiceNoteResult: VoiceNoteResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showPreview, let result = voiceNoteResult {
                    previewView(result: result)
                } else {
                    recordingView
                }
            }
            .navigationTitle(showPreview ? "确认笔记" : "语音笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        service.cancel()
                        onCancel()
                    }
                }

                if showPreview {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            saveNote()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - 录音视图

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 状态提示
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if service.state == .recording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }

                    Text(statusText)
                        .font(.headline)
                }

                // 离线状态标签
                if service.isOfflineAvailable {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("离线识别已就绪")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // 时长显示
            Text(VoiceInputService.formatDuration(service.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(.primary)

            // 波形动画
            if service.state == .recording {
                RecordingWaveform(level: service.audioLevel)
                    .frame(height: 60)
                    .padding(.horizontal, 40)
            } else {
                // 占位
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 60)
            }

            // 实时转写文本（纯转文字模式时显示）
            if !service.transcribedText.isEmpty && service.currentMode == .textOnly {
                ScrollView {
                    Text(service.transcribedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            Spacer()

            // 操作按钮
            recordingControls

            // 提示文字
            Text("最长可录制60秒")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .padding()
    }

    private var statusText: String {
        switch service.state {
        case .idle: return "点击开始录音"
        case .requesting: return "请求权限中..."
        case .recording: return "正在录音"
        case .recognizing: return "识别中..."
        case .finished: return "录音完成"
        case .error(let error): return error.localizedDescription
        }
    }

    private var recordingControls: some View {
        HStack(spacing: 40) {
            // 重录按钮
            if service.state == .recording || service.recordingDuration > 0 {
                Button {
                    service.cancel()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                        Text("重录")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                }
            } else {
                Spacer()
                    .frame(width: 60)
            }

            // 主按钮
            mainRecordButton

            // 完成按钮
            if service.state == .recording {
                Button {
                    finishRecording()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20))
                        Text("完成")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .frame(width: 60)
                }
            } else {
                Spacer()
                    .frame(width: 60)
            }
        }
    }

    private var mainRecordButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                // 外圈
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 4)
                    .frame(width: 80, height: 80)

                // 内圈/方块
                if service.state == .recording {
                    // 录音中显示红色方块
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else if service.state == .recognizing {
                    // 识别中显示加载动画
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    // 空闲状态显示红色圆形
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .disabled(service.state == .recognizing)
    }

    private func toggleRecording() {
        if service.state == .recording {
            finishRecording()
        } else if service.state == .idle || service.state == .finished(.init()) || isErrorState {
            Task {
                await service.startVoiceNoteRecording()
            }
        }
    }

    private var isErrorState: Bool {
        if case .error = service.state {
            return true
        }
        return false
    }

    private func finishRecording() {
        Task {
            let result = await service.stopRecording()

            if case .success(let value) = result {
                if let noteResult = value as? VoiceNoteResult {
                    voiceNoteResult = noteResult
                    editedText = noteResult.transcribedText
                    showPreview = true
                }
            }
        }
    }

    // MARK: - 预览视图

    private func previewView(result: VoiceNoteResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 音频播放
                VStack(alignment: .leading, spacing: 12) {
                    Text("录音")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    CompactAudioPlayer(
                        audioURL: result.audioFileURL,
                        duration: result.duration
                    )
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // 转写文本编辑
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("转写文本")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Spacer()

                        if result.isOfflineRecognized {
                            Label("离线识别", systemImage: "checkmark.icloud")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }

                    TextEditor(text: $editedText)
                        .font(.body)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    Text("可以编辑修正识别结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 重新录制按钮
                Button {
                    showPreview = false
                    voiceNoteResult = nil
                    editedText = ""
                    service.reset()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重新录制")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func saveNote() {
        guard let result = voiceNoteResult else { return }
        onSave(result, editedText)
    }
}

// MARK: - 录音波形动画

struct RecordingWaveform: View {
    let level: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.15, count: 30)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 4, height: bars[index] * 60)
            }
        }
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        withAnimation(.easeOut(duration: 0.08)) {
            // 从中间向两边更新
            let midIndex = bars.count / 2

            // 左半边向左移动
            for i in stride(from: 0, to: midIndex, by: 1) {
                if i > 0 {
                    bars[i - 1] = bars[i]
                }
            }

            // 右半边向右移动
            for i in stride(from: bars.count - 1, through: midIndex + 1, by: -1) {
                if i < bars.count - 1 {
                    bars[i + 1] = bars[i]
                }
            }

            // 中间两个条设置为当前音量
            let currentLevel = max(0.15, CGFloat(level))
            bars[midIndex] = currentLevel
            bars[midIndex - 1] = currentLevel
        }
    }
}

// MARK: - 预览

#Preview("Recording") {
    VoiceNoteRecordingSheet(
        service: VoiceInputService.shared,
        onSave: { _, _ in },
        onCancel: {}
    )
}
