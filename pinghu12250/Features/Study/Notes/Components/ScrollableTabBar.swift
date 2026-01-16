//
//  ScrollableTabBar.swift
//  pinghu12250
//
//  横向滚动Tab栏组件
//  支持任意数量的Tab选项
//

import SwiftUI

/// 笔记Tab类型
enum NoteTab: String, CaseIterable, Identifiable {
    case all = "全部"
    case timeline = "按时间"
    case textbook = "按教材"
    case vocabulary = "生词本"
    case excerpt = "摘录"
    case practice = "练习"
    case solving = "解题"

    var id: String { rawValue }

    /// 对应的筛选类型
    var sourceTypes: [String]? {
        switch self {
        case .all: return nil
        case .timeline: return nil
        case .textbook: return nil
        case .vocabulary: return ["dict"]
        case .excerpt: return ["pdf_selection", "highlight"]
        case .practice: return ["practice", "exercise", "writing_practice"]
        case .solving: return ["solving"]
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .timeline: return "clock"
        case .textbook: return "book"
        case .vocabulary: return "character.book.closed"
        case .excerpt: return "highlighter"
        case .practice: return "pencil.line"
        case .solving: return "questionmark.circle"
        }
    }
}

/// 横向滚动Tab栏
struct ScrollableTabBar: View {
    @Binding var selectedTab: NoteTab
    var tabs: [NoteTab] = NoteTab.allCases

    @Namespace private var animation

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    NoteTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
    }
}

/// 单个Tab按钮
private struct NoteTabButton: View {
    let tab: NoteTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 14))
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                }
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // 下划线指示器
                if isSelected {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "indicator", in: namespace)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: NoteTab = .all

        var body: some View {
            VStack {
                ScrollableTabBar(selectedTab: $selectedTab)
                    .background(Color(.systemGray6))

                Spacer()

                Text("选中: \(selectedTab.rawValue)")
            }
        }
    }

    return PreviewWrapper()
}
