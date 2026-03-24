//
//  BotAvatarView.swift
//  pinghu12250
//
//  Bot 头像视图
//

import SwiftUI

struct BotAvatarView: View {
    let avatar: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        if let avatar, let url = URL(string: avatar.hasPrefix("http") ? avatar : APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + avatar) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackAvatar
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
            )
    }
}
