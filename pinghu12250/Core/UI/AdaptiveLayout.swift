//
//  AdaptiveLayout.swift
//  pinghu12250
//
//  自适应布局助手 - 检测横屏/竖屏
//

import SwiftUI

struct AdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayout()
}

extension EnvironmentValues {
    var adaptiveLayout: AdaptiveLayout {
        get { self[AdaptiveLayoutKey.self] }
        set { self[AdaptiveLayoutKey.self] = newValue }
    }
}

struct AdaptiveLayout {
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?

    var isLandscape: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    var isSplitViewCapable: Bool {
        horizontalSizeClass == .regular
    }
}

// MARK: - View Modifier
struct AdaptiveLayoutModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.adaptiveLayout, AdaptiveLayout(
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass
            ))
    }
}

extension View {
    func adaptiveLayout() -> some View {
        modifier(AdaptiveLayoutModifier())
    }
}
