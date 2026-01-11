//
//  VoiceInputService.swift
//  pinghu12250
//
//  语音输入核心服务 - 支持纯转文字和语音笔记两种模式
//

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - 语音输入模式

enum VoiceInputMode {
    /// 纯转文字模式（解析/解题/探索Tab）
    /// 实时流式识别，不保存音频
    case textOnly

    /// 语音笔记模式（笔记Tab）
    /// 录音后识别，保存音频文件
    case voiceNote
}

// MARK: - 语音输入状态

enum VoiceInputState: Equatable {
    case idle                    // 空闲
    case requesting              // 请求权限中
    case recording               // 录音中
    case recognizing             // 识别中（仅语音笔记模式）
    case finished(String)        // 完成，带转写文本
    case error(VoiceInputError)  // 错误

    static func == (lhs: VoiceInputState, rhs: VoiceInputState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.requesting, .requesting),
             (.recording, .recording), (.recognizing, .recognizing):
            return true
        case (.finished(let a), .finished(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a.localizedDescription == b.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - 语音输入错误

enum VoiceInputError: LocalizedError {
    case microphoneNotAuthorized
    case speechRecognitionNotAuthorized
    case recognizerNotAvailable
    case recordingFailed(String)
    case recognitionFailed(String)
    case audioSessionFailed(String)
    case fileSaveFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .microphoneNotAuthorized:
            return "麦克风权限未授权，请在设置中开启"
        case .speechRecognitionNotAuthorized:
            return "语音识别权限未授权，请在设置中开启"
        case .recognizerNotAvailable:
            return "语音识别服务不可用"
        case .recordingFailed(let msg):
            return "录音失败：\(msg)"
        case .recognitionFailed(let msg):
            return "识别失败：\(msg)"
        case .audioSessionFailed(let msg):
            return "音频会话配置失败：\(msg)"
        case .fileSaveFailed:
            return "音频文件保存失败"
        case .cancelled:
            return "已取消"
        }
    }
}

// MARK: - 语音笔记结果

struct VoiceNoteResult {
    let audioFileURL: URL
    let transcribedText: String
    let duration: TimeInterval
    let isOfflineRecognized: Bool
    let createdAt: Date
}

// MARK: - 语音输入服务

@MainActor
class VoiceInputService: ObservableObject {

    // MARK: - 单例

    static let shared = VoiceInputService()

    // MARK: - 发布属性

    @Published private(set) var state: VoiceInputState = .idle
    @Published private(set) var transcribedText: String = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var isOfflineMode: Bool = false

    // MARK: - 配置

    private(set) var currentMode: VoiceInputMode = .textOnly
    private let maxRecordingDuration: TimeInterval = 60  // 最长60秒

    // MARK: - 私有属性

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // 语音笔记模式专用
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?

    // 定时器
    private var levelTimer: Timer?
    private var durationTimer: Timer?

    // 录音文件目录
    private let recordingsDirectory: URL

    // MARK: - 初始化

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

        // 创建录音文件目录
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        recordingsDirectory = cachesDir.appendingPathComponent("VoiceNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        // 检查离线识别能力
        checkOfflineCapability()
    }

    // MARK: - 离线识别检测

    private func checkOfflineCapability() {
        guard let recognizer = speechRecognizer else {
            isOfflineMode = false
            return
        }

        if #available(iOS 13.0, *) {
            isOfflineMode = recognizer.supportsOnDeviceRecognition
        } else {
            isOfflineMode = false
        }

        #if DEBUG
        print("[VoiceInput] 离线识别支持: \(isOfflineMode)")
        #endif
    }

    /// 离线识别是否可用
    var isOfflineAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        if #available(iOS 13.0, *) {
            return recognizer.supportsOnDeviceRecognition
        }
        return false
    }

    // MARK: - 权限检查

    func checkPermissions() async -> Result<Void, VoiceInputError> {
        // 检查麦克风权限
        let micStatus = AVAudioApplication.shared.recordPermission

        switch micStatus {
        case .denied:
            return .failure(.microphoneNotAuthorized)
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                return .failure(.microphoneNotAuthorized)
            }
        case .granted:
            break
        @unknown default:
            return .failure(.microphoneNotAuthorized)
        }

        // 检查语音识别权限
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        switch speechStatus {
        case .denied, .restricted:
            return .failure(.speechRecognitionNotAuthorized)
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            if status != .authorized {
                return .failure(.speechRecognitionNotAuthorized)
            }
        case .authorized:
            break
        @unknown default:
            return .failure(.speechRecognitionNotAuthorized)
        }

        return .success(())
    }

    // MARK: - 开始录音（纯转文字模式）

    func startTextOnlyRecording() async {
        currentMode = .textOnly
        state = .requesting

        // 检查权限
        let permissionResult = await checkPermissions()
        if case .failure(let error) = permissionResult {
            state = .error(error)
            return
        }

        // 检查识别器可用性
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .error(.recognizerNotAvailable)
            return
        }

        do {
            // 配置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else {
                throw VoiceInputError.recognitionFailed("无法创建识别请求")
            }

            request.shouldReportPartialResults = true

            // 配置离线识别
            if #available(iOS 13.0, *) {
                request.requiresOnDeviceRecognition = isOfflineAvailable
            }

            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }

            // 获取音频输入
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // 安装音频Tap
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)

                // 计算音量
                let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
                Task { @MainActor in
                    self?.audioLevel = level
                }
            }

            // 启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()

            state = .recording
            transcribedText = ""
            recordingDuration = 0

            startDurationTimer()

            // 启动识别任务
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let result = result {
                        self.transcribedText = result.bestTranscription.formattedString

                        if result.isFinal {
                            self.finishRecording(withText: result.bestTranscription.formattedString)
                        }
                    }

                    if let error = error {
                        // 忽略取消错误
                        if (error as NSError).code != 1 && (error as NSError).code != 216 {
                            self.state = .error(.recognitionFailed(error.localizedDescription))
                            self.stopRecordingInternal()
                        }
                    }
                }
            }

            #if DEBUG
            print("[VoiceInput] 纯转文字录音开始")
            #endif

        } catch {
            state = .error(.audioSessionFailed(error.localizedDescription))
        }
    }

    // MARK: - 开始录音（语音笔记模式）

    func startVoiceNoteRecording() async {
        currentMode = .voiceNote
        state = .requesting

        // 检查权限
        let permissionResult = await checkPermissions()
        if case .failure(let error) = permissionResult {
            state = .error(error)
            return
        }

        do {
            // 配置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            // 创建录音文件
            let fileName = "voice_note_\(Int(Date().timeIntervalSince1970)).m4a"
            let fileURL = recordingsDirectory.appendingPathComponent(fileName)
            recordedFileURL = fileURL

            // 录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            state = .recording
            transcribedText = ""
            recordingDuration = 0

            startDurationTimer()
            startLevelTimer()

            #if DEBUG
            print("[VoiceInput] 语音笔记录音开始: \(fileURL)")
            #endif

        } catch {
            state = .error(.recordingFailed(error.localizedDescription))
        }
    }

    // MARK: - 停止录音

    func stopRecording() async -> Result<Any, VoiceInputError> {
        switch currentMode {
        case .textOnly:
            stopRecordingInternal()
            if case .finished(let text) = state {
                return .success(text)
            } else if case .error(let error) = state {
                return .failure(error)
            }
            return .success(transcribedText)

        case .voiceNote:
            return await stopVoiceNoteRecording()
        }
    }

    private func stopRecordingInternal() {
        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // 结束识别
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // 停止定时器
        stopTimers()

        // 恢复音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        audioLevel = 0
    }

    private func stopVoiceNoteRecording() async -> Result<Any, VoiceInputError> {
        guard let recorder = audioRecorder, let fileURL = recordedFileURL else {
            return .failure(.recordingFailed("录音器未初始化"))
        }

        let duration = recorder.currentTime
        recorder.stop()
        audioRecorder = nil

        stopTimers()
        audioLevel = 0

        state = .recognizing

        // 识别录音文件
        do {
            let text = try await recognizeAudioFile(url: fileURL)

            let result = VoiceNoteResult(
                audioFileURL: fileURL,
                transcribedText: text,
                duration: duration,
                isOfflineRecognized: isOfflineMode,
                createdAt: Date()
            )

            state = .finished(text)
            transcribedText = text

            #if DEBUG
            print("[VoiceInput] 语音笔记识别完成: \(text.prefix(50))...")
            #endif

            return .success(result)

        } catch {
            // 识别失败，但保留音频文件
            let result = VoiceNoteResult(
                audioFileURL: fileURL,
                transcribedText: "",
                duration: duration,
                isOfflineRecognized: false,
                createdAt: Date()
            )

            state = .error(.recognitionFailed(error.localizedDescription))

            // 返回带空文本的结果，让用户手动输入
            return .success(result)
        }
    }

    // MARK: - 识别音频文件

    private func recognizeAudioFile(url: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceInputError.recognizerNotAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)

        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = isOfflineAvailable
        }

        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    // MARK: - 取消

    func cancel() {
        stopRecordingInternal()

        // 删除临时文件
        if let url = recordedFileURL {
            try? FileManager.default.removeItem(at: url)
            recordedFileURL = nil
        }

        state = .idle
        transcribedText = ""
        recordingDuration = 0
    }

    // MARK: - 重置

    func reset() {
        cancel()
    }

    // MARK: - 完成录音

    private func finishRecording(withText text: String) {
        stopRecordingInternal()
        state = .finished(text)
    }

    // MARK: - 音量计算

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = buffer.frameLength

        var sum: Float = 0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(rms)

        let minDb: Float = -60
        let maxDb: Float = 0
        return max(0, min(1, (db - minDb) / (maxDb - minDb)))
    }

    // MARK: - 定时器

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingDuration += 0.1

                // 超时检查
                if self.recordingDuration >= self.maxRecordingDuration {
                    _ = await self.stopRecording()
                }
            }
        }
    }

    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }

                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                let minDb: Float = -60
                let level = max(0, (db - minDb) / (-minDb))
                self.audioLevel = level
            }
        }
    }

    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    // MARK: - 工具方法

    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
