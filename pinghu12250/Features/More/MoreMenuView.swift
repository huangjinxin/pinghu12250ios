//
//  MoreMenuView.swift
//  pinghu12250
//
//  更多功能菜单
//

import SwiftUI

struct MoreMenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

struct MoreMenuView: View {
    @Binding var selectedItem: String?

    private let lifeItems = [
        MoreMenuItem(id: "feed", title: "学习圈", icon: "star.circle.fill", color: Color(hex: "3B82F6")),
        MoreMenuItem(id: "exchange", title: "成长兑换", icon: "gift.fill", color: Color(hex: "EC4899"))
    ]

    private let learningItems = [
        MoreMenuItem(id: "diary-submit", title: "写日记", icon: "square.and.pencil", color: Color(hex: "F59E0B")),
        MoreMenuItem(id: "diary", title: "日记列表", icon: "book.closed.fill", color: Color(hex: "EAB308")),
        MoreMenuItem(id: "writing", title: "书写练习", icon: "pencil", color: Color(hex: "6366F1")),
        MoreMenuItem(id: "pinyin", title: "拼音学习", icon: "character.phonetic", color: Color(hex: "8B5CF6")),
        MoreMenuItem(id: "works", title: "我的作品", icon: "paintbrush.fill", color: Color(hex: "EC4899")),
        MoreMenuItem(id: "homework", title: "我的作业", icon: "doc.text.fill", color: Color(hex: "10B981")),
        MoreMenuItem(id: "textbooks", title: "我的教材", icon: "book.fill", color: Color(hex: "F59E0B"))
    ]

    private let dataItems = [
        MoreMenuItem(id: "dashboard", title: "学习统计", icon: "chart.bar.fill", color: Color(hex: "06B6D4")),
        MoreMenuItem(id: "photos", title: "照片管理", icon: "photo.fill", color: Color(hex: "EF4444")),
        MoreMenuItem(id: "growth", title: "成长记录", icon: "chart.line.uptrend.xyaxis", color: Color(hex: "22C55E"))
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 生活娱乐分类
                CategoryHeader(title: "🎮 生活娱乐")
                ForEach(lifeItems) { item in
                    MoreMenuRow(item: item, isSelected: selectedItem == item.id)
                        .onTapGesture {
                            selectedItem = item.id
                        }
                }

                // 学习功能分类
                CategoryHeader(title: "📚 学习功能")
                ForEach(learningItems) { item in
                    MoreMenuRow(item: item, isSelected: selectedItem == item.id)
                        .onTapGesture {
                            selectedItem = item.id
                        }
                }

                // 数据统计分类
                CategoryHeader(title: "📊 数据统计")
                ForEach(dataItems) { item in
                    MoreMenuRow(item: item, isSelected: selectedItem == item.id)
                        .onTapGesture {
                            selectedItem = item.id
                        }
                }
            }
        }
        .background(Color.messageSecondaryBackground)
    }
}

struct CategoryHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .background(Color.messageSecondaryBackground)
    }
}

struct MoreMenuRow: View {
    let item: MoreMenuItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.color)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )

            Text(item.title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .appPrimary : .messagePrimaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.messageSecondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.appPrimary.opacity(0.08) : Color.white)
        .overlay(
            Rectangle()
                .fill(Color.messageBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
