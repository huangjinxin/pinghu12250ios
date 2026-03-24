# 苹湖少儿空间 iOS App

基于 SwiftUI 构建的 iPad 教育应用，包含学习、教材、日记、作品、家长端，以及已经整理完成的消息域结构。

## 技术栈

| 类别 | 技术选型 |
|------|---------|
| UI 框架 | SwiftUI |
| 架构模式 | MVVM + Store + 单向数据流 |
| 网络层 | URLSession + async/await |
| 实时通讯 | Socket.IO |
| 本地存储 | CoreData + UserDefaults |
| PDF 渲染 | PDFKit |
| 手写输入 | PencilKit |
| 语音识别 | Speech Framework |

## 当前主入口

当前 App 主入口链路：

```text
pinghu12250App
└── RootView
    ├── ParentTabView         # 家长角色
    └── SidebarNavigationView # 非家长角色
```

说明：

- `ContentView.swift` 已移除
- `Features/Home/AppRootView.swift` 已移除
- 旧 `MainTabView` / `NewMainTabView` 已移除
- 当前消息与主导航统一由 `SidebarNavigationView` 承担

## 项目结构

```text
pinghu12250/
├── Core/                      # 核心基础设施
│   ├── Network/               # APIConfig, APIService, SocketManager, RequestController
│   ├── Services/              # AppSettings, DownloadManager, Cache 等
│   ├── Models/                # 通用模型
│   ├── Extensions/            # Swift 扩展
│   ├── UI/                    # 复用 UI（含 QRCameraView）
│   ├── Stability/             # 安全解码、状态校验、保护逻辑
│   ├── Watchdog/              # 主线程看门狗
│   ├── Sync/                  # 同步能力
│   ├── Audio/                 # 音频录制/上传
│   ├── Speech/                # 语音输入
│   └── Concurrency/           # 并发工具
│
├── Features/
│   ├── Auth/                  # 登录注册
│   ├── Main/                  # 主壳层、侧栏、消息编排
│   ├── IM/                    # 联系人即时通讯核心
│   ├── Chat/                  # Bot Chat
│   ├── Contacts/              # 通讯录、好友、新朋友、AI老师
│   ├── Dashboard/             # 学习仪表盘
│   ├── Diary/                 # 日记与成就
│   ├── Study/                 # 阅读器、笔记、练习、批注、手写
│   ├── Textbook/              # 教材列表与详情
│   ├── Works/                 # 作品
│   ├── Wallet/                # 钱包
│   ├── Photos/                # 照片
│   ├── Parent/                # 家长端
│   ├── Profile/               # 个人中心
│   ├── More/                  # 更多功能页
│   ├── Feed/                  # 动态
│   ├── Friends/               # 朋友关系页
│   ├── Growth/                # 成长页
│   ├── Homework/              # 作业
│   ├── Moments/               # 广场/动态卡片
│   ├── Pinyin/                # 拼音练习
│   ├── Points/                # 积分
│   ├── Reading/               # 阅读模块
│   ├── Settings/              # 系统设置
│   ├── Shopping/              # 兑换/购物
│   ├── Sync/                  # 同步页
│   ├── Timeline/              # 时间线
│   ├── Tools/                 # 工具页
│   └── Writing/               # 书写练习
│
├── Mock/                      # Mock 数据
└── Assets.xcassets/           # 图片与图标资源
```

## 消息域结构

当前消息域已经整理成清晰边界：

### 1. Main Shell

负责整体装配，不直接保存消息真状态：

- `Features/Main/SidebarNavigationView.swift`
- `Features/Main/ConversationListSidebarView.swift`
- `Features/Main/MessageSelection.swift`

职责：

- 左侧菜单切换
- 消息/通讯录/更多/个人容器编排
- Bot 会话与 IM 会话详情切换
- 顶部连接状态条
- 未读徽标聚合

### 2. IM Core

负责联系人即时通讯：

- `Features/IM/IMCoordinator.swift`
- `Features/IM/IMConversationStore.swift`
- `Features/IM/IMMessageStore.swift`
- `Features/IM/Services/IMService.swift`
- `Features/IM/Services/FriendService.swift`
- `Features/IM/Services/IMNavigationHelper.swift`
- `Features/IM/Views/*`

职责：

- 会话列表
- 打开会话
- 历史消息
- 发送消息
- 实时接收
- 已读/未读
- 加好友 / 新朋友

### 3. Bot Chat

负责 AI 老师 / Bot 对话：

- `Features/Chat/Models/ChatModels.swift`
- `Features/Chat/Services/ChatService.swift`
- `Features/Chat/ViewModels/ChatViewModel.swift`
- `Features/Chat/Views/ChatView.swift`
- `Features/Chat/Views/CardMessageView.swift`
- `Features/Chat/Views/ChatBubble.swift`
- `Features/Chat/Views/BotAvatarView.swift`

职责：

- Bot 列表
- Bot 会话
- Bot 文本消息
- 卡片消息导航

### 4. Contacts

负责关系入口：

- 好友列表
- 新的朋友
- 加好友
- 好友二维码
- AI 老师入口

### 5. Core/UI

消息域复用组件：

- `Core/UI/QRCameraView.swift`

## 消息链路说明

### IM

IM 当前采用 REST + Socket 混合模式：

- REST：拉会话、拉历史、标记已读、发送消息、创建会话
- Socket：实时接收、同步补偿、连接状态

关键原则：

- **发送消息主通道是 REST**
- Socket 只做实时接收与增强

### Bot Chat

Bot Chat 当前是纯 REST 模式。

## 当前已完成的结构整理

已完成：

- 删除未使用旧入口文件
- 删除 `Deprecated` 旧消息页面
- 删除异常空嵌套目录 `Features/Works/ios-app/`
- 将 `ConversationListSidebarView` 归入 `Features/Main`
- 将 `QRCameraView` 归入 `Core/UI`
- 保留 `Features/Chat` 作为 Bot Chat，而不再混入联系人 IM
- 构建通过

## API 说明

后端服务：Express + Prisma + PostgreSQL

当前 `APIConfig.swift` 使用无 `/api` 的 base URL，具体 endpoint 自带 `/api/...` 前缀。

示例：

```swift
static let localBaseURL = "http://192.168.88.228:12251"
static let productionBaseURL = "https://kids.706tech.cn"
```

消息相关接口分两套：

### IM 接口

- `/api/messages/conversations/list`
- `/api/messages/:userId`
- `/api/messages/mark-chat-read`
- `/api/messages/send`
- `/api/conversations/create-or-get`

### Bot Chat 接口

- `/api/bot`
- `/api/chat-message/conversations`
- `/api/chat-message/:botId/messages`
- `/api/chat-message/:botId/send`
- `/api/scan`

## 开发环境

### 要求

- macOS 13+
- Xcode 15+
- iOS / iPadOS 开发环境

### 运行方式

```bash
open pinghu12250.xcodeproj
```

然后在 Xcode 中选择模拟器或真机运行。

## 测试账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 学生 | xiaoming | 123456 |
| 家长 | parent_ming | 123456 |
| 老师 | teacher_wang | 123456 |

## 相关文档

- `IM_ARCHITECTURE.md`：消息域架构说明
- `IM_SUMMARY.md`：消息域整理总结
- `IM_INTEGRATION.md`：消息模块集成说明
- `IM_TEST_GUIDE.md`：IM 测试指南
- `IM_TEST_CHECKLIST.md`：IM 测试检查表

## 当前结论

当前 iOS 文件结构已经基本整理完成，消息域边界已清晰，可作为后续 Web / Android 对齐时的参考基线。
