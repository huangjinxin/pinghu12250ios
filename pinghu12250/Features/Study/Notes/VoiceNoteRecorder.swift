//
//  VoiceNoteRecorder.swift
//  pinghu12250
//
//  语音转文字服务 - 用于笔记语音输入
//

import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

// MARK: - 语音录制器

@MainActor
class VoiceNoteRecorder: ObservableObject {
    // 发布的状态
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var error: String?
    @Published var audioLevel: Float = 0

    // 语音识别
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // 音频引擎
    private let audioEngine = AVAudioEngine()

    // 音量监测定时器
    private var levelTimer: Timer?

    init() {
        checkAuthorization()
    }

    // MARK: - 权限检查

    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.error = "语音识别权限未授权"
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }

    // MARK: - 开始录音

    func startRecording() async throws {
        guard isAuthorized else {
            throw VoiceRecorderError.notAuthorized
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceRecorderError.recognizerNotAvailable
        }

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecorderError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true  // iOS 16+ 自动添加标点

        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 安装音频Tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // 计算音量级别
            let level = self?.calculateLevel(buffer: buffer) ?? 0
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""

        // 开始识别任务
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }

                if let error = error {
                    self?.error = error.localizedDescription
                    self?.stopRecording()
                }

                // 检查是否最终结果
                if result?.isFinal == true {
                    self?.stopRecording()
                }
            }
        }

        #if DEBUG
        print("[VoiceRecorder] Recording started")
        #endif
    }

    // MARK: - 停止录音

    func stopRecording() {
        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // 结束识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil

        // 停止音量监测
        levelTimer?.invalidate()
        levelTimer = nil

        isRecording = false
        audioLevel = 0

        // 恢复音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        #if DEBUG
        print("[VoiceRecorder] Recording stopped, text: \(transcribedText)")
        #endif
    }

    // MARK: - 计算音量级别

    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = buffer.frameLength

        var sum: Float = 0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(rms)

        // 将dB值映射到0-1范围
        let minDb: Float = -60
        let maxDb: Float = 0
        let normalized = max(0, min(1, (db - minDb) / (maxDb - minDb)))

        return normalized
    }

    // MARK: - 重置

    func reset() {
        stopRecording()
        transcribedText = ""
        error = nil
    }

    // MARK: - 获取最终文本

    func getFinalText() -> String {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        reset()
        return text
    }
}

// MARK: - 错误类型

enum VoiceRecorderError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case requestCreationFailed
    case audioSessionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "语音识别未授权，请在设置中开启权限"
        case .recognizerNotAvailable:
            return "语音识别服务不可用"
        case .requestCreationFailed:
            return "无法创建识别请求"
        case .audioSessionFailed:
            return "音频会话配置失败"
        }
    }
}

// MARK: - 语音录制视图组件

struct VoiceRecordingView: View {
    @ObservedObject var recorder: VoiceNoteRecorder
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 状态指示
            HStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recorder.isRecording)

                Text(recorder.isRecording ? "正在录音..." : "准备就绪")
                    .font(.headline)

                Spacer()

                if recorder.isRecording {
                    Text(recorder.transcribedText.count > 0 ? "\(recorder.transcribedText.count)字" : "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 转写结果
            if !recorder.transcribedText.isEmpty {
                ScrollView {
                    Text(recorder.transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 150)
            }

            // 音量波形
            if recorder.isRecording {
                AudioWaveformView(level: recorder.audioLevel)
                    .frame(height: 40)
            }

            // 操作按钮
            HStack(spacing: 30) {
                Button(action: onCancel) {
                    Text("取消")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }

                if recorder.isRecording {
                    Button {
                        recorder.stopRecording()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                } else {
                    Button {
                        Task {
                            try? await recorder.startRecording()
                        }
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                    }
                }

                Button {
                    let text = recorder.getFinalText()
                    if !text.isEmpty {
                        onComplete(text)
                    }
                } label: {
                    Text("完成")
                        .fontWeight(.semibold)
                        .foregroundColor(recorder.transcribedText.isEmpty ? .gray : .appPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .disabled(recorder.transcribedText.isEmpty)
            }

            // 错误提示
            if let error = recorder.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
}

// MARK: - 音量波形视图

struct AudioWaveformView: View {
    let level: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 20)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appPrimary)
                    .frame(width: 4, height: bars[index] * 40)
            }
        }
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            // 移动现有的条
            for i in stride(from: bars.count - 1, through: 1, by: -1) {
                bars[i] = bars[i - 1]
            }
            // 添加新的条
            bars[0] = max(0.1, CGFloat(level))
        }
    }
}

// MARK: - 语音录制 Sheet（用于 NoteEditorView）

struct VoiceRecordingSheet: View {
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var recorder = VoiceNoteRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VoiceRecordingView(
                    recorder: recorder,
                    onComplete: onComplete,
                    onCancel: onCancel
                )

                Spacer()
            }
            .padding()
            .navigationTitle("语音输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        recorder.stopRecording()
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("VoiceRecordingView") {
    VoiceRecordingView(
        recorder: VoiceNoteRecorder(),
        onComplete: { _ in },
        onCancel: {}
    )
    .padding()
}

#Preview("VoiceRecordingSheet") {
    VoiceRecordingSheet(
        onComplete: { text in print("Got: \(text)") },
        onCancel: {}
    )
}
