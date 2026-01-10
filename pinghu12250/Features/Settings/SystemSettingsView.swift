//
//  SystemSettingsView.swift
//  pinghu12250
//
//  系统设置视图 - 服务器配置和测速
//

import SwiftUI

struct SystemSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var config = ServerConfig.shared
    @ObservedObject var appSettings = AppSettings.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var tempCustomURL: String = ""
    @State private var isTestingSpeed = false
    @State private var testResult: TestResult?
    @State private var showingAlert = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var deleteAccountPassword = ""
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var editingServer: ServerOption? = nil
    @State private var editingServerURL: String = ""
    @State private var showSpeechGuide = false

    struct TestResult {
        let success: Bool
        let latency: Int?  // 毫秒
        let speed: Double? // KB/s
        let message: String
    }

    var body: some View {
        NavigationStack {
            Form {
                // 账号安全（2FA 状态）
                Section {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.appPrimary)
                            .frame(width: 24)
                        Text("两步验证")
                        Spacer()
                        if authManager.currentUser?.twoFactorEnabled == true {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                Text("已启用")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                        } else {
                            Text("未启用")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("账号安全")
                } footer: {
                    Text("两步验证可增强账户安全性。如需开启或关闭，请前往 Web 端设置")
                }

                // 主题模式设置
                Section {
                    HStack(spacing: 12) {
                        ForEach(AppSettings.ThemeMode.allCases) { mode in
                            Button {
                                withAnimation {
                                    appSettings.themeMode = mode
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 22))
                                    Text(mode.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(appSettings.themeMode == mode ? Color.appPrimary : Color(.systemGray5))
                                )
                                .foregroundColor(appSettings.themeMode == mode ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("主题模式")
                } footer: {
                    Text("选择应用的外观模式，自动模式会跟随系统设置")
                }

                // 字体大小设置
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ForEach(AppSettings.FontSize.allCases) { size in
                                Button {
                                    withAnimation {
                                        appSettings.fontSize = size
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("文")
                                            .font(.system(size: size.displaySize))
                                            .fontWeight(.medium)
                                        Text(size.rawValue)
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(appSettings.fontSize == size ? Color.appPrimary : Color(.systemGray5))
                                    )
                                    .foregroundColor(appSettings.fontSize == size ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 预览文本
                        VStack(alignment: .leading, spacing: 4) {
                            Text("预览效果")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("苹湖少儿空间 - 让学习更有趣")
                                .font(.system(size: 16 * appSettings.fontScale))
                        }
                        .padding(.top, 8)
                    }
                } header: {
                    Text("字体大小")
                } footer: {
                    Text("调整应用内文字显示大小，方便阅读")
                }

                // 服务器选择
                Section {
                    ForEach(ServerOption.allCases) { option in
                        HStack {
                            Button {
                                config.selectedServer = option
                            } label: {
                                HStack {
                                    Image(systemName: option.icon)
                                        .foregroundColor(.appPrimary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(option.rawValue)
                                                .foregroundColor(.primary)
                                            Text(option.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if option != .custom && option.isCustomized {
                                                Text("已修改")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        if option != .custom {
                                            Text(option.url)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if config.selectedServer == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.appPrimary)
                                    }
                                }
                            }

                            // 编辑按钮（非自定义选项显示）
                            if option != .custom {
                                Button {
                                    editingServer = option
                                    editingServerURL = option.url
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.appPrimary.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("选择服务器")
                } footer: {
                    Text("生产服务器：正式环境\nTailscale：VPN 内网访问\n局域网：本地网络调试\n本地开发：模拟器调试\n\n点击铅笔图标可修改预设地址")
                }

                // 自定义地址
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

                        Button("保存自定义地址") {
                            config.customURL = tempCustomURL
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
                            Text("测试连接速度")
                            Spacer()
                            if isTestingSpeed {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTestingSpeed || (config.selectedServer == .custom && config.customURL.isEmpty))

                    if let result = testResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                Text(result.message)
                                    .fontWeight(.medium)
                            }

                            if result.success {
                                if let latency = result.latency {
                                    HStack {
                                        Text("延迟:")
                                            .foregroundColor(.secondary)
                                        Text("\(latency) ms")
                                            .fontWeight(.medium)
                                            .foregroundColor(latency < 100 ? .green : (latency < 500 ? .orange : .red))
                                    }
                                    .font(.subheadline)
                                }

                                if let speed = result.speed {
                                    HStack {
                                        Text("下载速度:")
                                            .foregroundColor(.secondary)
                                        Text(formatSpeed(speed))
                                            .fontWeight(.medium)
                                            .foregroundColor(speed > 1000 ? .green : (speed > 100 ? .orange : .red))
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("网络测试")
                }

                // AI 配置
                Section {
                    NavigationLink {
                        AIConfigView()
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("AI 配置")
                            Spacer()
                            Text("只读")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI 设置")
                } footer: {
                    Text("查看当前 AI 配置，如需修改请前往 Web 端工作台")
                }

                // 朗读功能
                Section {
                    Button {
                        showSpeechGuide = true
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.appPrimary)
                                .frame(width: 24)
                            Text("朗读功能设置")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("辅助功能")
                } footer: {
                    Text("开启系统朗读后，长按选择任意文字即可朗读")
                }

                // 退出登录
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }

                // 删除账户
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除账户")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                } footer: {
                    Text("删除账户将永久移除所有数据，此操作不可撤销")
                }
            }
            .navigationTitle("系统设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("确认退出", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    authManager.logout()
                    dismiss()
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
            .alert("删除账户", isPresented: $showDeleteAccountConfirm) {
                SecureField("请输入密码确认", text: $deleteAccountPassword)
                Button("取消", role: .cancel) {
                    deleteAccountPassword = ""
                    deleteAccountError = nil
                }
                Button("删除", role: .destructive) {
                    Task {
                        await performDeleteAccount()
                    }
                }
            } message: {
                VStack {
                    Text("此操作不可撤销！所有数据将被永久删除。")
                    if let error = deleteAccountError {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .sheet(item: $editingServer) { server in
                ServerURLEditSheet(
                    server: server,
                    currentURL: server.url,
                    onSave: { newURL in
                        server.saveCustomURL(newURL)
                        config.applyServerConfig()
                        editingServer = nil
                    }
                )
            }
            .sheet(isPresented: $showSpeechGuide) {
                SpeechSettingsGuideView()
            }
        }
    }

    private func testSpeed() async {
        isTestingSpeed = true
        testResult = nil

        let urlString = config.currentURL
        let baseURL = urlString.replacingOccurrences(of: "/api", with: "")

        // 测试延迟
        let startTime = Date()

        do {
            guard let healthURL = URL(string: baseURL + "/api/health") else {
                testResult = TestResult(success: false, latency: nil, speed: nil, message: "地址格式无效")
                isTestingSpeed = false
                return
            }

            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let httpResponse = response as? HTTPURLResponse else {
                testResult = TestResult(success: false, latency: latency, speed: nil, message: "响应格式异常")
                isTestingSpeed = false
                return
            }

            // 检查状态码
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                // 测试下载速度
                let speed = await measureDownloadSpeed(baseURL: baseURL)

                testResult = TestResult(
                    success: true,
                    latency: latency,
                    speed: speed,
                    message: "连接成功"
                )
            } else if httpResponse.statusCode == 404 {
                // 404 可能是 health 接口不存在，但服务器是在线的
                let speed = await measureDownloadSpeed(baseURL: baseURL)
                testResult = TestResult(
                    success: true,
                    latency: latency,
                    speed: speed,
                    message: "服务器在线"
                )
            } else {
                testResult = TestResult(
                    success: false,
                    latency: latency,
                    speed: nil,
                    message: "服务器返回错误 (\(httpResponse.statusCode))"
                )
            }
        } catch let error as URLError {
            // 更详细的错误信息
            let message: String
            switch error.code {
            case .timedOut:
                message = "连接超时，请检查网络"
            case .cannotFindHost:
                message = "找不到服务器，请检查地址"
            case .cannotConnectToHost:
                message = "无法连接服务器，请检查地址和端口"
            case .networkConnectionLost:
                message = "网络连接中断"
            case .notConnectedToInternet:
                message = "未连接到互联网"
            case .secureConnectionFailed:
                message = "安全连接失败"
            default:
                message = "连接失败: \(error.localizedDescription)"
            }
            testResult = TestResult(
                success: false,
                latency: nil,
                speed: nil,
                message: message
            )
        } catch {
            testResult = TestResult(
                success: false,
                latency: nil,
                speed: nil,
                message: "连接失败: \(error.localizedDescription)"
            )
        }

        isTestingSpeed = false
    }

    private func measureDownloadSpeed(baseURL: String) async -> Double? {
        // 使用多个测试 URL 确保更准确的测速
        let testURLs = [
            baseURL + "/api/health",
            baseURL + "/favicon.ico",
            baseURL + "/api/textbooks/public?limit=5"
        ]

        var totalBytes: Int = 0
        let testDuration: TimeInterval = 5.0 // 持续测试 5 秒
        let startTime = Date()
        var requestCount = 0

        // 持续测试直到达到 5 秒
        while Date().timeIntervalSince(startTime) < testDuration {
            for urlString in testURLs {
                // 检查是否已超时
                if Date().timeIntervalSince(startTime) >= testDuration {
                    break
                }

                guard let testURL = URL(string: urlString) else { continue }

                do {
                    var request = URLRequest(url: testURL)
                    request.timeoutInterval = 3 // 单次请求超时 3 秒
                    request.cachePolicy = .reloadIgnoringLocalCacheData // 忽略缓存确保真实下载

                    let (data, _) = try await URLSession.shared.data(for: request)
                    totalBytes += data.count
                    requestCount += 1
                } catch {
                    // 忽略单次失败，继续测试
                    continue
                }
            }

            // 如果已经有足够多的请求，且已过 2 秒，可以提前结束
            if requestCount >= 5 && Date().timeIntervalSince(startTime) >= 2.0 {
                break
            }
        }

        let actualDuration = Date().timeIntervalSince(startTime)

        // 计算平均速度
        if actualDuration > 0 && totalBytes > 0 {
            return Double(totalBytes) / 1024.0 / actualDuration
        }

        return nil
    }

    private func formatSpeed(_ kbps: Double) -> String {
        if kbps >= 1024 {
            return String(format: "%.1f MB/s", kbps / 1024)
        } else {
            return String(format: "%.0f KB/s", kbps)
        }
    }

    private func performDeleteAccount() async {
        guard !deleteAccountPassword.isEmpty else {
            deleteAccountError = "请输入密码"
            showDeleteAccountConfirm = true
            return
        }

        isDeletingAccount = true
        deleteAccountError = nil

        let success = await authManager.deleteAccount(password: deleteAccountPassword)

        isDeletingAccount = false

        if success {
            deleteAccountPassword = ""
            dismiss()
        } else {
            deleteAccountError = authManager.errorMessage ?? "删除失败"
            deleteAccountPassword = ""
            showDeleteAccountConfirm = true
        }
    }
}

// MARK: - 服务器地址编辑 Sheet

struct ServerURLEditSheet: View {
    let server: ServerOption
    let currentURL: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedURL: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: server.icon)
                                .foregroundColor(.appPrimary)
                            Text(server.rawValue)
                                .font(.headline)
                        }

                        Text(server.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("服务器地址") {
                    TextField("输入服务器地址", text: $editedURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Text("示例：https://your-server.com/api")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("默认地址") {
                    Text(server.defaultURL)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if server.isCustomized {
                        Button("恢复默认地址", role: .destructive) {
                            showResetConfirm = true
                        }
                    }
                }
            }
            .navigationTitle("编辑 \(server.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(editedURL)
                        dismiss()
                    }
                    .disabled(editedURL.isEmpty)
                }
            }
            .onAppear {
                editedURL = currentURL
            }
            .confirmationDialog("恢复默认地址", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("恢复默认", role: .destructive) {
                    server.resetToDefault()
                    editedURL = server.defaultURL
                    onSave(server.defaultURL)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将 \(server.rawValue) 的地址恢复为：\n\(server.defaultURL)")
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SystemSettingsView()
}
