//
//  UserProfileView.swift
//  pinghu12250
//
//  用户主页详情
//

import SwiftUI
import Combine

struct UserDetailResponse: Codable {
    let success: Bool?
    let data: User?
}

struct UserProfileView: View {
    let userId: String
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let user = viewModel.user {
                    // 头像和基本信息
                    VStack(spacing: 12) {
                        AsyncImage(url: user.avatarURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        Text(user.displayName)
                            .font(.system(size: 20, weight: .semibold))

                        if let bio = user.bio {
                            Text(bio)
                                .font(.system(size: 14))
                                .foregroundColor(.messageSecondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)

                    // 统计信息
                    HStack(spacing: 40) {
                        UserStatItem(title: "积分", count: user.totalPoints ?? 0)
                        UserStatItem(title: "关注", count: user.followingCount ?? 0)
                        UserStatItem(title: "粉丝", count: user.followersCount ?? 0)
                    }
                    .padding(.vertical, 20)
                } else if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else {
                    Text("加载失败")
                        .foregroundColor(.messageSecondaryText)
                        .padding(.top, 100)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.messageSecondaryBackground)
        .task {
            await viewModel.loadUser(userId: userId)
        }
    }
}

struct UserStatItem: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.messageSecondaryText)
        }
    }
}

class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false

    func loadUser(userId: String) async {
        await MainActor.run { isLoading = true }

        do {
            let response: UserDetailResponse = try await APIService.shared.get("/api/users/\(userId)")
            await MainActor.run {
                user = response.data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
