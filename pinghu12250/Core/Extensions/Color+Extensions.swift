//
//  Color+Extensions.swift
//  pinghu12250
//
//  颜色扩展 - 品牌色彩系统
//

import SwiftUI
import Combine

extension Color {
    /// 品牌主色调
    static let brand = Color("BrandColor", bundle: nil)

    /// 主题色
    static let appPrimary = Color(hex: "#4F46E5")      // 靛蓝色
    static let appSecondary = Color(hex: "#10B981")   // 翡翠绿
    static let appAccent = Color(hex: "#F59E0B")      // 琥珀色

    /// 语义色
    static let appSuccess = Color(hex: "#22C55E")
    static let appWarning = Color(hex: "#F59E0B")
    static let appError = Color(hex: "#EF4444")
    static let appInfo = Color(hex: "#3B82F6")

    /// 科目颜色
    static let subjectChinese = Color(hex: "#EF4444")  // 红色 - 语文
    static let subjectMath = Color(hex: "#3B82F6")     // 蓝色 - 数学
    static let subjectEnglish = Color(hex: "#22C55E") // 绿色 - 英语
    static let subjectScience = Color(hex: "#8B5CF6") // 紫色 - 科学

    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 获取科目对应颜色
    static func forSubject(_ subject: String?) -> Color {
        guard let subject = subject else { return .gray }
        switch subject.uppercased() {
        case "CHINESE", "语文": return .subjectChinese
        case "MATH", "数学": return .subjectMath
        case "ENGLISH", "英语": return .subjectEnglish
        case "SCIENCE", "科学": return .subjectScience
        default: return .gray
        }
    }

    // MARK: - LINE Style Colors (高对比度)

    /// 背景色
    static let messageBackground = Color(hex: "#FFFFFF")
    static let messageSecondaryBackground = Color(hex: "#F7F7F7")

    /// 文字颜色
    static let messagePrimaryText = Color(hex: "#000000")
    static let messageSecondaryText = Color(hex: "#666666")
    static let messageTertiaryText = Color(hex: "#999999")

    /// 分割线和边框（高对比度）
    static let messageSeparator = Color(hex: "#E0E0E0")
    static let messageBorder = Color(hex: "#D0D0D0")

    /// 气泡颜色 - 用户消息（蓝色）
    static let userBubbleStart = Color(hex: "#007AFF")
    static let userBubbleEnd = Color(hex: "#5AC8FA")

    /// 气泡颜色 - AI消息（灰色）
    static let aiBubbleLight = Color(hex: "#E5E5EA")
    static let aiBubbleDark = Color(hex: "#3A3A3C")

    /// 卡片背景
    static let cardBackground = Color(hex: "#FFFFFF")
    static let cardBackgroundSecondary = Color(hex: "#2C2C2E")
}

// MARK: - Gradient Support
extension LinearGradient {
    /// 用户消息气泡渐变
    static var userBubble: LinearGradient {
        LinearGradient(
            colors: [Color.userBubbleStart, Color.userBubbleEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
