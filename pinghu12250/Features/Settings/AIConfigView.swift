//
//  AIConfigView.swift
//  pinghu12250
//
//  AI配置展示视图（只读）- 从Web端同步配置
//

import SwiftUI
import Combine

// MARK: - AI配置视图

struct AIConfigView: View {
    @StateObject private var viewModel = AIConfigViewModel()

    var body: some View {
        List {
            // 加载状态
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if let error = viewModel.error {
                // 错误状态
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task { await viewModel.loadConfiguration() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                // API配置
                apiConfigSection

                // 连接测试
                connectionTestSection

                // 系统提示词
                systemPromptSection

                // 提示词模板
                promptTemplatesSection
            }

            // 说明
            Section {
                Label {
                    Text("AI配置需要在Web端工作台中设置")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("AI 配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.loadConfiguration() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadConfiguration()
        }
        .refreshable {
            await viewModel.loadConfiguration()
        }
    }

    // MARK: - API配置Section

    private var apiConfigSection: some View {
        Section {
            if let config = viewModel.apiConfig {
                LabeledContent("配置名称") {
                    Text(config.name)
                        .foregroundColor(.primary)
                }

                LabeledContent("模型") {
                    Text(config.model)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                LabeledContent("状态") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(config.isEnabled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(config.isEnabled ? "已启用" : "已禁用")
                            .font(.footnote)
                    }
                }

                if config.isDefault {
                    HStack {
                        Spacer()
                        Text("默认配置")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.orange)
                    Text("未配置AI API")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("AI API 配置", systemImage: "cpu")
        }
    }

    // MARK: - 连接测试Section

    private var connectionTestSection: some View {
        Section {
            // 测试按钮
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                HStack {
                    if viewModel.isTesting {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                    }
                    Text(viewModel.isTesting ? "测试中..." : "测试AI连接")
                        .foregroundColor(viewModel.isTesting ? .secondary : .blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(viewModel.isTesting)

            // 测试结果
            if let result = viewModel.testResult {
                switch result {
                case .success(let message, let latency):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("响应时间: \(Int(latency))ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                case .failure(let error, let details):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        if let details = details {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // 调试信息
            #if DEBUG
            VStack(alignment: .leading, spacing: 4) {
                Text("调试信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("baseURL: \(APIConfig.baseURL)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("已登录: \(APIService.shared.authToken != nil ? "是" : "否")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            #endif
        } header: {
            Label("连接测试", systemImage: "network")
        } footer: {
            Text("点击测试按钮检查AI服务连接状态")
        }
    }

    // MARK: - 系统提示词Section

    private var systemPromptSection: some View {
        Section {
            if let prompt = viewModel.systemPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.promptText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(5)

                    if !prompt.updatedAt.isEmpty {
                        Text("更新于: \(formatDate(prompt.updatedAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text("使用默认系统提示词")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("系统提示词", systemImage: "text.quote")
        }
    }

    // MARK: - 提示词模板Section

    private var promptTemplatesSection: some View {
        Section {
            if viewModel.promptTemplates.isEmpty {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                    Text("暂无自定义模板")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(viewModel.promptTemplates, id: \.id) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.subheadline)

                            if let subject = template.subject {
                                Text(subject)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if template.isDefault {
                            Text("默认")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        } header: {
            Label("提示词模板 (\(viewModel.promptTemplates.count))", systemImage: "list.bullet.rectangle")
        }
    }

    // MARK: - 辅助方法

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - ViewModel

@MainActor
class AIConfigViewModel: ObservableObject {
    @Published var apiConfig: AIApiConfig?
    @Published var systemPrompt: AISystemPrompt?
    @Published var promptTemplates: [AIPromptTemplate] = []
    @Published var isLoading = false
    @Published var error: String?

    // 连接测试状态
    @Published var isTesting = false
    @Published var testResult: TestResult?

    enum TestResult {
        case success(message: String, latency: Double)
        case failure(error: String, details: String?)
    }

    func loadConfiguration() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // 并行获取AI配置和提示词模板
            async let configTask = fetchAIConfig()
            async let promptsTask = fetchPromptTemplates()
            async let systemPromptTask = fetchSystemPrompt()

            let (config, templates, sysPrompt) = try await (configTask, promptsTask, systemPromptTask)

            self.apiConfig = config
            self.promptTemplates = templates
            self.systemPrompt = sysPrompt

        } catch {
            self.error = "加载配置失败: \(error.localizedDescription)"
        }
    }

    // MARK: - API 调用

    private func fetchAIConfig() async throws -> AIApiConfig? {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.aiConfig + "/active") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        // 解析响应: { success: true, data: { config: {...} } }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success,
           let dataObj = json["data"] as? [String: Any],
           let configObj = dataObj["config"] as? [String: Any] {
            return AIApiConfig(
                id: configObj["id"] as? String ?? "",
                name: configObj["name"] as? String ?? "未配置",
                baseUrl: configObj["baseUrl"] as? String ?? "",
                model: configObj["model"] as? String ?? "",
                isDefault: configObj["isDefault"] as? Bool ?? false,
                isEnabled: configObj["isEnabled"] as? Bool ?? true
            )
        }

        return nil
    }

    private func fetchPromptTemplates() async throws -> [AIPromptTemplate] {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.aiPrompts) else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        // 解析响应: { success: true, data: { prompts: [...] } }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success,
           let dataObj = json["data"] as? [String: Any],
           let promptsArray = dataObj["prompts"] as? [[String: Any]] {
            return promptsArray.compactMap { item in
                AIPromptTemplate(
                    id: item["id"] as? String ?? "",
                    name: item["name"] as? String ?? "",
                    subject: item["subject"] as? String,
                    isDefault: item["isDefault"] as? Bool ?? false
                )
            }
        }

        return []
    }

    private func fetchSystemPrompt() async throws -> AISystemPrompt? {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.aiPromptsSystem) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        // 解析响应: { success: true, data: { prompt: {...} } }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success,
           let dataObj = json["data"] as? [String: Any],
           let promptObj = dataObj["prompt"] as? [String: Any] {
            return AISystemPrompt(
                id: promptObj["id"] as? String ?? "",
                promptText: promptObj["promptText"] as? String ?? "",
                updatedAt: promptObj["updatedAt"] as? String ?? ""
            )
        }

        return nil
    }

    // MARK: - 连接测试

    func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        let startTime = Date()

        do {
            // Step 1: 检查 baseURL 配置
            let baseURL = APIConfig.baseURL
            #if DEBUG
            print("[AIConfig] Testing connection to: \(baseURL)")
            #endif

            // Step 2: 检查认证 token
            guard let token = APIService.shared.authToken else {
                testResult = .failure(
                    error: "未登录",
                    details: "请先登录账号后再测试AI连接"
                )
                return
            }

            // Step 3: 测试 AI 配置端点（直接测试，不用 health 端点）
            guard let configURL = URL(string: baseURL + APIConfig.Endpoints.aiConfig + "/active") else {
                testResult = .failure(error: "配置URL错误", details: nil)
                return
            }

            #if DEBUG
            print("[AIConfig] Testing config URL: \(configURL)")
            #endif

            var configRequest = URLRequest(url: configURL)
            configRequest.timeoutInterval = 15
            configRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (configData, configResponse) = try await URLSession.shared.data(for: configRequest)
            guard let httpConfig = configResponse as? HTTPURLResponse else {
                testResult = .failure(error: "配置请求失败", details: nil)
                return
            }

            #if DEBUG
            print("[AIConfig] Config response status: \(httpConfig.statusCode)")
            if let responseStr = String(data: configData, encoding: .utf8) {
                print("[AIConfig] Config response: \(responseStr.prefix(500))")
            }
            #endif

            if httpConfig.statusCode == 401 {
                testResult = .failure(error: "认证失败", details: "Token已过期，请重新登录")
                return
            }

            if httpConfig.statusCode == 404 {
                testResult = .failure(
                    error: "API端点不存在",
                    details: "后端可能需要更新，请检查 /ai-config/active 端点"
                )
                return
            }

            if httpConfig.statusCode != 200 {
                testResult = .failure(
                    error: "获取AI配置失败",
                    details: "HTTP \(httpConfig.statusCode)"
                )
                return
            }

            // 解析配置响应
            guard let json = try JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
                testResult = .failure(error: "响应解析失败", details: "非JSON格式")
                return
            }

            let success = json["success"] as? Bool ?? false
            if !success {
                let errorMsg = json["error"] as? String ?? "未知错误"
                testResult = .failure(error: "API返回失败", details: errorMsg)
                return
            }

            // 检查是否有配置
            guard let dataObj = json["data"] as? [String: Any],
                  let configObj = dataObj["config"] as? [String: Any] else {
                testResult = .failure(
                    error: "AI未配置",
                    details: "请在Web端工作台中配置AI API（设置 > AI配置）"
                )
                return
            }

            // Step 4: 尝试发送测试消息到 AI（可选，跳过以加快测试速度）
            let latency = Date().timeIntervalSince(startTime) * 1000 // ms
            let modelName = configObj["model"] as? String ?? "未知模型"
            let configName = configObj["name"] as? String ?? "默认配置"

            testResult = .success(
                message: "连接正常: \(configName) (\(modelName))",
                latency: latency
            )

        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                testResult = .failure(error: "连接超时", details: "请检查网络连接")
            case .notConnectedToInternet:
                testResult = .failure(error: "无网络连接", details: "请检查网络设置")
            case .cannotFindHost:
                testResult = .failure(error: "无法找到服务器", details: "请检查服务器地址: \(APIConfig.baseURL)")
            default:
                testResult = .failure(error: "网络错误", details: error.localizedDescription)
            }
        } catch {
            testResult = .failure(error: "测试失败", details: error.localizedDescription)
        }
    }
}

// MARK: - 数据模型

struct AIApiConfig: Codable, Identifiable {
    let id: String
    let name: String
    let baseUrl: String
    let model: String
    let isDefault: Bool
    let isEnabled: Bool
}

struct AISystemPrompt: Codable, Identifiable {
    let id: String
    let promptText: String
    let updatedAt: String
}

struct AIPromptTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let subject: String?
    let isDefault: Bool
}

// MARK: - 预览

#Preview {
    NavigationStack {
        AIConfigView()
    }
}
