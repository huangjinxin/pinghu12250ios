//
//  DownloadProgressView.swift
//  pinghu12250
//
//  可复用的下载进度视图组件
//

import SwiftUI

// MARK: - 下载进度卡片（大）

struct DownloadProgressCard: View {
    @ObservedObject var task: DownloadTask
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                switch task.state {
                case .downloading:
                    // 进度圆环
                    Circle()
                        .stroke(Color.appPrimary.opacity(0.2), lineWidth: 4)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: task.state.progress)
                        .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: task.state.progress)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.appPrimary)

                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                case .paused:
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                default:
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }

            // 状态文字
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)

                if case .downloading = task.state {
                    Text(task.progressText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !task.speedText.isEmpty {
                        HStack(spacing: 8) {
                            Text(task.speedText)
                                .foregroundColor(.appPrimary)

                            if !task.estimatedTimeRemaining.isEmpty {
                                Text("·")
                                Text("剩余 \(task.estimatedTimeRemaining)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            // 进度条
            if case .downloading = task.state {
                ProgressView(value: task.state.progress)
                    .progressViewStyle(.linear)
                    .tint(.appPrimary)
                    .frame(width: 200)
            }

            // 操作按钮
            HStack(spacing: 16) {
                if case .failed = task.state {
                    Button {
                        onRetry?()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if case .downloading = task.state {
                    Button(role: .destructive) {
                        onCancel?()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var statusText: String {
        switch task.state {
        case .idle: return "等待中"
        case .waiting: return "准备下载..."
        case .downloading(let progress): return "下载中 \(Int(progress * 100))%"
        case .paused: return "已暂停"
        case .completed: return "下载完成"
        case .failed(let error): return "下载失败: \(error)"
        }
    }
}

// MARK: - 下载进度条（小）

struct DownloadProgressBar: View {
    @ObservedObject var task: DownloadTask
    var showDetails: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(height: 8)

                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * task.state.progress, height: 8)
                        .animation(.linear(duration: 0.2), value: task.state.progress)
                }
            }
            .frame(height: 8)

            // 详情
            if showDetails {
                HStack {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if case .downloading = task.state {
                        Text(task.speedText)
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }

    private var progressColor: Color {
        switch task.state {
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        default: return .appPrimary
        }
    }

    private var statusText: String {
        switch task.state {
        case .idle: return "等待中"
        case .waiting: return "准备下载..."
        case .downloading: return "\(Int(task.state.progress * 100))% · \(task.progressText)"
        case .paused: return "已暂停"
        case .completed: return "下载完成"
        case .failed: return "下载失败"
        }
    }
}

// MARK: - 下载按钮（带状态）

struct DownloadButton: View {
    let url: URL
    let fileName: String
    @State private var task: DownloadTask?
    var onComplete: ((URL) -> Void)?

    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 8) {
                if let task = task {
                    switch task.state {
                    case .downloading(let progress):
                        // 进度圆环
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 20, height: 20)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(-90))
                        }
                        Text("\(Int(progress * 100))%")

                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                        Text("已下载")

                    case .paused:
                        Image(systemName: "play.fill")
                        Text("继续")

                    case .failed:
                        Image(systemName: "arrow.clockwise")
                        Text("重试")

                    default:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("下载中")
                    }
                } else if downloadManager.isCached(url: url, fileName: fileName) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("已下载")
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text("下载")
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .disabled(task?.state.isDownloading == true)
    }

    private func handleTap() {
        if let task = task {
            switch task.state {
            case .paused:
                downloadManager.resume(taskId: task.id)
            case .failed:
                startDownload()
            case .completed(let url):
                onComplete?(url)
            default:
                break
            }
        } else if let cachedURL = downloadManager.getCachedFileURL(for: url, fileName: fileName) {
            onComplete?(cachedURL)
        } else {
            startDownload()
        }
    }

    private func startDownload() {
        task = downloadManager.download(url: url, fileName: fileName) { result in
            if case .success(let localURL) = result {
                onComplete?(localURL)
            }
        }
    }
}

// MARK: - 下载列表视图

struct DownloadListView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.activeTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("暂无下载任务")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(Array(downloadManager.activeTasks.values), id: \.id) { task in
                            DownloadTaskRow(task: task)
                        }
                    }
                }
            }
            .navigationTitle("下载管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !downloadManager.activeTasks.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                for task in downloadManager.activeTasks.values {
                                    downloadManager.cancel(taskId: task.id)
                                }
                            } label: {
                                Label("取消全部", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

struct DownloadTaskRow: View {
    @ObservedObject var task: DownloadTask
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // 操作按钮
                switch task.state {
                case .downloading:
                    Button {
                        downloadManager.pause(taskId: task.id)
                    } label: {
                        Image(systemName: "pause.fill")
                            .foregroundColor(.orange)
                    }

                case .paused:
                    Button {
                        downloadManager.resume(taskId: task.id)
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundColor(.appPrimary)
                    }

                case .failed:
                    Button {
                        downloadManager.resume(taskId: task.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.appPrimary)
                    }

                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                default:
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            DownloadProgressBar(task: task, showDetails: true)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                downloadManager.cancel(taskId: task.id)
            } label: {
                Label("取消", systemImage: "xmark")
            }
        }
    }
}

// MARK: - 预览

#Preview("下载进度卡片") {
    let task = DownloadTask(id: "test", url: URL(string: "https://example.com/test.pdf")!, fileName: "test.pdf")
    task.state = .downloading(progress: 0.65)
    task.bytesReceived = 3_500_000
    task.totalBytes = 5_242_880
    task.speed = 1_200_000

    return DownloadProgressCard(task: task)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("下载进度条") {
    let task = DownloadTask(id: "test", url: URL(string: "https://example.com/test.pdf")!, fileName: "test.pdf")
    task.state = .downloading(progress: 0.45)
    task.bytesReceived = 2_300_000
    task.totalBytes = 5_242_880
    task.speed = 800_000

    return VStack(spacing: 20) {
        DownloadProgressBar(task: task)
    }
    .padding()
}
