//
//  ParentTabView.swift
//  pinghu12250
//
//  家长专属TabView - 查看孩子的仪表盘/笔记/作品
//

import SwiftUI

struct ParentTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var children: [Child] = []
    @State private var selectedChild: Child?
    @State private var isLoading = true
    @State private var error: String?

    @State private var sidebarCollapsed = false
    @State private var customSidebarWidth: CGFloat = 136
    @State private var isDraggingSidebar = false

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let minSidebarWidth: CGFloat = 60
    private let maxSidebarWidth: CGFloat = 200

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "仪表盘"
        case diary = "日记"
        case notes = "笔记"
        case works = "作品"
        case settings = "设置"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .diary: return "book.closed.fill"
            case .notes: return "note.text"
            case .works: return "paintpalette.fill"
            case .settings: return "gearshape.fill"
            }
        }

        var color: Color {
            switch self {
            case .dashboard: return .indigo
            case .diary: return .orange
            case .notes: return .yellow
            case .works: return .pink
            case .settings: return .gray
            }
        }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var sidebarWidth: CGFloat {
        if isCompact { return 60 }
        if sidebarCollapsed { return 60 }
        return customSidebarWidth
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if children.isEmpty {
                noChildrenView
            } else {
                mainContent
            }
        }
        .onAppear {
            loadChildren()
        }
    }

    // MARK: - 主内容

    private var mainContent: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                sidebarContent
                    .frame(width: sidebarWidth)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 0)

                if !isCompact && !sidebarCollapsed {
                    sidebarResizeHandle
                }

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: horizontalSizeClass) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                sidebarCollapsed = (newValue == .compact)
            }
        }
        .onAppear {
            sidebarCollapsed = isCompact
        }
    }

    // MARK: - 侧边栏

    @State private var showSystemSettings = false

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Logo
            VStack(spacing: 4) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)

                if !sidebarCollapsed && !isCompact {
                    Text("家长中心")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)

            Divider()

            // 导航项
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        sidebarItem(tab)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // 底部用户信息
            Button {
                showSystemSettings = true
            } label: {
                Group {
                    if sidebarCollapsed || isCompact {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(authManager.currentUser?.avatarLetter ?? "家")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            )
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(authManager.currentUser?.avatarLetter ?? "家")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.currentUser?.displayName ?? "家长")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("家长账号")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showSystemSettings) {
            SystemSettingsView()
                .environmentObject(authManager)
        }
        .safeAreaInset(edge: .bottom) {
            if !isCompact {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                                .font(.system(size: 14))
                            if !sidebarCollapsed {
                                Text("收起")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func sidebarItem(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Group {
                if sidebarCollapsed || isCompact {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18))
                        .foregroundColor(selectedTab == tab ? tab.color : tab.color.opacity(0.6))
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .foregroundColor(tab.color)
                            .frame(width: 24)

                        Text(tab.rawValue)
                            .font(.subheadline)
                            .foregroundColor(selectedTab == tab ? tab.color : .primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? tab.color.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var sidebarResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDraggingSidebar ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: isDraggingSidebar ? 6 : 4, height: isDraggingSidebar ? 60 : 40)
                    .animation(.easeInOut(duration: 0.15), value: isDraggingSidebar)
            )
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        isDraggingSidebar = true
                        let newWidth = customSidebarWidth + value.translation.width
                        customSidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
                    }
                    .onEnded { _ in
                        isDraggingSidebar = false
                        if customSidebarWidth < 80 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sidebarCollapsed = true
                                customSidebarWidth = 136
                            }
                        }
                    }
            )
    }

    // MARK: - 详情内容

    @ViewBuilder
    private var detailContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 孩子选择器（放在页面内容顶部，随页面滚动）
                // 作品页面不需要选择孩子（显示公共作品）
                if selectedTab != .settings && selectedTab != .works {
                    ChildSelectorBar(
                        selectedChild: $selectedChild,
                        children: children,
                        onSelect: { child in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedChild = child
                            }
                        }
                    )
                }

                // 页面内容
                Group {
                    switch selectedTab {
                    case .dashboard:
                        if let child = selectedChild {
                            ParentDashboardView(childId: child.id)
                                .id(child.id) // 强制刷新
                                .environment(\.parentMode, true)
                                .environment(\.viewingChildId, child.id)
                                .environment(\.viewingChild, child)
                                .transition(.opacity)
                        } else {
                            selectChildPrompt
                        }
                    case .diary:
                        if let child = selectedChild {
                            ParentDiaryView(childId: child.id)
                                .id(child.id)
                                .environment(\.parentMode, true)
                                .environment(\.viewingChildId, child.id)
                                .environment(\.viewingChild, child)
                                .transition(.opacity)
                        } else {
                            selectChildPrompt
                        }
                    case .notes:
                        if let child = selectedChild {
                            ParentNotesView(childId: child.id)
                                .id(child.id)
                                .environment(\.parentMode, true)
                                .environment(\.viewingChildId, child.id)
                                .environment(\.viewingChild, child)
                                .transition(.opacity)
                        } else {
                            selectChildPrompt
                        }
                    case .works:
                        // 作品页面显示公共作品，不需要选择孩子
                        WorksGalleryView()
                            .transition(.opacity)
                    case .settings:
                        SystemSettingsView()
                    }
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 辅助视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
            Button("重试") {
                loadChildren()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var noChildrenView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无绑定的孩子")
                .font(.headline)
            Text("请联系管理员绑定孩子账号")
                .foregroundColor(.secondary)
        }
    }

    private var selectChildPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("请选择要查看的孩子")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据加载

    private func loadChildren() {
        isLoading = true
        error = nil

        Task {
            do {
                let response: ChildrenResponse = try await APIService.shared.get("/users/me/children")
                await MainActor.run {
                    children = response.children
                    // 默认选中第一个孩子
                    if selectedChild == nil, let first = children.first {
                        selectedChild = first
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "加载失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ParentTabView()
        .environmentObject(AuthManager.shared)
}
