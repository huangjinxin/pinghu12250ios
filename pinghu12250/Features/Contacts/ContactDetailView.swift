//
//  ContactDetailView.swift
//  pinghu12250
//
//  联系人详情页（右侧详情区）
//

import SwiftUI

struct ContactDetailView: View {
    let user: User

    var body: some View {
        VStack(spacing: 0) {
            // 顶部个人信息卡片
            VStack(spacing: 16) {
                // 头像
                if let avatar = user.avatar, let url = avatarURL(avatar) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        placeholderAvatar
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    placeholderAvatar
                }

                // 名称
                Text(user.displayName)
                    .font(.system(size: 22, weight: .bold))

                // 角色标签
                Text(user.role.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(roleColor)
                    .clipShape(Capsule())

                // 签名
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.white)

            Divider()

            // 信息区
            VStack(spacing: 0) {
                infoRow(label: "用户名", value: user.username)
                if let nickname = user.nickname, !nickname.isEmpty {
                    infoRow(label: "昵称", value: nickname)
                }
            }
            .background(Color.white)
            .padding(.top, 8)

            Spacer()

            // 发消息按钮
            Button {
                IMNavigationHelper.openFriendChat(userId: user.id)
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text("发消息")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(
            Divider(), alignment: .bottom
        )
    }

    private var placeholderAvatar: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(UIColor.systemGray5))
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(user.displayName.prefix(1)))
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.gray)
            )
    }

    private var roleColor: Color {
        switch user.role {
        case .student: return .blue
        case .teacher: return .green
        case .parent: return .orange
        case .admin: return .red
        }
    }

    private func avatarURL(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: APIConfig.baseURL + path)
    }
}
