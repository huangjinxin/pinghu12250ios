//
//  MenuType.swift
//  pinghu12250
//
//  侧边栏菜单类型
//

import SwiftUI

enum MenuType: String, CaseIterable, Identifiable {
    case messages = "消息"
    case contacts = "通讯录"
    case more = "更多"
    case profile = "我的"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .messages: return "message.fill"
        case .contacts: return "person.2.fill"
        case .more: return "square.grid.2x2.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .messages: return Color(hex: "10B981")
        case .contacts: return Color(hex: "3B82F6")
        case .more: return Color(hex: "F59E0B")
        case .profile: return Color(hex: "EC4899")
        }
    }
}
