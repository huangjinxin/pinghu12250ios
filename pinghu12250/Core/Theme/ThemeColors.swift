//
//  ThemeColors.swift
//  pinghu12250
//
//  主题常量 - 间距、圆角、阴影、字体
//

import SwiftUI

enum Theme {
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let bubble: CGFloat = 18
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let avatar: CGFloat = 8
    }

    // MARK: - Shadow
    enum Shadow {
        static let card = (color: Color.black.opacity(0.1), radius: CGFloat(4), y: CGFloat(2))
        static let cardDark = (color: Color.black.opacity(0.3), radius: CGFloat(4), y: CGFloat(2))
    }

    // MARK: - Font Size
    enum FontSize {
        static let title: CGFloat = 20
        static let headline: CGFloat = 17
        static let body: CGFloat = 15
        static let caption: CGFloat = 13
        static let small: CGFloat = 11
    }

    // MARK: - Avatar Size
    enum AvatarSize {
        static let small: CGFloat = 40
        static let medium: CGFloat = 52
        static let large: CGFloat = 60
        static let xlarge: CGFloat = 80
    }
}
