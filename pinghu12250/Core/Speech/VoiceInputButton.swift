//
//  VoiceInputButton.swift
//  pinghu12250
//
//  语音输入按钮组件 - 用于其他Tab的纯转文字输入
//

import SwiftUI
import Combine

// MARK: - 语音输入按钮（紧凑型）

struct VoiceInputButton: View {
    @ObservedObject var service: VoiceInputService
    let onTextReceived: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        Group {
            if isExpanded {
                expandedView
            } else {
                compactButton
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }

    // 紧凑按钮
    private var compactButton: some View {
        Button {
            startRecording()
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 18))
                .foregroundColor(service.state == .recording ? .red : .secondary)
        }
    }

    // 展开视图（录音中）
    private var expandedView: some View {
        HStack(spacing: 8) {
            // 波形动画
            VoiceWaveformMini(level: service.audioLevel)
                .frame(width: 40, height: 20)

            // 时长
            Text(VoiceInputService.formatDuration(service.recordingDuration))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()

            // 取消按钮
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            // 完成按钮
            Button {
                finishRecording()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    // MARK: - 操作

    private func startRecording() {
        isExpanded = true
        Task {
            await service.startTextOnlyRecording()
        }
    }

    private func cancelRecording() {
        service.cancel()
        isExpanded = false
    }

    private func finishRecording() {
        Task {
            let result = await service.stopRecording()
            isExpanded = false

            if case .success(let value) = result {
                if let text = value as? String, !text.isEmpty {
                    onTextReceived(text)
                }
            }
        }
    }
}

// MARK: - 迷你波形视图

struct VoiceWaveformMini: View {
    let level: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.2, count: 5)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: 3, height: bars[index] * 20)
            }
        }
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            for i in stride(from: bars.count - 1, through: 1, by: -1) {
                bars[i] = bars[i - 1]
            }
            bars[0] = max(0.2, CGFloat(level))
        }
    }
}

// MARK: - 语音输入浮层（完整版）

struct VoiceInputOverlay: View {
    @ObservedObject var service: VoiceInputService
    @Binding var isPresented: Bool
    let onTextReceived: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 状态标签
            statusLabel

            // 实时转写文本
            if !service.transcribedText.isEmpty {
                ScrollView {
                    Text(service.transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 120)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // 波形动画
            if service.state == .recording {
                VoiceWaveformView(level: service.audioLevel)
                    .frame(height: 50)
            }

            // 时长显示
            Text(VoiceInputService.formatDuration(service.recordingDuration))
                .font(.title2)
                .fontWeight(.medium)
                .monospacedDigit()

            // 操作按钮
            HStack(spacing: 40) {
                // 取消
                Button {
                    service.cancel()
                    isPresented = false
                } label: {
                    Text("取消")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }

                // 录音/停止按钮
                recordButton

                // 完成
                Button {
                    finishAndClose()
                } label: {
                    Text("完成")
                        .fontWeight(.semibold)
                        .foregroundColor(service.transcribedText.isEmpty ? .gray : .appPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .disabled(service.transcribedText.isEmpty)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .padding(.horizontal, 20)
    }

    private var statusLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if service.isOfflineAvailable {
                Text("离线")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private var statusColor: Color {
        switch service.state {
        case .recording: return .red
        case .recognizing: return .orange
        case .finished: return .green
        case .error: return .red
        default: return .gray
        }
    }

    private var statusText: String {
        switch service.state {
        case .idle: return "准备就绪"
        case .requesting: return "请求权限..."
        case .recording: return "正在录音"
        case .recognizing: return "识别中..."
        case .finished: return "识别完成"
        case .error(let error): return error.localizedDescription
        }
    }

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(service.state == .recording ? Color.red : Color.appPrimary)
                    .frame(width: 70, height: 70)

                if service.state == .recording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func toggleRecording() {
        if service.state == .recording {
            Task {
                _ = await service.stopRecording()
            }
        } else {
            Task {
                await service.startTextOnlyRecording()
            }
        }
    }

    private func finishAndClose() {
        let text = service.transcribedText
        service.reset()
        isPresented = false
        if !text.isEmpty {
            onTextReceived(text)
        }
    }
}

// MARK: - 大波形视图

struct VoiceWaveformView: View {
    let level: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 20)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appPrimary)
                    .frame(width: 4, height: bars[index] * 50)
            }
        }
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            for i in stride(from: bars.count - 1, through: 1, by: -1) {
                bars[i] = bars[i - 1]
            }
            bars[0] = max(0.1, CGFloat(level))
        }
    }
}

// MARK: - 权限提示视图

struct VoicePermissionAlert: View {
    let error: VoiceInputError
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text(error.localizedDescription ?? "权限错误")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("请前往「设置」>「苹湖少儿空间」开启权限")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Button("取消", action: onDismiss)
                    .foregroundColor(.secondary)

                Button("前往设置") {
                    onOpenSettings()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.appPrimary)
                .fontWeight(.semibold)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 预览

#Preview("VoiceInputButton") {
    HStack {
        TextField("输入内容...", text: .constant(""))
            .textFieldStyle(.roundedBorder)

        VoiceInputButton(service: VoiceInputService.shared) { text in
            print("收到文本: \(text)")
        }
    }
    .padding()
}

#Preview("VoiceInputOverlay") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        VoiceInputOverlay(
            service: VoiceInputService.shared,
            isPresented: .constant(true)
        ) { text in
            print("收到文本: \(text)")
        }
    }
}
