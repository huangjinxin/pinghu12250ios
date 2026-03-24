# iOS 消息域架构说明

## 当前状态

当前 iOS 端消息域已经按职责拆成 4 层：

- `Features/Main`：消息壳层，负责左侧菜单、右侧详情区、消息/通讯录/更多/个人的切换
- `Features/IM`：联系人 IM Core，只负责人与人单聊、会话打开、未读、已读、实时接收
- `Features/Chat`：Bot Chat，只负责 AI 老师会话、卡片消息、Bot 列表与跳转
- `Core/UI`：消息域复用的基础 UI 能力，目前包括 `QRCameraView`

这次整理后，旧入口和残留结构已清理：

- 已移除：`ContentView.swift`
- 已移除：`Features/Home/AppRootView.swift`
- 已移除：`Features/Deprecated/`
- 已移除：`Features/Works/ios-app/` 异常空嵌套目录

---

## 主入口结构

当前 App 主入口：

```text
pinghu12250App
└── RootView
    ├── ParentTabView        (家长角色)
    └── SidebarNavigationView (非家长角色)
```

关键文件：

- `pinghu12250/RootView.swift`
- `pinghu12250/Features/Main/SidebarNavigationView.swift`

`RootView` 不再走旧的 `ContentView` 或 `AppRootView`。

---

## 消息域模块边界

### 1. Main Shell

`Features/Main` 是消息域外壳，不保存消息业务数据，只负责编排。

主要职责：

- 左侧菜单切换
- 消息/通讯录/更多/个人四个域的容器编排
- Bot 会话与 IM 会话的右侧详情区切换
- 顶部消息连接状态条显示
- 消息未读徽标聚合
- 统一消费导航通知：`.openConversation`、`.openBotConversation`

关键文件：

- `pinghu12250/Features/Main/SidebarNavigationView.swift`
- `pinghu12250/Features/Main/ConversationListSidebarView.swift`
- `pinghu12250/Features/Main/MenuButtonsView.swift`
- `pinghu12250/Features/Main/MessageSelection.swift`

### 2. IM Core

`Features/IM` 是当前跨端最重要的参考边界。

范围只包含：

- 好友单聊会话列表
- 打开/创建会话
- 单聊消息加载
- 发送消息
- 实时接收消息
- 未读数与已读状态
- 新好友、加好友入口

关键文件：

```text
Features/IM/
├── IMCoordinator.swift
├── IMConversationStore.swift
├── IMMessageStore.swift
├── IMPersistence.swift
├── IMRouteState.swift
├── Models/
│   ├── IMConversation.swift
│   ├── IMMessage.swift
│   └── UserSearchResult.swift
├── Services/
│   ├── IMService.swift
│   ├── FriendService.swift
│   └── IMNavigationHelper.swift
├── ViewModels/
│   ├── IMChatViewModel.swift
│   └── IMConversationListViewModel.swift
└── Views/
    ├── IMAddFriendView.swift
    ├── IMChatView.swift
    ├── IMConversationListView.swift
    ├── IMFriendListView.swift
    ├── IMMessageBubble.swift
    └── IMNewFriendsView.swift
```

### 3. Bot Chat

`Features/Chat` 现在不再承载联系人 IM，而是明确只负责 Bot Chat。

关键文件：

```text
Features/Chat/
├── Models/ChatModels.swift
├── Services/ChatService.swift
├── ViewModels/ChatViewModel.swift
└── Views/
    ├── BotAvatarView.swift
    ├── CardMessageView.swift
    ├── ChatBubble.swift
    └── ChatView.swift
```

职责：

- Bot 列表与 Bot 会话数据模型
- Bot 历史消息加载与发送
- Bot 卡片消息跳转到业务页面
- AI 老师入口复用

### 4. 通用基础能力

`Core/UI/QRCameraView.swift` 是扫码底层组件。

当前被以下页面复用：

- `Features/Contacts/FriendQRScannerView.swift`

---

## 网络与状态关系

### IM 链路

```text
IMChatView / SidebarNavigationView
        ↓
IMChatViewModel / IMCoordinator
        ↓
IMMessageStore / IMConversationStore
        ↓
IMService (REST) + SocketManager (实时)
        ↓
Backend IM API / Socket.IO
```

### Bot 链路

```text
ChatView
   ↓
ChatViewModel
   ↓
ChatService
   ↓
Backend Bot API
```

---

## API 与实时职责划分

### IM

IM 当前采用混合模式，但主发送链路已经固定：

- REST：会话列表、历史消息、标记已读、发送消息、创建/获取会话
- Socket：实时接收 `new_message`、同步补偿、连接状态

这意味着：

- **发送消息主通道是 REST，不是 Socket**
- Socket 只承担实时接收和增强

关键文件：

- `pinghu12250/Core/Network/APIConfig.swift`
- `pinghu12250/Core/Network/SocketManager.swift`
- `pinghu12250/Features/IM/Services/IMService.swift`
- `pinghu12250/Features/IM/IMMessageStore.swift`

### Bot Chat

Bot Chat 当前仍是纯 REST：

- Bot 列表
- Bot 会话列表
- Bot 消息历史
- 发送消息
- 二维码扫描业务接口

关键文件：

- `pinghu12250/Features/Chat/Services/ChatService.swift`

---

## 当前推荐的跨端参考边界

为后续 Web / Android 对齐，建议直接参考以下语义边界：

- `MessageShell` → iOS 对应 `Features/Main`
- `IM Core` → iOS 对应 `Features/IM`
- `Bot Chat` → iOS 对应 `Features/Chat`
- `Contacts` → iOS 对应 `Features/Contacts`

不要再把 Bot Chat 和联系人 IM 混在一个目录里。

---

## 当前已知特点

1. `SidebarNavigationView` 是总装配层，当前负责消息域整体编排
2. `IMConversationStore` 是会话真源，视图应直接观察它的 `@Published` 状态
3. `IMMessageStore` 是消息真源，负责发送、接收、失败重试、未读预览更新
4. `SocketManager` 当前只服务 IM，不服务 Bot Chat
5. `IMNavigationHelper` 只做通知分发，不直接做数据写入

---

## 整理结论

当前文件结构已经基本整理完成，消息域边界如下：

- Main：壳层
- IM：联系人即时通讯核心
- Chat：Bot 会话
- Core/UI：可复用基础组件

这套结构已经可以作为 Web 和 Android 后续对齐时的参考基线。
