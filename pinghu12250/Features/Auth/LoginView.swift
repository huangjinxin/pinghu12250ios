//
//  LoginView.swift
//  pinghu12250
//
//  登录页面 - iPad 优化
//

import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isShowingRegister = false
    @State private var twoFactorCode = ""
    @State private var useBackupCode = false
    @FocusState private var focusedField: Field?

    enum Field {
        case username, password, twoFactorCode
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧品牌区域（iPad）
                if geometry.size.width > 600 {
                    brandSection
                        .frame(width: geometry.size.width * 0.45)
                }

                // 右侧登录表单
                ScrollView {
                    VStack(spacing: 0) {
                        // 移动端 Logo
                        if geometry.size.width <= 600 {
                            compactHeader
                                .padding(.top, 60)
                        }

                        // 登录表单
                        loginFormSection
                            .padding(.top, geometry.size.width > 600 ? 100 : 40)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 40)
                    .frame(minHeight: geometry.size.height)
                }
                .frame(maxWidth: geometry.size.width > 600 ? geometry.size.width * 0.55 : .infinity)
                .background(Color(.systemBackground))
            }
        }
        .ignoresSafeArea()
        .onTapGesture {
            focusedField = nil
        }
        .sheet(isPresented: $isShowingRegister) {
            RegisterView()
        }
    }

    // MARK: - 品牌区域（iPad 左侧）

    private var brandSection: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 24) {
                // 使用自定义 Logo
                AppLogo(size: 100, showText: false)
                    .colorScheme(.dark)

                Text("苹湖少儿空间")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("记录成长，启迪未来")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 16) {
                    FeatureItem(icon: "book.fill", text: "丰富的学习资源")
                    FeatureItem(icon: "chart.line.uptrend.xyaxis", text: "成长轨迹追踪")
                    FeatureItem(icon: "person.3.fill", text: "互动社区交流")
                }
                .padding(.top, 40)
            }
            .padding(40)
        }
    }

    // MARK: - 紧凑头部（移动端）

    private var compactHeader: some View {
        VStack(spacing: 16) {
            // 使用自定义 Logo
            AppLogo(size: 80)

            Text("欢迎回来")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 登录表单

    private var loginFormSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 根据 2FA 状态显示不同内容
            if authManager.requiresTwoFactor {
                twoFactorSection
            } else {
                normalLoginSection
            }
        }
        .frame(maxWidth: 400)
    }

    // MARK: - 正常登录表单

    private var normalLoginSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("登录账户")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                // 用户名
                VStack(alignment: .leading, spacing: 8) {
                    Text("用户名")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                        TextField("请输入用户名", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // 密码
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                        SecureField("请输入密码", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            // 错误提示
            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appError)
                .cornerRadius(12)
            }

            // 登录按钮
            Button(action: login) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("登录")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isFormValid ? Color.appPrimary : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authManager.isLoading)

            // 注册链接
            HStack {
                Text("还没有账号？")
                    .foregroundColor(.secondary)
                Button("立即注册") {
                    isShowingRegister = true
                }
                .foregroundColor(.appPrimary)
                .fontWeight(.medium)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)

            // 演示账户
            demoAccountsSection
        }
    }

    // MARK: - 两步验证表单

    private var twoFactorSection: some View {
        VStack(alignment: .center, spacing: 24) {
            // 图标和标题
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)

                Text("两步验证")
                    .font(.title)
                    .fontWeight(.bold)

                Text("请打开您的身份验证器应用\n输入 6 位验证码")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text(useBackupCode ? "恢复码" : "验证码")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.secondary)
                    TextField(useBackupCode ? "XXXX-XXXX-XXXX" : "000000", text: $twoFactorCode)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(useBackupCode ? .default : .numberPad)
                        .focused($focusedField, equals: .twoFactorCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: useBackupCode ? 16 : 24, weight: .medium, design: .monospaced))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // 使用恢复码切换
            Toggle("使用恢复码", isOn: $useBackupCode)
                .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                .font(.subheadline)
                .onChange(of: useBackupCode) { _ in
                    twoFactorCode = ""
                }

            // 错误提示
            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appError)
                .cornerRadius(12)
            }

            // 验证按钮
            Button(action: verifyTwoFactor) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("验证")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isTwoFactorValid ? Color.appPrimary : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isTwoFactorValid || authManager.isLoading)

            // 返回按钮
            Button(action: cancelTwoFactor) {
                Text("返回登录")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
    }

    // MARK: - 演示账户

    private var demoAccountsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            Text("演示账户")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                DemoAccountButton(role: "老师", username: "teacher_wang") {
                    username = "teacher_wang"
                    password = "123456"
                }

                DemoAccountButton(role: "学生", username: "xiaoming") {
                    username = "xiaoming"
                    password = "123456"
                }
            }

            Text("密码: 123456")
                .font(.caption2)
                .foregroundColor(.secondary)

            // 服务器配置入口
            Divider()
                .padding(.vertical, 8)

            ServerSelectorCompact()
        }
    }

    // MARK: - 计算属性

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private var isTwoFactorValid: Bool {
        if useBackupCode {
            // 恢复码格式: XXXX-XXXX-XXXX 或 12 位字符（不带横杠）
            let cleanCode = twoFactorCode.replacingOccurrences(of: "-", with: "")
            return cleanCode.count == 12
        } else {
            // TOTP 验证码: 6 位数字
            return twoFactorCode.count == 6 && twoFactorCode.allSatisfy { $0.isNumber }
        }
    }

    // MARK: - 方法

    private func login() {
        guard isFormValid else { return }
        focusedField = nil

        Task {
            await authManager.login(username: username, password: password)
        }
    }

    private func verifyTwoFactor() {
        guard isTwoFactorValid else { return }
        focusedField = nil

        Task {
            await authManager.verifyTwoFactor(code: twoFactorCode)
        }
    }

    private func cancelTwoFactor() {
        authManager.cancelTwoFactor()
        twoFactorCode = ""
        useBackupCode = false
    }
}

// MARK: - 辅助组件

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 30)

            Text(text)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct DemoAccountButton: View {
    let role: String
    let username: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(role)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(username)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
