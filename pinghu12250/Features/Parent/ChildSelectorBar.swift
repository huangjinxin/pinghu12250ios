//
//  ChildSelectorBar.swift
//  pinghu12250
//
//  孩子选择器组件 - 横向滚动卡片
//

import SwiftUI

struct ChildSelectorBar: View {
    @Binding var selectedChild: Child?
    let children: [Child]
    let onSelect: (Child) -> Void

    @Namespace private var animation

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(children) { child in
                    ChildCard(
                        child: child,
                        isSelected: selectedChild?.id == child.id,
                        namespace: animation
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedChild = child
                            onSelect(child)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 孩子卡片

private struct ChildCard: View {
    let child: Child
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            // 头像
            ZStack {
                if let avatarURL = child.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                // 选中指示器
                if isSelected {
                    Circle()
                        .stroke(Color.appPrimary, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                // 名字
                Text(child.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .appPrimary : .primary)
                    .lineLimit(1)

                // 班级或积分
                if let className = child.class?.name {
                    Text(className)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let points = child.totalPoints {
                    Text("\(points) 积分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // 选中勾选
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appPrimary)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.appPrimary.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.appPrimary.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Text(child.avatarLetter)
                    .font(.headline)
                    .foregroundColor(.appPrimary)
            )
    }
}

// MARK: - 只读模式提示横幅

struct ParentModeBanner: View {
    let childName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 14))
            Text("正在查看 \(childName) 的学习记录")
                .font(.subheadline)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue)
    }
}

#Preview {
    VStack {
        ChildSelectorBar(
            selectedChild: .constant(nil),
            children: [
                Child(
                    id: "1",
                    username: "xiaoming",
                    email: nil,
                    avatar: nil,
                    totalPoints: 1200,
                    createdAt: nil,
                    profile: ChildProfile(id: nil, nickname: "小明", bio: nil, grade: "三年级"),
                    class: ChildClass(id: nil, name: "三年级1班", school: nil)
                ),
                Child(
                    id: "2",
                    username: "xiaohong",
                    email: nil,
                    avatar: nil,
                    totalPoints: 980,
                    createdAt: nil,
                    profile: ChildProfile(id: nil, nickname: "小红", bio: nil, grade: "五年级"),
                    class: ChildClass(id: nil, name: "五年级2班", school: nil)
                )
            ],
            onSelect: { _ in }
        )

        ParentModeBanner(childName: "小明")

        Spacer()
    }
}
