//
//  HeavyOperationGuard.swift
//  pinghu12250
//
//  高危操作守卫 - PDF/Camera 等重量级操作的安全加载
//
//  【核心原则】
//  1. 所有重量级操作必须先占位 UI，后异步加载
//  2. 禁止在 View init / body 中直接触发 PDF render / AVCaptureSession start
//  3. 操作超时必须有回退机制
//

import SwiftUI
@preconcurrency import PDFKit
import AVFoundation

// MARK: - Unsafe Sendable Wrapper for PDFKit

/// 包装器：绕过 PDFKit 类型的 Sendable 检查
/// PDFKit 在 iOS SDK 中不符合 Sendable，但实际使用中是线程安全的
struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - HeavyOperationGuard

/// 高危操作守卫
/// 封装 PDF、Camera 等可能导致 UI 冻结的操作
final class HeavyOperationGuard {
    static let shared = HeavyOperationGuard()

    private init() {}

    // MARK: - PDF 安全加载

    /// 安全加载 PDF 文档（异步 + 超时 + 回退）
    func loadPDFSafely(
        from url: URL,
        timeout: TimeInterval = 30,
        context: String = "PDF"
    ) async -> Result<PDFDocument, HeavyOperationError> {
        // 标记进入危险区域
        StateSanityChecker.shared.markDangerousEntry(screen: "PDFLoader", context: context)

        defer {
            StateSanityChecker.shared.markSafeExit()
        }

        return await withTaskGroup(of: UnsafeSendableWrapper<PDFDocument?>.self) { group in
            // 添加实际加载任务
            group.addTask {
                let doc = await self.loadPDFInBackground(url: url)
                return UnsafeSendableWrapper(doc)
            }

            // 添加超时任务
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return UnsafeSendableWrapper(nil)
            }

            // 等待第一个完成的任务
            for await result in group {
                group.cancelAll()

                if let document = result.value {
                    appLog("[HeavyOp] PDF 加载成功: \(url.lastPathComponent)")
                    return .success(document)
                } else {
                    appLog("[HeavyOp] PDF 加载超时或失败: \(url.lastPathComponent)")
                    recordFailure(operation: "PDF", url: url.absoluteString, context: context)
                    return .failure(.timeout)
                }
            }

            return .failure(.unknown)
        }
    }

    private func loadPDFInBackground(url: URL) async -> PDFDocument? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let document = PDFDocument(url: url)
                continuation.resume(returning: document)
            }
        }
    }

    // MARK: - PDF 页面渲染

    /// 安全渲染 PDF 页面
    func renderPDFPageSafely(
        _ page: PDFPage,
        size: CGSize,
        scale: CGFloat = 1.0,
        context: String = "PDFRender"
    ) async -> UIImage? {
        // 验证尺寸
        let safeSize = RangeGuard.guardSize(
            size,
            minWidth: 1,
            minHeight: 1,
            default: CGSize(width: 100, height: 100),
            context: context
        )

        guard safeSize.width > 0 && safeSize.height > 0 else {
            appLog("[HeavyOp] PDF 渲染尺寸无效: \(size)")
            return nil
        }

        nonisolated(unsafe) let capturedPage = page
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let pageRect = capturedPage.bounds(for: .mediaBox)

                // 验证 pageRect
                guard pageRect.width > 0 && pageRect.height > 0 &&
                      pageRect.width.isFinite && pageRect.height.isFinite else {
                    continuation.resume(returning: nil)
                    return
                }

                let renderer = UIGraphicsImageRenderer(size: safeSize)

                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: safeSize))

                    let scaleX = safeSize.width / pageRect.width
                    let scaleY = safeSize.height / pageRect.height
                    let finalScale = min(scaleX, scaleY)

                    ctx.cgContext.translateBy(x: 0, y: safeSize.height)
                    ctx.cgContext.scaleBy(x: finalScale, y: -finalScale)

                    capturedPage.draw(with: .mediaBox, to: ctx.cgContext)
                }

                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Camera 安全启动

    /// 检查 Camera 权限并安全启动
    func checkCameraPermissionSafely() async -> CameraPermissionResult {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return .authorized

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied

        case .denied, .restricted:
            return .denied

        @unknown default:
            return .denied
        }
    }

    /// 安全创建 Camera Session
    func createCameraSessionSafely(
        position: AVCaptureDevice.Position = .back
    ) async -> Result<AVCaptureSession, HeavyOperationError> {
        // 标记进入危险区域
        StateSanityChecker.shared.markDangerousEntry(screen: "CameraSession", context: "createSession")

        defer {
            StateSanityChecker.shared.markSafeExit()
        }

        // 检查权限
        let permission = await checkCameraPermissionSafely()
        guard permission == .authorized else {
            return .failure(.permissionDenied)
        }

        // 在后台线程创建 Session
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                    continuation.resume(returning: .failure(.deviceNotFound))
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    let session = AVCaptureSession()

                    session.beginConfiguration()
                    if session.canAddInput(input) {
                        session.addInput(input)
                    }
                    session.commitConfiguration()

                    continuation.resume(returning: .success(session))
                } catch {
                    appLog("[HeavyOp] Camera Session 创建失败: \(error)")
                    continuation.resume(returning: .failure(.configurationFailed))
                }
            }
        }
    }

    // MARK: - 通用异步操作包装

    /// 包装任意重量级操作
    func performHeavyOperation<T>(
        name: String,
        timeout: TimeInterval = 10,
        operation: @escaping () async throws -> T
    ) async -> Result<T, HeavyOperationError> {
        StateSanityChecker.shared.markDangerousEntry(screen: name, context: "heavyOp")

        defer {
            StateSanityChecker.shared.markSafeExit()
        }

        do {
            let result = try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    try await operation()
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw HeavyOperationError.timeout
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            return .success(result)
        } catch let error as HeavyOperationError {
            return .failure(error)
        } catch {
            return .failure(.operationFailed(error.localizedDescription))
        }
    }

    // MARK: - 诊断

    private func recordFailure(operation: String, url: String, context: String) {
        let snapshot = FreezeSnapshot.capture(
            reason: "HeavyOperation failed: \(operation) - \(context)",
            level: .level1_snapshot,
            currentScreen: context
        )
        FreezeSnapshotStorage.shared.save(snapshot)
    }
}

// MARK: - Error Types

enum HeavyOperationError: LocalizedError {
    case timeout
    case permissionDenied
    case deviceNotFound
    case configurationFailed
    case operationFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .timeout: return "操作超时"
        case .permissionDenied: return "权限被拒绝"
        case .deviceNotFound: return "设备未找到"
        case .configurationFailed: return "配置失败"
        case .operationFailed(let msg): return "操作失败: \(msg)"
        case .unknown: return "未知错误"
        }
    }
}

enum CameraPermissionResult {
    case authorized
    case denied
}

// MARK: - SafePDFView

/// 安全 PDF 视图
/// 自动处理异步加载和错误状态
struct SafePDFView: View {
    let url: URL
    let pageIndex: Int
    let size: CGSize

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                // 占位 UI
                VStack(spacing: 12) {
                    ProgressView()
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: size.width, height: size.height)
                .background(Color.gray.opacity(0.1))
            } else if let error = error {
                // 错误 UI
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: size.width, height: size.height)
                .background(Color.gray.opacity(0.1))
            }
        }
        .task {
            await loadPage()
        }
    }

    private func loadPage() async {
        isLoading = true

        // 安全加载 PDF
        let result = await HeavyOperationGuard.shared.loadPDFSafely(from: url, context: "SafePDFView")

        switch result {
        case .success(let document):
            if let page = document.page(at: pageIndex) {
                image = await HeavyOperationGuard.shared.renderPDFPageSafely(
                    page,
                    size: size,
                    context: "SafePDFView"
                )
                if image == nil {
                    error = "页面渲染失败"
                }
            } else {
                error = "页面不存在"
            }

        case .failure(let operationError):
            error = operationError.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - LazyHeavyView

/// 延迟加载的重量级视图容器
/// 在视图真正可见时才开始加载
struct LazyHeavyView<Content: View, Placeholder: View>: View {
    let content: () -> Content
    let placeholder: () -> Placeholder
    let loadDelay: TimeInterval

    @State private var isReady = false

    init(
        loadDelay: TimeInterval = 0.3,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.loadDelay = loadDelay
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if isReady {
                content()
            } else {
                placeholder()
            }
        }
        .task {
            // 延迟加载，让 UI 先显示占位
            try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
            withAnimation {
                isReady = true
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// 将视图包装为延迟加载
    func lazyLoad(
        delay: TimeInterval = 0.3,
        placeholder: some View = ProgressView()
    ) -> some View {
        LazyHeavyView(loadDelay: delay) {
            self
        } placeholder: {
            placeholder
        }
    }
}
