//
//  MyFriendQRCodeCard.swift
//  pinghu12250
//
//  添加好友页底部二维码卡片
//

import SwiftUI

struct MyFriendQRCodeCard: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if let user = authManager.currentUser,
           let image = FriendQRCodeHelper.generateQRCodeImage(from: FriendQRCodeHelper.payload(for: user.id)) {
            VStack(spacing: 10) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(16)

                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text("扫一扫上方二维码，加我为好友")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}
