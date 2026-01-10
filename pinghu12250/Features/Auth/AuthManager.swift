//
//  AuthManager.swift
//  pinghu12250
//
//  认证管理器 - 管理用户登录状态
//

import Foundation
import SwiftUI
import Combine

/// 认证管理器
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // 两步验证 (2FA) 状态
    @Published var requiresTwoFactor = false
    @Published var tempToken: String?
    @Published var twoFactorUsedBackup = false
    @Published var twoFactorRemainingBackups: Int?

    private let apiService = APIService.shared
    private let userDefaultsKey = "currentUser"

    private init() {
        checkAuthStatus()
    }

    // MARK: - 检查认证状态

    /// 检查本地存储的认证状态
    func checkAuthStatus() {
        if apiService.isAuthenticated {
            // 尝试从本地加载用户信息
            if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                self.currentUser = user
                self.isAuthenticated = true
            } else {
                // 有 token 但没有用户信息，尝试获取
                Task {
                    await fetchCurrentUser()
                }
            }
        }
    }

    // MARK: - 登录

    /// 用户登录
    /// - Returns: true 表示登录成功或需要 2FA，false 表示登录失败
    func login(username: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = LoginRequest(username: username, password: password)
            let response: LoginResponse = try await apiService.post(APIConfig.Endpoints.login, body: request)

            // 检查是否需要两步验证
            if response.requiresTwoFactor == true, let tempToken = response.tempToken {
                self.requiresTwoFactor = true
                self.tempToken = tempToken
                isLoading = false
                return true  // 返回 true 表示需要继续 2FA 流程
            }

            // 正常登录流程
            guard let token = response.token, let user = response.user else {
                errorMessage = "登录响应格式错误"
                isLoading = false
                return false
            }

            // 保存 token
            apiService.authToken = token

            // 保存用户信息
            saveUser(user)

            isAuthenticated = true
            currentUser = user
            isLoading = false

            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 两步验证

    /// 验证两步验证码
    func verifyTwoFactor(code: String) async -> Bool {
        guard let tempToken = tempToken else {
            errorMessage = "验证会话已过期，请重新登录"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = TwoFactorVerifyRequest(tempToken: tempToken, code: code)
            let response: TwoFactorVerifyResponse = try await apiService.post(APIConfig.Endpoints.verifyTwoFactor, body: request)

            // 保存 token
            apiService.authToken = response.token

            // 保存用户信息
            saveUser(response.user)

            // 更新 2FA 状态
            if response.usedBackupCode == true {
                twoFactorUsedBackup = true
                twoFactorRemainingBackups = response.remainingBackupCodes
            }

            // 清除临时状态
            requiresTwoFactor = false
            self.tempToken = nil

            isAuthenticated = true
            currentUser = response.user
            isLoading = false

            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "验证失败：\(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 取消两步验证
    func cancelTwoFactor() {
        requiresTwoFactor = false
        tempToken = nil
        twoFactorUsedBackup = false
        twoFactorRemainingBackups = nil
        errorMessage = nil
    }

    /// 清除 2FA 提示状态
    func clearTwoFactorAlert() {
        twoFactorUsedBackup = false
        twoFactorRemainingBackups = nil
    }

    // MARK: - 注册

    /// 用户注册
    func register(username: String, password: String, nickname: String?, email: String?) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = RegisterRequest(
                username: username,
                password: password,
                email: email,
                nickname: nickname,
                role: "STUDENT"
            )
            let response: LoginResponse = try await apiService.post(APIConfig.Endpoints.register, body: request)

            // 注册响应必须包含 token 和 user
            guard let token = response.token, let user = response.user else {
                errorMessage = "注册响应格式错误"
                isLoading = false
                return false
            }

            // 保存 token
            apiService.authToken = token

            // 保存用户信息
            saveUser(user)

            isAuthenticated = true
            currentUser = user
            isLoading = false

            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "注册失败：\(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 登出

    /// 退出登录
    func logout() {
        apiService.clearToken()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentUser = nil
        isAuthenticated = false
        // 清除 2FA 状态
        requiresTwoFactor = false
        tempToken = nil
        twoFactorUsedBackup = false
        twoFactorRemainingBackups = nil
    }

    // MARK: - 删除账户

    /// 删除账户（需要密码确认）
    func deleteAccount(password: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = DeleteAccountRequest(password: password)
            let _: DeleteAccountResponse = try await apiService.delete(APIConfig.Endpoints.deleteAccount, body: request)

            // 删除成功，清除本地数据
            logout()

            isLoading = false
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return false
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 获取当前用户

    /// 获取当前用户信息
    func fetchCurrentUser() async {
        guard apiService.isAuthenticated else { return }

        do {
            let user: User = try await apiService.get(APIConfig.Endpoints.currentUser)
            saveUser(user)
            currentUser = user
            isAuthenticated = true
        } catch {
            // Token 可能已过期
            logout()
        }
    }

    // MARK: - 私有方法

    private func saveUser(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDefaultsKey)
        }
    }
}
