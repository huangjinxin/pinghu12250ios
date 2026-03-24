//
//  ContactRowView.swift
//  pinghu12250
//
//  联系人行视图
//

import SwiftUI

struct ContactRowView: View {
    let contact: ContactItem

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(contact.role.color.opacity(0.15))
                .frame(width: Theme.AvatarSize.medium, height: Theme.AvatarSize.medium)
                .overlay(
                    Text(contact.avatarLetter)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(contact.role.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: Theme.FontSize.headline))
                    .foregroundColor(.messagePrimaryText)

                if let subtitle = contact.subtitle {
                    Text(subtitle)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.messageSecondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ContactItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let role: ContactRole

    var avatarLetter: String {
        String(name.prefix(1))
    }
}

enum ContactRole {
    case ai, teacher, student, parent

    var color: Color {
        switch self {
        case .ai: return .appPrimary
        case .teacher: return .appSuccess
        case .student: return .appInfo
        case .parent: return .appWarning
        }
    }
}
