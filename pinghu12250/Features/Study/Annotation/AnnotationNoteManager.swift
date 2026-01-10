//
//  AnnotationNoteManager.swift
//  pinghu12250
//
//  批注与笔记关联管理器 - 管理 PDF 批注的保存和同步
//

import Foundation
import SwiftUI
import PencilKit
import Combine
import Network

// MARK: - 批注同步状态

enum AnnotationSyncStatus: String, Codable {
    case synced = "synced"           // 已同步
    case pending = "pending"         // 待同步
    case failed = "failed"           // 同步失败
}

// MARK: - 页面批注笔记数据模型

struct PageAnnotationNote: Codable, Identifiable {
    let id: UUID
    let textbookId: String
    let pageIndex: Int
    var drawingData: Data
    var ocrText: String?
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: AnnotationSyncStatus
    var serverId: String?  // 服务器端的 ID

    init(
        id: UUID = UUID(),
        textbookId: String,
        pageIndex: Int,
        drawingData: Data,
        ocrText: String? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: AnnotationSyncStatus = .pending,
        serverId: String? = nil
    ) {
        self.id = id
        self.textbookId = textbookId
        self.pageIndex = pageIndex
        self.drawingData = drawingData
        self.ocrText = ocrText
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.serverId = serverId
    }

    /// 关联的笔记 ID（与 id 相同，便于查找）
    var noteId: UUID { id }

    /// 获取 PKDrawing
    var drawing: PKDrawing? {
        try? PKDrawing(data: drawingData)
    }

    /// 获取缩略图
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    /// 是否为空批注
    var isEmpty: Bool {
        if let drawing = drawing {
            return drawing.strokes.isEmpty
        }
        return true
    }
}

// MARK: - 批注与笔记关联管理器

/// 批注与笔记关联管理器
/// 职责：管理批注的保存/加载/同步，每页只有一个批注笔记
@MainActor
class AnnotationNoteManager: ObservableObject {
    static let shared = AnnotationNoteManager()

    // MARK: - Published Properties

    @Published var pageAnnotations: [String: PageAnnotationNote] = [:]  // key: textbookId_pageIndex
    @Published var isSaving = false
    @Published var isSyncing = false
    @Published var lastSaveTime: Date?
    @Published var lastSyncTime: Date?
    @Published var pendingSyncCount = 0

    // MARK: - Dependencies

    private let ocrService = OCRService.shared
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "AnnotationNetworkMonitor")
    private var isOnline = true

    // MARK: - Storage Keys

    private let localStorageKey = "pdf_annotation_notes"
    private let syncMetadataKey = "pdf_annotation_sync_metadata"

    private init() {
        loadLocalAnnotations()
        setupNetworkMonitoring()
        updatePendingCount()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // 网络恢复时自动同步
                if wasOffline && path.status == .satisfied {
                    #if DEBUG
                    print("[AnnotationNoteManager] Network restored, syncing pending annotations...")
                    #endif
                    await self?.syncPendingAnnotations()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public Methods

    /// 生成批注 key
    func annotationKey(textbookId: String, pageIndex: Int) -> String {
        "\(textbookId)_\(pageIndex)"
    }

    /// 获取指定页的批注（如果存在）
    func getAnnotation(textbookId: String, pageIndex: Int) -> PageAnnotationNote? {
        let key = annotationKey(textbookId: textbookId, pageIndex: pageIndex)
        return pageAnnotations[key]
    }

    /// 获取指定页的 PKDrawing
    func getDrawing(textbookId: String, pageIndex: Int) -> PKDrawing? {
        getAnnotation(textbookId: textbookId, pageIndex: pageIndex)?.drawing
    }

    /// 检查指定页是否有批注
    func hasAnnotation(textbookId: String, pageIndex: Int) -> Bool {
        guard let annotation = getAnnotation(textbookId: textbookId, pageIndex: pageIndex) else {
            return false
        }
        return !annotation.isEmpty
    }

    /// 获取教材的所有批注页码
    func getAnnotatedPages(for textbookId: String) -> [Int] {
        pageAnnotations
            .filter { $0.key.hasPrefix("\(textbookId)_") && !$0.value.isEmpty }
            .map { $0.value.pageIndex }
            .sorted()
    }

    /// 保存或更新批注
    /// - Note: performOCR 默认关闭，识别由用户主动触发"保存到笔记"时进行
    func saveAnnotation(
        drawing: PKDrawing,
        textbookId: String,
        pageIndex: Int,
        performOCR: Bool = false
    ) async {
        let key = annotationKey(textbookId: textbookId, pageIndex: pageIndex)

        // 如果绘图为空，删除批注
        if drawing.strokes.isEmpty {
            await deleteAnnotation(textbookId: textbookId, pageIndex: pageIndex)
            return
        }

        isSaving = true
        defer { isSaving = false }

        // 1. 将绘图转换为数据
        let drawingData = drawing.dataRepresentation()

        // 2. 生成缩略图
        let bounds = drawing.bounds.insetBy(dx: -10, dy: -10)
        let thumbnailImage = drawing.image(from: bounds, scale: 1.0)
        let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.6)

        // 3. OCR 识别（异步）
        var ocrText: String? = nil
        if performOCR {
            let recognitionImage = drawing.image(from: bounds, scale: 2.0)
            ocrText = await ocrService.recognizeText(from: recognitionImage)
        }

        // 4. 查找或创建批注笔记
        let now = Date()
        if var existing = pageAnnotations[key] {
            // 更新现有批注
            existing.drawingData = drawingData
            existing.ocrText = ocrText
            existing.thumbnailData = thumbnailData
            existing.updatedAt = now
            existing.syncStatus = .pending  // 标记为待同步
            pageAnnotations[key] = existing

            // 同步更新到 NotesManager
            await updateNoteForAnnotation(existing)

            // 尝试同步到服务器
            await syncAnnotationToServer(existing)
        } else {
            // 创建新批注
            let annotation = PageAnnotationNote(
                id: UUID(),
                textbookId: textbookId,
                pageIndex: pageIndex,
                drawingData: drawingData,
                ocrText: ocrText,
                thumbnailData: thumbnailData,
                createdAt: now,
                updatedAt: now,
                syncStatus: .pending
            )
            pageAnnotations[key] = annotation

            // 创建对应的笔记
            await createNoteForAnnotation(annotation)

            // 尝试同步到服务器
            await syncAnnotationToServer(annotation)
        }

        // 5. 保存到本地
        saveLocalAnnotations()
        lastSaveTime = now
        updatePendingCount()
    }

    /// 删除批注
    func deleteAnnotation(textbookId: String, pageIndex: Int) async {
        let key = annotationKey(textbookId: textbookId, pageIndex: pageIndex)

        if let annotation = pageAnnotations[key] {
            // 从服务器删除
            await deleteAnnotationFromServer(annotation)

            // 删除对应的笔记
            NotesManager.shared.deleteNote(annotation.noteId)
            pageAnnotations.removeValue(forKey: key)
            saveLocalAnnotations()
            updatePendingCount()
        }
    }

    /// 清除某教材的所有批注
    func clearAnnotations(for textbookId: String) async {
        let keysToRemove = pageAnnotations.keys.filter { $0.hasPrefix("\(textbookId)_") }
        for key in keysToRemove {
            if let annotation = pageAnnotations[key] {
                await deleteAnnotationFromServer(annotation)
                NotesManager.shared.deleteNote(annotation.noteId)
            }
            pageAnnotations.removeValue(forKey: key)
        }
        saveLocalAnnotations()
        updatePendingCount()
    }

    /// 从服务器加载批注
    func loadAnnotationsFromServer(for textbookId: String) async {
        guard let token = APIService.shared.authToken else { return }

        do {
            guard let url = URL(string: "\(APIConfig.baseURL)/textbook-annotations/\(textbookId)") else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct ServerResponse: Codable {
                let success: Bool
                let data: ResponseData?

                struct ResponseData: Codable {
                    let annotations: [ServerAnnotation]
                    let pages: [Int]
                }

                struct ServerAnnotation: Codable {
                    let id: String
                    let page: Int
                    let snippet: String?
                    let createdAt: String
                }
            }

            let serverResponse = try decoder.decode(ServerResponse.self, from: data)

            if let annotations = serverResponse.data?.annotations {
                for serverAnnotation in annotations {
                    // 加载每个批注的详细数据
                    await loadSingleAnnotationFromServer(
                        textbookId: textbookId,
                        page: serverAnnotation.page,
                        serverId: serverAnnotation.id
                    )
                }
            }

            #if DEBUG
            print("[AnnotationNoteManager] Loaded annotations from server for textbook: \(textbookId)")
            #endif
        } catch {
            #if DEBUG
            print("[AnnotationNoteManager] Failed to load annotations from server: \(error)")
            #endif
        }
    }

    /// 同步所有待同步的批注
    func syncPendingAnnotations() async {
        guard isOnline else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let pendingAnnotations = pageAnnotations.values.filter { $0.syncStatus == .pending }

        for annotation in pendingAnnotations {
            await syncAnnotationToServer(annotation)
        }

        lastSyncTime = Date()
        updatePendingCount()
    }

    // MARK: - Private Methods - Server Sync

    private func syncAnnotationToServer(_ annotation: PageAnnotationNote) async {
        guard isOnline else { return }
        guard let token = APIService.shared.authToken else {
            markAsPending(annotation)
            return
        }

        do {
            let urlString = "\(APIConfig.baseURL)/textbook-annotations/\(annotation.textbookId)/\(annotation.pageIndex)"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            // 构建请求体
            let body: [String: Any] = [
                "drawingData": annotation.drawingData.base64EncodedString(),
                "ocrText": annotation.ocrText ?? "",
                "thumbnailData": annotation.thumbnailData?.base64EncodedString() ?? ""
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 200 {
                // 解析服务器返回的 ID
                struct ServerResponse: Codable {
                    let success: Bool
                    let data: ResponseData?

                    struct ResponseData: Codable {
                        let id: String
                    }
                }

                if let serverResponse = try? JSONDecoder().decode(ServerResponse.self, from: data),
                   let serverId = serverResponse.data?.id {
                    markAsSynced(annotation, serverId: serverId)
                } else {
                    markAsSynced(annotation, serverId: nil)
                }

                #if DEBUG
                print("[AnnotationNoteManager] Synced annotation to server: P\(annotation.pageIndex + 1)")
                #endif
            } else {
                markAsFailed(annotation)
                #if DEBUG
                print("[AnnotationNoteManager] Failed to sync annotation: HTTP \(httpResponse.statusCode)")
                #endif
            }
        } catch {
            markAsFailed(annotation)
            #if DEBUG
            print("[AnnotationNoteManager] Failed to sync annotation: \(error)")
            #endif
        }
    }

    private func deleteAnnotationFromServer(_ annotation: PageAnnotationNote) async {
        guard isOnline else { return }
        guard let token = APIService.shared.authToken else { return }

        do {
            let urlString = "\(APIConfig.baseURL)/textbook-annotations/\(annotation.textbookId)/\(annotation.pageIndex)"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                #if DEBUG
                print("[AnnotationNoteManager] Deleted annotation from server: P\(annotation.pageIndex + 1)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[AnnotationNoteManager] Failed to delete annotation from server: \(error)")
            #endif
        }
    }

    private func loadSingleAnnotationFromServer(textbookId: String, page: Int, serverId: String) async {
        guard let token = APIService.shared.authToken else { return }

        do {
            let urlString = "\(APIConfig.baseURL)/textbook-annotations/\(textbookId)/\(page)"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            struct ServerResponse: Codable {
                let success: Bool
                let data: AnnotationData?

                struct AnnotationData: Codable {
                    let id: String
                    let content: ContentData?
                    let snippet: String?
                    let createdAt: String

                    struct ContentData: Codable {
                        let drawingData: String?
                        let ocrText: String?
                        let thumbnailData: String?
                    }
                }
            }

            let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)

            if let annotationData = serverResponse.data,
               let content = annotationData.content,
               let drawingDataString = content.drawingData,
               let drawingData = Data(base64Encoded: drawingDataString) {

                let key = annotationKey(textbookId: textbookId, pageIndex: page - 1)

                // 如果本地有更新的版本，跳过
                if let local = pageAnnotations[key], local.updatedAt > Date() {
                    return
                }

                let thumbnailData = content.thumbnailData.flatMap { Data(base64Encoded: $0) }

                let annotation = PageAnnotationNote(
                    id: UUID(),
                    textbookId: textbookId,
                    pageIndex: page - 1,
                    drawingData: drawingData,
                    ocrText: content.ocrText,
                    thumbnailData: thumbnailData,
                    createdAt: ISO8601DateFormatter().date(from: annotationData.createdAt) ?? Date(),
                    updatedAt: Date(),
                    syncStatus: .synced,
                    serverId: annotationData.id
                )

                pageAnnotations[key] = annotation
                saveLocalAnnotations()
            }
        } catch {
            #if DEBUG
            print("[AnnotationNoteManager] Failed to load single annotation: \(error)")
            #endif
        }
    }

    // MARK: - Private Methods - Sync Status

    private func markAsSynced(_ annotation: PageAnnotationNote, serverId: String?) {
        let key = annotationKey(textbookId: annotation.textbookId, pageIndex: annotation.pageIndex)
        if var existing = pageAnnotations[key] {
            existing.syncStatus = .synced
            existing.serverId = serverId
            pageAnnotations[key] = existing
            saveLocalAnnotations()
            updatePendingCount()
        }
    }

    private func markAsPending(_ annotation: PageAnnotationNote) {
        let key = annotationKey(textbookId: annotation.textbookId, pageIndex: annotation.pageIndex)
        if var existing = pageAnnotations[key] {
            existing.syncStatus = .pending
            pageAnnotations[key] = existing
            saveLocalAnnotations()
            updatePendingCount()
        }
    }

    private func markAsFailed(_ annotation: PageAnnotationNote) {
        let key = annotationKey(textbookId: annotation.textbookId, pageIndex: annotation.pageIndex)
        if var existing = pageAnnotations[key] {
            existing.syncStatus = .failed
            pageAnnotations[key] = existing
            saveLocalAnnotations()
            updatePendingCount()
        }
    }

    private func updatePendingCount() {
        pendingSyncCount = pageAnnotations.values.filter { $0.syncStatus == .pending }.count
    }

    // MARK: - Private Methods - Note Integration

    /// 创建批注对应的笔记
    private func createNoteForAnnotation(_ annotation: PageAnnotationNote) async {
        let attachment = NoteAttachment(
            id: UUID(),
            type: .drawing,
            data: annotation.drawingData,
            url: nil
        )

        let note = StudyNote(
            id: annotation.noteId,
            textbookId: annotation.textbookId,
            pageIndex: annotation.pageIndex,
            title: "批注 P\(annotation.pageIndex + 1)",
            content: annotation.ocrText ?? "手写批注",
            type: .handwriting,
            tags: ["批注"],
            color: .default,
            createdAt: annotation.createdAt,
            updatedAt: annotation.updatedAt,
            isFavorite: false,
            attachments: [attachment],
            isResolved: false
        )

        NotesManager.shared.createNote(note)
    }

    /// 更新批注对应的笔记
    private func updateNoteForAnnotation(_ annotation: PageAnnotationNote) async {
        let attachment = NoteAttachment(
            id: UUID(),
            type: .drawing,
            data: annotation.drawingData,
            url: nil
        )

        let note = StudyNote(
            id: annotation.noteId,
            textbookId: annotation.textbookId,
            pageIndex: annotation.pageIndex,
            title: "批注 P\(annotation.pageIndex + 1)",
            content: annotation.ocrText ?? "手写批注",
            type: .handwriting,
            tags: ["批注"],
            color: .default,
            createdAt: annotation.createdAt,
            updatedAt: annotation.updatedAt,
            isFavorite: false,
            attachments: [attachment],
            isResolved: false
        )

        NotesManager.shared.updateNote(note)
    }

    // MARK: - Local Storage

    private func loadLocalAnnotations() {
        guard let data = UserDefaults.standard.data(forKey: localStorageKey),
              let decoded = try? JSONDecoder().decode([String: PageAnnotationNote].self, from: data) else {
            return
        }
        pageAnnotations = decoded
        updatePendingCount()
        #if DEBUG
        print("[AnnotationNoteManager] Loaded \(pageAnnotations.count) annotations from local storage")
        #endif
    }

    private func saveLocalAnnotations() {
        guard let data = try? JSONEncoder().encode(pageAnnotations) else {
            #if DEBUG
            print("[AnnotationNoteManager] Failed to encode annotations")
            #endif
            return
        }
        UserDefaults.standard.set(data, forKey: localStorageKey)
        #if DEBUG
        print("[AnnotationNoteManager] Saved \(pageAnnotations.count) annotations to local storage")
        #endif
    }
}
