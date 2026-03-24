//
//  MenuButtonsView.swift
//  pinghu12250
//
//  侧边栏顶部菜单按钮（胶囊样式）
//

import SwiftUI

struct MenuButtonsView: View {
    @Binding var selected: MenuType
    var badges: [MenuType: Int] = [:]
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MenuType.allCases) { menu in
                MenuCapsuleButton(
                    menu: menu,
                    badge: badges[menu] ?? 0,
                    isSelected: selected == menu,
                    animation: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = menu
                    }
                }
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.12))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
    }
}

struct MenuCapsuleButton: View {
    let menu: MenuType
    let badge: Int
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: menu.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(menu.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(backgroundView)

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Capsule()
                .fill(menu.color)
                .matchedGeometryEffect(id: "selector", in: animation)
        }
    }
}
