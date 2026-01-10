//
//  AudioRecorderManager.swift
//  pinghu12250
//
//  专业录音管理器 - 支持录音、暂停、播放、波形显示
//

import Foundation
import AVFoundation
import Combine

// MARK: - 录音状态

enum RecordingState: Equatable {
    case idle           // 空闲
    case recording      // 录音中
    case paused         // 暂停
    case stopped        // 已停止（有录音文件）
    case playing        // 播放中
    case playPaused     // 播放暂停
}

// MARK: - 录音管理器

@MainActor
class AudioRecorderManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var state: RecordingState = .idle
    @Published var recordingTime: TimeInterval = 0
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var recordedFileURL: URL?

    // MARK: - 高频状态（内部使用，View 不应直接订阅）

    @Published private(set) var _audioLevel: Float = 0
    @Published private(set) var _waveformSamples: [Float] = []

    // MARK: - 节流状态（View 应订阅这些）

    /// 节流后的音量电平（100ms 节流 + 变化阈值 0.05）
    lazy var throttledLevel: AudioLevelThrottle = {
        AudioLevelThrottle(intervalMs: 100, changeThreshold: 0.05)
    }()

    /// 节流后的波形数据（150ms 批量刷新）
    lazy var throttledWaveform: WaveformThrottle = {
        WaveformThrottle(maxSamples: 300, intervalMs: 150)
    }()

    // MARK: - 兼容性访问器（向后兼容，但建议使用节流版本）

    var audioLevel: Float {
        get { throttledLevel.displayLevel }
        set {
            _audioLevel = newValue
            throttledLevel.update(newValue)
        }
    }

    var waveformSamples: [Float] {
        get { throttledWaveform.samples }
    }

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var playbackTimer: Timer?

    // 录音配置
    private let maxRecordingDuration: TimeInterval = 180 // 最长3分钟
    private let sampleRate: Double = 44100
    private let numberOfChannels: Int = 1

    // 临时文件目录
    private let recordingsDirectory: URL

    // MARK: - 初始化

    override init() {
        // 创建录音文件目录
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        recordingsDirectory = cachesDir.appendingPathComponent("Recordings", isDirectory: true)

        super.init()

        // 确保目录存在
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 权限检查

    func requestPermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission

        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - 录音控制

    /// 开始录音
    func startRecording() async {
        // 检查权限
        guard await requestPermission() else {
            errorMessage = "请在设置中允许麦克风权限"
            return
        }

        // 配置音频会话
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "音频会话配置失败: \(error.localizedDescription)"
            return
        }

        // 创建录音文件
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        // 录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: numberOfChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            recordedFileURL = fileURL
            state = .recording
            recordingTime = 0
            throttledWaveform.reset()
            throttledLevel.reset()

            startRecordingTimer()
            startLevelTimer()

        } catch {
            errorMessage = "录音启动失败: \(error.localizedDescription)"
        }
    }

    /// 暂停录音
    func pauseRecording() {
        guard state == .recording else { return }

        audioRecorder?.pause()
        state = .paused
        stopLevelTimer()
    }

    /// 继续录音
    func resumeRecording() {
        guard state == .paused else { return }

        audioRecorder?.record()
        state = .recording
        startLevelTimer()
    }

    /// 停止录音
    func stopRecording() {
        guard state == .recording || state == .paused else { return }

        audioRecorder?.stop()
        state = .stopped

        stopRecordingTimer()
        stopLevelTimer()

        // 获取录音时长
        if let url = recordedFileURL {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                playbackDuration = player.duration
            } catch {
                #if DEBUG
                print("获取录音时长失败: \(error)")
                #endif
            }
        }
    }

    /// 重新录制（删除当前录音）
    func resetRecording() {
        // 停止播放和录音
        audioPlayer?.stop()
        audioRecorder?.stop()

        // 删除文件
        if let url = recordedFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        // 重置状态
        state = .idle
        recordingTime = 0
        playbackTime = 0
        playbackDuration = 0
        _audioLevel = 0
        throttledLevel.reset()
        throttledWaveform.reset()
        recordedFileURL = nil

        stopRecordingTimer()
        stopLevelTimer()
        stopPlaybackTimer()
    }

    // MARK: - 播放控制

    /// 播放录音
    func play() {
        guard let url = recordedFileURL else { return }

        do {
            // 配置音频会话
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            playbackDuration = audioPlayer?.duration ?? 0
            state = .playing

            startPlaybackTimer()

        } catch {
            errorMessage = "播放失败: \(error.localizedDescription)"
        }
    }

    /// 暂停播放
    func pausePlayback() {
        guard state == .playing else { return }

        audioPlayer?.pause()
        state = .playPaused
        stopPlaybackTimer()
    }

    /// 继续播放
    func resumePlayback() {
        guard state == .playPaused else { return }

        audioPlayer?.play()
        state = .playing
        startPlaybackTimer()
    }

    /// 停止播放
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        playbackTime = 0
        state = .stopped
        stopPlaybackTimer()
    }

    /// 跳转到指定位置
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        playbackTime = time
    }

    // MARK: - 定时器

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordingTime = self.audioRecorder?.currentTime ?? 0

                // 检查是否超过最大时长
                if self.recordingTime >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder else { return }

                recorder.updateMeters()

                // 获取音量级别 (-160 到 0 dB)
                let db = recorder.averagePower(forChannel: 0)

                // 转换为 0-1 范围
                let minDb: Float = -60
                let level = max(0, (db - minDb) / (-minDb))

                // 更新节流后的值（自动节流）
                self._audioLevel = level
                self.throttledLevel.update(level)

                // 添加到节流波形数据
                self.throttledWaveform.append(level)
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.playbackTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - 工具方法

    /// 格式化时间
    static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化时间（带毫秒）
    static func formatTimeWithMs(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, ms)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "录音失败"
                state = .idle
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = "录音编码错误: \(error?.localizedDescription ?? "未知错误")"
            state = .idle
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioRecorderManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            state = .stopped
            playbackTime = 0
            stopPlaybackTimer()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            errorMessage = "播放解码错误: \(error?.localizedDescription ?? "未知错误")"
            state = .stopped
        }
    }
}
