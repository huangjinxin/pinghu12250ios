//
//  ServerSelector.swift
//  pinghu12250
//
//  服务器选择器 - 共享组件，用于登录界面和系统设置
//

import SwiftUI
import Combine

// MARK: - 服务器选项

enum ServerOption: String, CaseIterable, Identifiable {
    case production = "生产服务器"
    case tailscale = "Tailscale"
    case local = "本地开发"
    case custom = "自定义地址"

    var id: String { rawValue }

    /// 默认URL（初始值）
    var defaultURL: String {
        switch self {
        case .production:
            return "https://pinghu.706tech.cn/api"
        case .tailscale:
            return "https://beichenmac-mini-3.tail2b26f.ts.net/api"
        case .local:
            return "http://192.168.88.228:12251/api"  // 后端端口是 12251，不是 12250
        case .custom:
            return ""
        }
    }

    /// 当前URL（从 UserDefaults 读取用户自定义值，如无则返回默认值）
    var url: String {
        if self == .custom || self == .local { return defaultURL }
        let key = "serverURL_\(self.rawValue)"
        if let customURL = UserDefaults.standard.string(forKey: key), !customURL.isEmpty {
            return customURL
        }
        return defaultURL
    }

    /// 保存用户自定义的URL
    func saveCustomURL(_ url: String) {
        let key = "serverURL_\(self.rawValue)"
        if url.isEmpty || url == defaultURL {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(url, forKey: key)
        }
    }

    /// 检查是否已被用户自定义
    var isCustomized: Bool {
        if self == .custom || self == .local { return false }
        let key = "serverURL_\(self.rawValue)"
        if let customURL = UserDefaults.standard.string(forKey: key), !customURL.isEmpty, customURL != defaultURL {
            return true
        }
        return false
    }

    /// 重置为默认值
    func resetToDefault() {
        let key = "serverURL_\(self.rawValue)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    var icon: String {
        switch self {
        case .production: return "cloud"
        case .tailscale: return "network"
        case .local: return "desktopcomputer"
        case .custom: return "link"
        }
    }

    var description: String {
        switch self {
        case .production: return "正式环境"
        case .tailscale: return "VPN 内网"
        case .local: return "本地 HTTP"
        case .custom: return "自定义"
        }
    }
}

// MARK: - 服务器配置管理

class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    @Published var selectedServer: ServerOption {
        didSet {
            UserDefaults.standard.set(selectedServer.rawValue, forKey: "selectedServerOption")
            applyServerConfig()
        }
    }

    @Published var customURL: String {
        didSet {
            UserDefaults.standard.set(customURL, forKey: "customServerURL")
            if selectedServer == .custom {
                applyServerConfig()
            }
        }
    }

    var currentURL: String {
        if selectedServer == .custom {
            return customURL.isEmpty ? ServerOption.production.url : customURL
        }
        return selectedServer.url
    }

    private init() {
        let savedOption = UserDefaults.standard.string(forKey: "selectedServerOption") ?? ""
        self.selectedServer = ServerOption(rawValue: savedOption) ?? .production
        self.customURL = UserDefaults.standard.string(forKey: "customServerURL") ?? ""

        // 自动修复错误的端口配置：12250（前端）→ 12251（后端）
        migrateWrongPortIfNeeded()

        applyServerConfig()
    }

    /// 迁移修复：自动修正错误的端口和 IP 配置
    private func migrateWrongPortIfNeeded() {
        var needsUpdate = false
        var fixedURL = customURL

        // 修复错误端口：12250（前端）→ 12251（后端）
        if fixedURL.contains(":12250/") {
            fixedURL = fixedURL.replacingOccurrences(of: ":12250/", with: ":12251/")
            needsUpdate = true
            #if DEBUG
            print("⚠️ 自动修复端口: 12250 → 12251")
            #endif
        }

        // 修复错误 IP：248 → 228
        if fixedURL.contains("192.168.88.248") {
            fixedURL = fixedURL.replacingOccurrences(of: "192.168.88.248", with: "192.168.88.228")
            needsUpdate = true
            #if DEBUG
            print("⚠️ 自动修复 IP: 248 → 228")
            #endif
        }

        if needsUpdate {
            customURL = fixedURL
            UserDefaults.standard.set(customURL, forKey: "customServerURL")
        }

        // 修复 activeServerURL
        if let activeURL = UserDefaults.standard.string(forKey: "activeServerURL") {
            var fixedActiveURL = activeURL
            var activeNeedsUpdate = false

            if fixedActiveURL.contains(":12250/") {
                fixedActiveURL = fixedActiveURL.replacingOccurrences(of: ":12250/", with: ":12251/")
                activeNeedsUpdate = true
            }
            if fixedActiveURL.contains("192.168.88.248") {
                fixedActiveURL = fixedActiveURL.replacingOccurrences(of: "192.168.88.248", with: "192.168.88.228")
                activeNeedsUpdate = true
            }

            if activeNeedsUpdate {
                UserDefaults.standard.set(fixedActiveURL, forKey: "activeServerURL")
                #if DEBUG
                print("⚠️ 自动修复 activeServerURL: \(fixedActiveURL)")
                #endif
            }
        }
    }

    func applyServerConfig() {
        APIConfig.updateBaseURL(currentURL)
        #if DEBUG
        print("服务器已切换: \(currentURL)")
        #endif
    }
}

// MARK: - 服务器选择器视图（紧凑版 - 用于登录界面）

struct ServerSelectorCompact: View {
    @ObservedObject var config = ServerConfig.shared
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: config.selectedServer.icon)
                    .font(.caption)
                Text(config.selectedServer.rawValue)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .sheet(isPresented: $showingPicker) {
            ServerPickerSheet(config: config)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - 服务器选择器 Sheet

struct ServerPickerSheet: View {
    @ObservedObject var config: ServerConfig
    @Environment(\.dismiss) var dismiss
    @State private var tempCustomURL: String = ""
    @State private var isTestingSpeed = false
    @State private var testResult: SpeedTestResult?

    struct SpeedTestResult {
        let success: Bool
        let latency: Int?
        let message: String
    }

    var body: some View {
        NavigationStack {
            Form {
                // 服务器列表
                Section {
                    ForEach(ServerOption.allCases) { option in
                        Button {
                            config.selectedServer = option
                            if option != .custom {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.appPrimary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.rawValue)
                                        .foregroundColor(.primary)
                                    if option != .custom {
                                        Text(option.url)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text(option.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if config.selectedServer == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择服务器")
                } footer: {
                    Text("生产服务器用于正式使用\nTailscale 用于 VPN 内网访问")
                        .font(.caption2)
                }

                // 自定义地址输入
                if config.selectedServer == .custom {
                    Section("自定义服务器地址") {
                        TextField("输入服务器地址", text: $tempCustomURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onAppear {
                                tempCustomURL = config.customURL
                            }

                        Text("示例：https://your-server.com/api")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("保存地址") {
                            config.customURL = tempCustomURL
                            dismiss()
                        }
                        .disabled(tempCustomURL.isEmpty)
                    }
                }

                // 当前配置
                Section("当前配置") {
                    LabeledContent("服务器地址") {
                        Text(config.currentURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                // 测速
                Section {
                    Button {
                        Task { await testSpeed() }
                    } label: {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.appPrimary)
                            Text("测试连接")
                            Spacer()
                            if isTestingSpeed {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTestingSpeed)

                    if let result = testResult {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            VStack(alignment: .leading) {
                                Text(result.message)
                                    .font(.subheadline)
                                if let latency = result.latency {
                                    Text("延迟: \(latency)ms")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("网络测试")
                }
            }
            .navigationTitle("服务器配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func testSpeed() async {
        isTestingSpeed = true
        testResult = nil

        let urlString = config.currentURL.replacingOccurrences(of: "/api", with: "")

        let startTime = Date()

        do {
            guard let healthURL = URL(string: urlString + "/api/health") else {
                testResult = SpeedTestResult(success: false, latency: nil, message: "地址格式无效")
                isTestingSpeed = false
                return
            }

            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 200 && httpResponse.statusCode < 500 {
                testResult = SpeedTestResult(success: true, latency: latency, message: "连接成功")
            } else {
                testResult = SpeedTestResult(success: false, latency: latency, message: "服务器响应异常")
            }
        } catch {
            testResult = SpeedTestResult(success: false, latency: nil, message: "连接失败")
        }

        isTestingSpeed = false
    }
}

// MARK: - 预览

#Preview("服务器选择器") {
    VStack(spacing: 20) {
        ServerSelectorCompact()
    }
    .padding()
}

#Preview("服务器选择 Sheet") {
    ServerPickerSheet(config: ServerConfig.shared)
}
