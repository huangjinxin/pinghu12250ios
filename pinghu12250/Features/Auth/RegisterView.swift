//
//  RegisterView.swift
//  pinghu12250
//
//  注册页面
//

import SwiftUI
import Combine

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""
    @State private var email = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case username, password, confirmPassword, nickname, email
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 表单区域
                    VStack(spacing: 16) {
                        // 用户名（必填）
                        inputField(
                            icon: "person.fill",
                            placeholder: "用户名（必填）",
                            text: $username,
                            field: .username
                        )
                        .textContentType(.username)
                        .autocapitalization(.none)

                        // 密码（必填）
                        secureField(
                            icon: "lock.fill",
                            placeholder: "密码（必填）",
                            text: $password,
                            field: .password
                        )

                        // 确认密码（必填）
                        secureField(
                            icon: "lock.fill",
                            placeholder: "确认密码",
                            text: $confirmPassword,
                            field: .confirmPassword
                        )

                        // 昵称（选填）
                        inputField(
                            icon: "face.smiling",
                            placeholder: "昵称（选填）",
                            text: $nickname,
                            field: .nickname
                        )

                        // 邮箱（选填）
                        inputField(
                            icon: "envelope.fill",
                            placeholder: "邮箱（选填）",
                            text: $email,
                            field: .email
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    }

                    // 密码不匹配提示
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("两次输入的密码不一致")
                        }
                        .font(.caption)
                        .foregroundColor(.appError)
                    }

                    // 错误提示
                    if let error = authManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.appError)
                        .cornerRadius(12)
                    }

                    // 注册按钮
                    Button(action: register) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("注册")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.appPrimary : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading)

                    // 用户协议
                    Text("注册即表示同意")
                        .foregroundColor(.secondary) +
                    Text("《用户协议》")
                        .foregroundColor(.appPrimary) +
                    Text("和")
                        .foregroundColor(.secondary) +
                    Text("《隐私政策》")
                        .foregroundColor(.appPrimary)
                }
                .font(.caption)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("创建账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    // MARK: - 输入框组件

    private func inputField(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            SecureField(placeholder, text: text)
                .textContentType(.newPassword)
                .focused($focusedField, equals: field)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 计算属性

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    // MARK: - 方法

    private func register() {
        guard isFormValid else { return }
        focusedField = nil

        Task {
            let success = await authManager.register(
                username: username,
                password: password,
                nickname: nickname.isEmpty ? nil : nickname,
                email: email.isEmpty ? nil : email
            )
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    RegisterView()
}
