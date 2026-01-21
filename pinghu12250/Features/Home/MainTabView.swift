//
//  MainTabView.swift
//  pinghu12250
//
//  主 Tab 导航视图 - iPad 响应式优化
//

import SwiftUI
import Combine

// MARK: - Tab 导航通知
extension Notification.Name {
    static let switchToGrowthTab = Notification.Name("switchToGrowthTab")
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var sidebarCollapsed = false
    @State private var customSidebarWidth: CGFloat = 136  // 可拖动调整的宽度
    @State private var isDraggingSidebar = false
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // 侧边栏宽度限制
    private let minSidebarWidth: CGFloat = 60
    private let maxSidebarWidth: CGFloat = 200

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "仪表盘"
        case growth = "心路"
        case diary = "日记"
        case homework = "作业"
        case reading = "读书"
        case writing = "书写"
        case notes = "笔记"
        case photos = "照片"
        case works = "作品"
        case wallet = "钱包"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .growth: return "star.fill"
            case .diary: return "book.closed.fill"
            case .homework: return "doc.text.fill"
            case .reading: return "books.vertical.fill"
            case .writing: return "pencil.tip.crop.circle"
            case .notes: return "note.text"
            case .photos: return "photo.on.rectangle.angled"
            case .works: return "paintpalette.fill"
            case .wallet: return "creditcard.fill"
            }
        }

        var color: Color {
            switch self {
            case .dashboard: return .indigo
            case .growth: return .orange
            case .diary: return .purple
            case .homework: return .blue
            case .reading: return .green
            case .writing: return .brown
            case .notes: return .yellow
            case .photos: return .teal
            case .works: return .pink
            case .wallet: return .cyan
            }
        }
    }

    // 根据横竖屏自动调整侧边栏
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    // 侧边栏宽度
    private var sidebarWidth: CGFloat {
        if isCompact {
            return 60
        }
        if sidebarCollapsed {
            return 60
        }
        return customSidebarWidth
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 侧边栏
                sidebarContent
                    .frame(width: sidebarWidth)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 0)

                // 拖动手柄（仅横屏且非折叠状态显示）
                if !isCompact && !sidebarCollapsed {
                    sidebarResizeHandle
                }

                // 主内容区
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: horizontalSizeClass) { _, newValue in
            // 横屏自动展开，竖屏自动折叠
            withAnimation(.easeInOut(duration: 0.2)) {
                sidebarCollapsed = (newValue == .compact)
            }
        }
        .onAppear {
            sidebarCollapsed = isCompact
        }
        // 监听跳转到心路 Tab 的通知
        .onReceive(NotificationCenter.default.publisher(for: .switchToGrowthTab)) { notification in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = .growth
            }
            // 如果通知中包含要选择的 tab index，延迟发送子Tab切换通知
            // 确保 MyGrowthView 已经加载完成
            if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NotificationCenter.default.post(
                        name: Notification.Name("switchGrowthSubTab"),
                        object: nil,
                        userInfo: ["tabIndex": tabIndex]
                    )
                }
            }
        }
    }

    // MARK: - 拖动手柄

    private var sidebarResizeHandle: some View {
        // 扩大拖动区域，提高易用性
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20)  // 扩大到20pt
            .contentShape(Rectangle())
            .overlay(
                // 视觉指示器
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDraggingSidebar ? Color.appPrimary : Color.gray.opacity(0.3))
                    .frame(width: isDraggingSidebar ? 6 : 4, height: isDraggingSidebar ? 60 : 40)
                    .animation(.easeInOut(duration: 0.15), value: isDraggingSidebar)
            )
            .gesture(
                DragGesture(minimumDistance: 5)  // 增加最小距离，减少误触
                    .onChanged { value in
                        isDraggingSidebar = true
                        let newWidth = customSidebarWidth + value.translation.width
                        customSidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
                    }
                    .onEnded { _ in
                        isDraggingSidebar = false
                        // 如果宽度小于阈值，自动折叠
                        if customSidebarWidth < 80 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sidebarCollapsed = true
                                customSidebarWidth = 136
                            }
                        }
                    }
            )
            .onHover { hovering in
                // macOS/iPad 鼠标悬停时改变光标
                #if targetEnvironment(macCatalyst)
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
                #endif
            }
    }

    // MARK: - 侧边栏

    @State private var showSystemSettings = false

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Logo/标题
            VStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appPrimary)

                if !sidebarCollapsed && !isCompact {
                    Text("苹湖")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)

            Divider()

            // 导航项
            ScrollView {
                VStack(spacing: 4) {
                    sidebarSection("首页", tabs: [.dashboard])
                    sidebarSection("学习", tabs: [.diary, .homework, .reading, .writing, .notes])
                    sidebarSection("社区", tabs: [.growth, .photos, .works])
                    sidebarSection("账户", tabs: [.wallet])
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // 底部用户信息和设置
            VStack(spacing: 8) {
                // 用户名（点击进入设置）
                Button {
                    showSystemSettings = true
                } label: {
                    Group {
                        if sidebarCollapsed || isCompact {
                            // 折叠时：头像居中
                            Circle()
                                .fill(Color.appPrimary.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(authManager.currentUser?.avatarLetter ?? "用")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appPrimary)
                                )
                        } else {
                            // 展开时：头像+名字
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.appPrimary.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(authManager.currentUser?.avatarLetter ?? "用")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appPrimary)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(authManager.currentUser?.nickname ?? authManager.currentUser?.username ?? "用户")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text("设置")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "gearshape.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showSystemSettings) {
            SystemSettingsView()
                .environmentObject(authManager)
        }
        // 折叠/展开按钮移到底部，避免与拖动手柄冲突
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

    private func sidebarSection(_ title: String, tabs: [Tab]) -> some View {
        VStack(spacing: 2) {
            if !sidebarCollapsed && !isCompact {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            ForEach(tabs) { tab in
                sidebarItem(tab)
            }
        }
    }

    private func sidebarItem(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Group {
                if sidebarCollapsed || isCompact {
                    // 折叠时：图标居中
                    Image(systemName: tab.icon)
                        .font(.system(size: 18))
                        .foregroundColor(selectedTab == tab ? tab.color : tab.color.opacity(0.6))
                        .frame(maxWidth: .infinity)
                } else {
                    // 展开时：图标+文字靠左
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

    // MARK: - 详情内容

    @ViewBuilder
    private var detailContent: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .growth:
                    MyGrowthView()
                case .diary:
                    DiaryListView()
                case .homework:
                    HomeworkListView()
                case .reading:
                    ReadingView()
                case .writing:
                    WritingView()
                case .notes:
                    NotesMainView()
                case .photos:
                    PhotosView()
                case .works:
                    WorksGalleryView()
                case .wallet:
                    WalletView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
