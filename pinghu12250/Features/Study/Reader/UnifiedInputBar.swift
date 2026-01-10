//
//  UnifiedInputBar.swift
//  pinghu12250
//
//  统一输入框组件 - 用于探索/解析/解题/笔记Tab
//  支持语音输入功能
//

import SwiftUI

// MARK: - 输入框模式

enum InputBarMode {
    case search     // 探索Tab - 搜索模式
    case chat       // 解析/解题Tab - AI聊天模式
    case note       // 笔记Tab - 笔记添加模式

    var placeholder: String {
        switch self {
        case .search: return "搜索教材内容..."
        case .chat: return "问AI任何问题..."
        case .note: return "添加笔记..."
        }
    }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .chat: return "sparkles"
        case .note: return "pencil"
        }
    }

    var accentColor: Color {
        switch self {
        case .search: return .appPrimary
        case .chat: return .purple
        case .note: return .orange
        }
    }

    var sendIcon: String {
        switch self {
        case .search: return "arrow.right.circle.fill"
        case .chat: return "arrow.up.circle.fill"
        case .note: return "plus.circle.fill"
        }
    }

    /// 是否支持语音输入（纯转文字）
    var supportsVoiceInput: Bool {
        switch self {
        case .search: return true
        case .chat: return true
        case .note: return false  // 笔记Tab使用专门的语音笔记功能
        }
    }
}

// MARK: - 统一输入框组件

struct UnifiedInputBar: View {
    let mode: InputBarMode
    @Binding var text: String
    @Binding var pendingImage: UIImage?
    let isLoading: Bool
    let onSend: (String, UIImage?) -> Void
    var onImagePick: (() -> Void)? = nil
    var onCurrentPageCapture: (() -> Void)? = nil  // 截取当前页
    var onRegionCapture: (() -> Void)? = nil  // 区域截图
    var onVoiceNote: (() -> Void)? = nil  // 语音笔记（仅笔记Tab）
    var specialButton: AnyView? = nil  // 特殊按钮（如"深入学习本页"）

    @FocusState private var isFocused: Bool
    @StateObject private var voiceService = VoiceInputService.shared
    @State private var showVoiceOverlay = false

    var body: some View {
        VStack(spacing: 0) {
            // 图片预览区
            if let image = pendingImage {
                imagePreview(image)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // 特殊按钮区（如"深入学习本页"）
            if let button = specialButton {
                button
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // 主输入区
            HStack(spacing: 10) {
                // 左侧图标/按钮组
                leftButtons

                // 输入框
                TextField(mode.placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .onSubmit { submitIfReady() }

                // 清除按钮
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }

                // 语音输入按钮（search和chat模式）
                if mode.supportsVoiceInput && text.isEmpty && pendingImage == nil {
                    voiceInputButton
                }

                // 发送按钮
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(24)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showVoiceOverlay) {
            VoiceInputSheet(
                service: voiceService,
                onTextReceived: { receivedText in
                    text = receivedText
                },
                onDismiss: {
                    showVoiceOverlay = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 左侧按钮组

    @ViewBuilder
    private var leftButtons: some View {
        HStack(spacing: 8) {
            // 模式图标
            Image(systemName: mode.icon)
                .font(.system(size: 18))
                .foregroundColor(mode.accentColor)

            // 语音笔记按钮（仅笔记模式）
            if mode == .note, let onVoice = onVoiceNote {
                Button {
                    onVoice()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
            }

            // 图片选择按钮（仅chat和note模式）
            if mode != .search {
                Menu {
                    // 区域截图（框选）
                    if let onRegion = onRegionCapture {
                        Button {
                            onRegion()
                        } label: {
                            Label("框选截图", systemImage: "rectangle.dashed")
                        }
                    }

                    // 截取当前页
                    if let onCapture = onCurrentPageCapture {
                        Button {
                            onCapture()
                        } label: {
                            Label("整页截图", systemImage: "doc.viewfinder")
                        }
                    }

                    Divider()

                    // 从相册选择
                    if let onPick = onImagePick {
                        Button {
                            onPick()
                        } label: {
                            Label("从相册选择", systemImage: "photo.on.rectangle")
                        }
                    }
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 发送按钮

    private var sendButton: some View {
        Button(action: submitIfReady) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: mode.sendIcon)
                    .font(.system(size: 28))
                    .foregroundColor(canSubmit ? mode.accentColor : .gray.opacity(0.5))
            }
        }
        .disabled(!canSubmit || isLoading)
    }

    // MARK: - 图片预览

    private func imagePreview(_ image: UIImage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Button {
                pendingImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - 辅助方法

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImage != nil
    }

    private func submitIfReady() {
        guard canSubmit else { return }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSend(trimmedText, pendingImage)
        text = ""
        pendingImage = nil
        isFocused = false
    }

    // MARK: - 语音输入按钮

    private var voiceInputButton: some View {
        Button {
            showVoiceOverlay = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 18))
                .foregroundColor(mode.accentColor)
        }
    }
}

// MARK: - 语音输入Sheet

struct VoiceInputSheet: View {
    @ObservedObject var service: VoiceInputService
    let onTextReceived: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 状态显示
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

                    // 离线状态
                    if service.isOfflineAvailable {
                        Label("离线识别", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // 时长
                Text(VoiceInputService.formatDuration(service.recordingDuration))
                    .font(.system(size: 36, weight: .light, design: .monospaced))

                // 波形
                if service.state == .recording {
                    VoiceWaveformView(level: service.audioLevel)
                        .frame(height: 50)
                        .padding(.horizontal, 40)
                }

                // 实时转写
                if !service.transcribedText.isEmpty {
                    ScrollView {
                        Text(service.transcribedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(maxHeight: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // 操作按钮
                HStack(spacing: 40) {
                    // 取消
                    Button {
                        service.cancel()
                        onDismiss()
                    } label: {
                        Text("取消")
                            .foregroundColor(.secondary)
                    }

                    // 主按钮
                    Button {
                        toggleRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 4)
                                .frame(width: 70, height: 70)

                            if service.state == .recording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 56, height: 56)
                            }
                        }
                    }

                    // 完成
                    Button {
                        finishRecording()
                    } label: {
                        Text("完成")
                            .fontWeight(.semibold)
                            .foregroundColor(service.transcribedText.isEmpty ? .gray : .appPrimary)
                    }
                    .disabled(service.transcribedText.isEmpty)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationTitle("语音输入")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusText: String {
        switch service.state {
        case .idle: return "点击开始"
        case .requesting: return "请求权限..."
        case .recording: return "正在识别"
        case .recognizing: return "识别中..."
        case .finished: return "识别完成"
        case .error(let error): return error.localizedDescription
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

    private func finishRecording() {
        let text = service.transcribedText
        service.reset()
        onDismiss()
        if !text.isEmpty {
            onTextReceived(text)
        }
    }
}

// MARK: - 深入学习本页按钮

struct DeepLearnButton: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "book.pages")
                        .font(.system(size: 14))
                }
                Text("深入学习本页")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
        }
        .disabled(isLoading)
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()

        // 搜索模式
        UnifiedInputBar(
            mode: .search,
            text: .constant(""),
            pendingImage: .constant(nil),
            isLoading: false,
            onSend: { _, _ in }
        )

        Divider()

        // 聊天模式（带特殊按钮）
        UnifiedInputBar(
            mode: .chat,
            text: .constant(""),
            pendingImage: .constant(nil),
            isLoading: false,
            onSend: { _, _ in },
            onImagePick: {},
            onCurrentPageCapture: {},
            onRegionCapture: {},
            specialButton: AnyView(
                DeepLearnButton(isLoading: false, onTap: {})
            )
        )

        Divider()

        // 笔记模式
        UnifiedInputBar(
            mode: .note,
            text: .constant("这是一条笔记"),
            pendingImage: .constant(nil),
            isLoading: false,
            onSend: { _, _ in },
            onImagePick: {}
        )
    }
    .background(Color(.systemGroupedBackground))
}
