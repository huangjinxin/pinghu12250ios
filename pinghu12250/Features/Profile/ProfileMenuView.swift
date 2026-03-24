//
//  ProfileMenuView.swift
//  pinghu12250
//
//  我的菜单（个人功能）
//

import SwiftUI

struct MenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

struct ProfileMenuView: View {
    @Binding var selectedItem: String?

    private let menuItems = [
        MenuItem(id: "wallet", title: "我的钱包", icon: "creditcard.fill", color: Color(hex: "F59E0B")),
        MenuItem(id: "points", title: "我的积分", icon: "star.circle.fill", color: Color(hex: "EAB308")),
        MenuItem(id: "settings", title: "系统设置", icon: "gearshape.fill", color: Color(hex: "6B7280")),
        MenuItem(id: "about", title: "关于", icon: "info.circle.fill", color: Color(hex: "3B82F6"))
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(menuItems) { item in
                    ProfileMenuRow(item: item, isSelected: selectedItem == item.id)
                        .onTapGesture {
                            selectedItem = item.id
                        }
                }
            }
        }
        .background(Color.messageSecondaryBackground)
    }
}

struct ProfileMenuRow: View {
    let item: MenuItem
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
