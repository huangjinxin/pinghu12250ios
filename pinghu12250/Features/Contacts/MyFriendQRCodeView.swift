//
//  MyFriendQRCodeView.swift
//  pinghu12250
//
//  我的好友二维码
//

import SwiftUI

struct MyFriendQRCodeView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let user = authManager.currentUser {
                if let image = FriendQRCodeHelper.generateQRCodeImage(from: FriendQRCodeHelper.payload(for: user.id)) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 260, height: 260)
                        .background(Color.white)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                }

                VStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.system(size: 20, weight: .semibold))
                    Text("扫一扫上方二维码，加我为好友")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("ID: \(user.username)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView("加载中...")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("我的二维码")
        .navigationBarTitleDisplayMode(.inline)
    }
}
