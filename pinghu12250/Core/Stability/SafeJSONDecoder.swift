//
//  SafeJSONDecoder.swift
//  pinghu12250
//
//  安全 JSON 解码器 - 熔断式错误处理
//  防止 JSON 解码失败导致 App 崩溃或进入非受控状态
//
//  【核心原则】
//  1. 所有解码失败不允许 throw 传播到 UI
//  2. 解码失败必须转换为空状态或降级状态
//  3. 记录 JSONDecodeFailureSnapshot 用于诊断
//

import Foundation

// MARK: - SafeJSONDecoder

/// 安全 JSON 解码器
/// 封装 JSONDecoder 并提供熔断式错误处理
final class SafeJSONDecoder {
    static let shared = SafeJSONDecoder()

    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - 基础解码（返回 Optional）

    /// 安全解码，失败时返回 nil 并记录诊断
    func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> T? {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            recordFailure(
                type: String(describing: type),
                error: error,
                data: data,
                context: context,
                file: file,
                line: line
            )
            return nil
        }
    }

    /// 安全解码，失败时返回默认值
    func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        default defaultValue: T,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> T {
        return decode(type, from: data, context: context, file: file, line: line) ?? defaultValue
    }

    // MARK: - 数组解码（容错模式）

    /// 安全解码数组，跳过无效元素
    /// 对于 [Element] 类型，即使部分元素解析失败也能返回成功的元素
    func decodeArray<Element: Decodable>(
        _ type: [Element].Type,
        from data: Data,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> [Element] {
        // 首先尝试正常解码
        if let result = decode(type, from: data, context: context, file: file, line: line) {
            return result
        }

        // 如果失败，尝试逐个解码
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            var results: [Element] = []

            for (index, item) in jsonArray.enumerated() {
                do {
                    let itemData = try JSONSerialization.data(withJSONObject: item)
                    if let element = try? decoder.decode(Element.self, from: itemData) {
                        results.append(element)
                    } else {
                        recordPartialFailure(
                            arrayType: String(describing: type),
                            index: index,
                            item: item,
                            context: context,
                            file: file,
                            line: line
                        )
                    }
                } catch {
                    // 单个元素序列化失败，跳过
                }
            }

            return results
        } catch {
            return []
        }
    }

    // MARK: - 字典解码（容错模式）

    /// 安全解码字典
    func decodeDictionary<Value: Decodable>(
        _ type: [String: Value].Type,
        from data: Data,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> [String: Value] {
        return decode(type, from: data, default: [:], context: context, file: file, line: line)
    }

    // MARK: - 诊断记录

    private func recordFailure(
        type: String,
        error: Error,
        data: Data,
        context: String,
        file: String,
        line: Int
    ) {
        let snapshot = JSONDecodeFailureSnapshot(
            timestamp: Date(),
            targetType: type,
            error: describeError(error),
            dataPreview: String(data: data.prefix(500), encoding: .utf8) ?? "Binary data",
            context: context,
            file: (file as NSString).lastPathComponent,
            line: line
        )

        JSONDecodeFailureStorage.shared.save(snapshot)

        // 同时记录 FreezeSnapshot
        let freezeSnapshot = FreezeSnapshot.capture(
            reason: "JSON decode failed: \(type) - \(describeError(error))",
            level: .none,
            currentScreen: context.isEmpty ? (file as NSString).lastPathComponent : context
        )
        FreezeSnapshotStorage.shared.save(freezeSnapshot)
    }

    private func recordPartialFailure(
        arrayType: String,
        index: Int,
        item: [String: Any],
        context: String,
        file: String,
        line: Int
    ) {
        let itemPreview = (try? JSONSerialization.data(withJSONObject: item))
            .flatMap { String(data: $0.prefix(200), encoding: .utf8) } ?? "Unknown"

        let snapshot = JSONDecodeFailureSnapshot(
            timestamp: Date(),
            targetType: "\(arrayType)[index=\(index)]",
            error: "Partial array decode failure",
            dataPreview: itemPreview,
            context: context,
            file: (file as NSString).lastPathComponent,
            line: line
        )

        JSONDecodeFailureStorage.shared.save(snapshot)
    }

    private func describeError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                return "keyNotFound: '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .valueNotFound(let type, let context):
                return "valueNotFound: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let context):
                return "typeMismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .dataCorrupted(let context):
                return "dataCorrupted: \(context.debugDescription)"
            @unknown default:
                return "unknown DecodingError"
            }
        }
        return error.localizedDescription
    }
}

// MARK: - JSONDecodeFailureSnapshot

/// JSON 解码失败快照
struct JSONDecodeFailureSnapshot: Codable {
    let id: String
    let timestamp: Date
    let targetType: String
    let error: String
    let dataPreview: String
    let context: String
    let file: String
    let line: Int

    init(
        timestamp: Date,
        targetType: String,
        error: String,
        dataPreview: String,
        context: String,
        file: String,
        line: Int
    ) {
        self.id = UUID().uuidString
        self.timestamp = timestamp
        self.targetType = targetType
        self.error = error
        self.dataPreview = dataPreview
        self.context = context
        self.file = file
        self.line = line
    }

    var formattedSummary: String {
        """
        === JSONDecodeFailure ===
        ID: \(id)
        时间: \(timestamp.formatted())
        目标类型: \(targetType)
        错误: \(error)
        上下文: \(context)
        位置: \(file):\(line)
        数据预览: \(dataPreview.prefix(100))...
        =========================
        """
    }
}

// MARK: - JSONDecodeFailureStorage

/// JSON 解码失败存储
final class JSONDecodeFailureStorage {
    static let shared = JSONDecodeFailureStorage()

    private let fileManager = FileManager.default
    private let maxSnapshots = 20

    private var storageDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documentsPath.appendingPathComponent("JSONDecodeFailures", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }

    private init() {}

    func save(_ snapshot: JSONDecodeFailureSnapshot) {
        let fileName = "json_failure_\(snapshot.id).json"
        let fileURL = storageDirectory.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL)

            appLog("[JSONDecode] 记录解码失败: \(snapshot.targetType) - \(snapshot.error)")

            cleanupOld()
        } catch {
            #if DEBUG
            print("[JSONDecodeFailure] 保存失败: \(error)")
            #endif
        }
    }

    func loadAll() -> [JSONDecodeFailureSnapshot] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { file -> JSONDecodeFailureSnapshot? in
                guard let data = try? Data(contentsOf: file) else { return nil }
                return try? decoder.decode(JSONDecodeFailureSnapshot.self, from: data)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func cleanupOld() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let sortedFiles = files
            .filter { $0.pathExtension == "json" }
            .sorted { url1, url2 in
                let date1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? .distantPast
                let date2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? .distantPast
                return date1 > date2
            }

        if sortedFiles.count > maxSnapshots {
            for file in sortedFiles.dropFirst(maxSnapshots) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func clearAll() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}

// MARK: - 安全解码扩展

extension Data {
    /// 安全解码为指定类型
    func safeDecode<T: Decodable>(
        _ type: T.Type,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> T? {
        SafeJSONDecoder.shared.decode(type, from: self, context: context, file: file, line: line)
    }

    /// 安全解码为指定类型，失败时返回默认值
    func safeDecode<T: Decodable>(
        _ type: T.Type,
        default defaultValue: T,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> T {
        SafeJSONDecoder.shared.decode(type, from: self, default: defaultValue, context: context, file: file, line: line)
    }

    /// 安全解码数组（容错模式）
    func safeDecodeArray<Element: Decodable>(
        _ type: [Element].Type,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> [Element] {
        SafeJSONDecoder.shared.decodeArray(type, from: self, context: context, file: file, line: line)
    }
}

// MARK: - Decodable 协议扩展（提供默认值）

/// 可降级解码协议
protocol SafeDecodable: Decodable {
    /// 解码失败时的降级状态
    static var degradedState: Self { get }
}

extension SafeJSONDecoder {
    /// 解码可降级类型，失败时返回降级状态
    func decodeSafe<T: SafeDecodable>(
        _ type: T.Type,
        from data: Data,
        context: String = "",
        file: String = #file,
        line: Int = #line
    ) -> T {
        return decode(type, from: data, default: T.degradedState, context: context, file: file, line: line)
    }
}

// MARK: - 常用类型的 SafeDecodable 实现

extension Array: SafeDecodable where Element: Decodable {
    static var degradedState: [Element] { [] }
}

extension Dictionary: SafeDecodable where Key == String, Value: Decodable {
    static var degradedState: [String: Value] { [:] }
}

extension Optional: SafeDecodable where Wrapped: Decodable {
    static var degradedState: Optional<Wrapped> { nil }
}
