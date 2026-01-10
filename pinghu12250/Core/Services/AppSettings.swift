//
//  AppSettings.swift
//  pinghu12250
//
//  全局应用设置 - 字体大小、显示偏好等
//

import SwiftUI
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - 主题模式设置

    enum ThemeMode: String, CaseIterable, Identifiable {
        case auto = "自动"
        case light = "亮色"
        case dark = "暗色"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .auto: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .auto: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "appThemeMode")
        }
    }

    // MARK: - 字体大小设置

    enum FontSize: String, CaseIterable, Identifiable {
        case small = "小"
        case medium = "中"
        case large = "大"
        case extraLarge = "特大"

        var id: String { rawValue }

        var scale: CGFloat {
            switch self {
            case .small: return 0.85
            case .medium: return 1.0
            case .large: return 1.15
            case .extraLarge: return 1.3
            }
        }

        var displaySize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            case .extraLarge: return 20
            }
        }

        /// 映射到系统 DynamicTypeSize
        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .extraLarge: return .xLarge
            }
        }
    }

    @Published var fontSize: FontSize {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: "appFontSize")
        }
    }

    // MARK: - 计算属性

    var fontScale: CGFloat { fontSize.scale }
    var dynamicTypeSize: DynamicTypeSize { fontSize.dynamicTypeSize }

    // 标题字体
    var titleFont: Font { .system(size: 20 * fontScale, weight: .bold) }
    var headlineFont: Font { .system(size: 17 * fontScale, weight: .semibold) }
    var subheadlineFont: Font { .system(size: 15 * fontScale) }
    var bodyFont: Font { .system(size: 16 * fontScale) }
    var captionFont: Font { .system(size: 13 * fontScale) }
    var caption2Font: Font { .system(size: 11 * fontScale) }

    // MARK: - 初始化

    private init() {
        // 加载主题模式
        let savedThemeMode = UserDefaults.standard.string(forKey: "appThemeMode") ?? ThemeMode.auto.rawValue
        self.themeMode = ThemeMode(rawValue: savedThemeMode) ?? .auto

        // 加载字体大小
        let savedFontSize = UserDefaults.standard.string(forKey: "appFontSize") ?? FontSize.medium.rawValue
        self.fontSize = FontSize(rawValue: savedFontSize) ?? .medium
    }
}

// MARK: - 环境键

struct AppSettingsKey: EnvironmentKey {
    static let defaultValue = AppSettings.shared
}

extension EnvironmentValues {
    var appSettings: AppSettings {
        get { self[AppSettingsKey.self] }
        set { self[AppSettingsKey.self] = newValue }
    }
}
