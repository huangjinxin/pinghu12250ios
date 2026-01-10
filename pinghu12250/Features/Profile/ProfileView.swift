//
//  ProfileView.swift
//  pinghu12250
//
//  个人中心 - 用户信息和设置
//

import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var activeTab: ProfileTab = .profile
    @State private var showLogoutAlert = false

    enum ProfileTab: String, CaseIterable {
        case profile = "基本信息"
        case privacy = "隐私设置"
        case security = "安全设置"
        case system = "系统设置"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 用户信息头部
                userHeader

                // 标签页
                tabPicker

                // 内容区域
                ScrollView {
                    Group {
                        switch activeTab {
                        case .profile:
                            ProfileInfoSection()
                        case .privacy:
                            PrivacySection()
                        case .security:
                            SecuritySection()
                        case .system:
                            SystemSection()
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("个人中心")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出登录", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }

    // MARK: - 用户头部

    private var userHeader: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(authManager.currentUser?.username.prefix(1) ?? "U").uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimary)
                    )

                Button {
                    // 头像更换功能
                } label: {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            }

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.currentUser?.username ?? "用户")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(authManager.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let role = authManager.currentUser?.role {
                    Text(role.label)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(role.color)
                        .cornerRadius(8)
                }
            }

            Spacer()

            // 统计数据
            HStack(spacing: 24) {
                StatColumn(value: "30", label: "加入天数")
                StatColumn(value: "15", label: "打卡天数", color: .green)
                StatColumn(value: "7", label: "连续打卡", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    ProfileTabButton(title: tab.rawValue, isSelected: activeTab == tab) {
                        activeTab = tab
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct StatColumn: View {
    let value: String
    let label: String
    var color: Color = .appPrimary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ProfileTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .appPrimary : .secondary)

                Rectangle()
                    .fill(isSelected ? Color.appPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 基本信息

struct ProfileInfoSection: View {
    @State private var nickname = ""
    @State private var grade = ""
    @State private var bio = ""
    @State private var interests: [String] = []
    @State private var newInterest = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 16) {
            // 昵称
            FormField(label: "昵称") {
                TextField("请输入昵称", text: $nickname)
                    .textFieldStyle(.roundedBorder)
            }

            // 年级
            FormField(label: "年级") {
                TextField("如：三年级", text: $grade)
                    .textFieldStyle(.roundedBorder)
            }

            // 个人简介
            FormField(label: "个人简介") {
                TextEditor(text: $bio)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }

            // 兴趣爱好
            FormField(label: "兴趣爱好") {
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(interests, id: \.self) { interest in
                            InterestTag(text: interest) {
                                interests.removeAll { $0 == interest }
                            }
                        }
                    }

                    HStack {
                        TextField("添加兴趣", text: $newInterest)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            if !newInterest.isEmpty {
                                interests.append(newInterest)
                                newInterest = ""
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // 保存按钮
            Button {
                Task { await saveProfile() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("保存修改")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func saveProfile() async {
        isSaving = true
        // 保存用户资料
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isSaving = false
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            content
        }
    }
}

struct InterestTag: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appPrimary.opacity(0.1))
        .foregroundColor(.appPrimary)
        .cornerRadius(15)
    }
}

// 简单的流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + maxHeight)
        }
    }
}

// MARK: - 隐私设置

struct PrivacySection: View {
    @State private var profilePublic = true
    @State private var showStats = true

    var body: some View {
        VStack(spacing: 0) {
            PrivacyToggleRow(
                title: "公开个人主页",
                description: "允许他人查看你的个人资料",
                isOn: $profilePublic
            )

            Divider()

            PrivacyToggleRow(
                title: "显示统计数据",
                description: "在个人主页展示学习统计",
                isOn: $showStats
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct PrivacyToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - 安全设置

struct SecuritySection: View {
    var body: some View {
        VStack(spacing: 16) {
            // 修改登录密码
            PasswordChangeCard(
                title: "修改登录密码",
                description: nil
            )

            // 支付密码
            PasswordChangeCard(
                title: "支付密码",
                description: "支付密码用于学习币消费时的安全验证",
                isPaymentPassword: true
            )
        }
    }
}

struct PasswordChangeCard: View {
    let title: String
    let description: String?
    var isPaymentPassword: Bool = false

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if isPaymentPassword {
                    Text("未设置（默认123456）")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            if let desc = description {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            SecureField(isPaymentPassword ? "原支付密码" : "旧密码", text: $oldPassword)
                .textFieldStyle(.roundedBorder)

            SecureField("新密码", text: $newPassword)
                .textFieldStyle(.roundedBorder)

            SecureField("确认密码", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await changePassword() }
            } label: {
                HStack {
                    if isChanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isPaymentPassword ? "设置支付密码" : "修改密码")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || isChanging)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func changePassword() async {
        guard newPassword == confirmPassword else { return }
        isChanging = true
        // 修改密码
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isChanging = false
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
}

// MARK: - 系统设置

struct SystemSection: View {
    @StateObject private var offlineManager = OfflineManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // 离线模式设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("离线模式")
                            .font(.headline)
                        Text("开启后将优先使用本地缓存数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { offlineManager.isOfflineMode },
                        set: { offlineManager.setOfflineMode($0) }
                    ))
                }

                Divider()

                // 网络状态
                HStack {
                    Image(systemName: offlineManager.isOnline ? "wifi" : "wifi.slash")
                        .foregroundColor(offlineManager.isOnline ? .green : .red)
                    Text(offlineManager.isOnline ? "网络已连接" : "网络已断开")
                        .font(.subheadline)
                    if offlineManager.isOnline {
                        Text("(\(offlineManager.connectionType.description))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // 缓存大小
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("缓存大小")
                            .font(.subheadline)
                        Text("包含教材PDF、诗词数据、图片等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(offlineManager.cacheSizeDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("清除") {
                        offlineManager.clearAllOfflineData()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }

                Divider()

                // 已下载教材数量
                HStack {
                    Text("已下载教材")
                        .font(.subheadline)
                    Spacer()
                    Text("\(offlineManager.offlineTextbookIds.count) 本")
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // 版本信息
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("苹湖少儿空间")
                            .font(.headline)
                        Text("Children Growth Platform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("v1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(8)
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // 技术栈
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TechItem(label: "客户端", value: "SwiftUI")
                    TechItem(label: "后端", value: "Node.js + Express")
                    TechItem(label: "数据库", value: "PostgreSQL")
                    TechItem(label: "平台", value: "iPad")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // 关于
            VStack(alignment: .leading, spacing: 12) {
                Text("关于我们")
                    .font(.headline)

                Text("苹湖少儿空间是一个面向青少年的综合性学习成长平台。我们致力于为孩子们提供一个安全、有趣、富有创造力的学习环境，帮助他们在编程、艺术、社交等多个领域全面发展。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                HStack(spacing: 16) {
                    Button("使用帮助") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("隐私政策") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("用户协议") { }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

struct TechItem: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + "：")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
