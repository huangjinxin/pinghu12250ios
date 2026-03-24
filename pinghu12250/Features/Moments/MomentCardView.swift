//
//  MomentCardView.swift
//  pinghu12250
//
//  朋友圈卡片视图
//

import SwiftUI

struct MomentCardView: View {
    let moment: Moment

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(moment.userName.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.userName)
                        .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                    Text(moment.timeAgo)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.messageSecondaryText)
                }
                Spacer()
            }

            Text(moment.content)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.messagePrimaryText)

            HStack(spacing: Theme.Spacing.xl) {
                Label("\(moment.likes)", systemImage: "heart")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.messageSecondaryText)
                Label("\(moment.comments)", systemImage: "bubble.right")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.messageSecondaryText)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.card)
                .stroke(Color.messageBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}
