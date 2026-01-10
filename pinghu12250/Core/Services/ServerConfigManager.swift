//
//  ServerConfigManager.swift
//  pinghu12250
//
//  服务器配置管理器 - 支持切换服务器地址
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ServerConfigManager: ObservableObject {
    static let shared = ServerConfigManager()

    // MARK: - 预设服务器

    enum PresetServer: String, CaseIterable, Identifiable {
        case production = "生产服务器"
        case tailscale = "Tailscale"
        case custom = "自定义地址"

        var id: String { rawValue }

        var baseURL: String {
            switch self {
            case .production:
                return "https://pinghu.706tech.cn/api"
            case .tailscale:
                return "https://beichenmac-mini-3.tail2b26f.ts.net/api"
            case .custom:
                return "" // 使用自定义地址
            }
        }
    }

    // MARK: - 配置

    @Published var selectedPreset: PresetServer {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: "serverPreset")
            updateAPIBaseURL()
        }
    }

    @Published var customURL: String {
        didSet {
            UserDefaults.standard.set(customURL, forKey: "customServerURL")
            if selectedPreset == .custom {
                updateAPIBaseURL()
            }
        }
    }

    @Published var isTestingSpeed = false
    @Published var testResult: SpeedTestResult?

    struct SpeedTestResult {
        let success: Bool
        let latency: TimeInterval?  // 延迟（秒）
        let downloadSpeed: Double?  // 下载速度（KB/s）
        let message: String
    }

    // MARK: - 当前生效的 URL

    var currentBaseURL: String {
        switch selectedPreset {
        case .tailscale, .production:
            return selectedPreset.baseURL
        case .custom:
            return customURL.isEmpty ? PresetServer.production.baseURL : customURL
        }
    }

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 恢复配置
        let savedPreset = UserDefaults.standard.string(forKey: "serverPreset") ?? PresetServer.production.rawValue
        self.selectedPreset = PresetServer(rawValue: savedPreset) ?? .production
        self.customURL = UserDefaults.standard.string(forKey: "customServerURL") ?? ""

        updateAPIBaseURL()
    }

    // MARK: - 更新 API 配置

    private func updateAPIBaseURL() {
        // 通知 APIConfig 更新 baseURL
        // 这里需要修改 APIConfig 来支持动态 URL
        #if DEBUG
        print("服务器地址已更新: \(currentBaseURL)")
        #endif
    }

    // MARK: - 测速

    func testSpeed() async {
        isTestingSpeed = true
        testResult = nil

        let startTime = Date()

        do {
            // 测试延迟 - 请求一个轻量级接口
            let pingURL = URL(string: currentBaseURL.replacingOccurrences(of: "/api", with: "") + "/api/health")
                ?? URL(string: currentBaseURL + "/health")!

            var request = URLRequest(url: pingURL)
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                testResult = SpeedTestResult(
                    success: false,
                    latency: nil,
                    downloadSpeed: nil,
                    message: "连接失败"
                )
                isTestingSpeed = false
                return
            }

            let latency = Date().timeIntervalSince(startTime)

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                // 测试下载速度 - 下载一个小文件
                let downloadSpeed = await measureDownloadSpeed()

                testResult = SpeedTestResult(
                    success: true,
                    latency: latency,
                    downloadSpeed: downloadSpeed,
                    message: "连接成功"
                )
            } else {
                testResult = SpeedTestResult(
                    success: false,
                    latency: latency,
                    downloadSpeed: nil,
                    message: "服务器返回错误: \(httpResponse.statusCode)"
                )
            }
        } catch {
            testResult = SpeedTestResult(
                success: false,
                latency: nil,
                downloadSpeed: nil,
                message: "连接失败: \(error.localizedDescription)"
            )
        }

        isTestingSpeed = false
    }

    private func measureDownloadSpeed() async -> Double? {
        // 尝试下载一个已知文件来测量速度
        let testURL = URL(string: currentBaseURL.replacingOccurrences(of: "/api", with: "") + "/favicon.ico")

        guard let url = testURL else { return nil }

        let startTime = Date()

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let duration = Date().timeIntervalSince(startTime)

            if duration > 0 {
                // 返回 KB/s
                return Double(data.count) / 1024.0 / duration
            }
        } catch {
            #if DEBUG
            print("测速失败: \(error)")
            #endif
        }

        return nil
    }
}
