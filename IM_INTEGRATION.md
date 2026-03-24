# iOS 消息模块集成说明

## 当前集成状态

当前 iOS 消息域已经落地为以下结构：

```text
RootView
└── SidebarNavigationView
    ├── Main Shell
    ├── IM Core
    └── Bot Chat
```

说明：

- 主入口已是 `RootView -> SidebarNavigationView`
- 不再使用旧的 `ContentView` 和 `AppRootView`
- `Features/IM` 与 `Features/Chat` 已按职责分开

---

## 目录结构

### Main Shell

- `pinghu12250/Features/Main/SidebarNavigationView.swift`
- `pinghu12250/Features/Main/ConversationListSidebarView.swift`
- `pinghu12250/Features/Main/MessageSelection.swift`

### IM Core

- `pinghu12250/Features/IM/IMCoordinator.swift`
- `pinghu12250/Features/IM/IMConversationStore.swift`
- `pinghu12250/Features/IM/IMMessageStore.swift`
- `pinghu12250/Features/IM/Services/IMService.swift`
- `pinghu12250/Features/IM/Services/FriendService.swift`
- `pinghu12250/Features/IM/Services/IMNavigationHelper.swift`
- `pinghu12250/Features/IM/ViewModels/IMChatViewModel.swift`
- `pinghu12250/Features/IM/ViewModels/IMConversationListViewModel.swift`
- `pinghu12250/Features/IM/Views/IMChatView.swift`
- `pinghu12250/Features/IM/Views/IMConversationListView.swift`
- `pinghu12250/Features/IM/Views/IMAddFriendView.swift`
- `pinghu12250/Features/IM/Views/IMFriendListView.swift`
- `pinghu12250/Features/IM/Views/IMNewFriendsView.swift`

### Bot Chat

- `pinghu12250/Features/Chat/Models/ChatModels.swift`
- `pinghu12250/Features/Chat/Services/ChatService.swift`
- `pinghu12250/Features/Chat/ViewModels/ChatViewModel.swift`
- `pinghu12250/Features/Chat/Views/ChatView.swift`
- `pinghu12250/Features/Chat/Views/CardMessageView.swift`
- `pinghu12250/Features/Chat/Views/ChatBubble.swift`
- `pinghu12250/Features/Chat/Views/BotAvatarView.swift`

### 通用基础组件

- `pinghu12250/Core/Network/SocketManager.swift`
- `pinghu12250/Core/UI/QRCameraView.swift`

---

## 当前职责划分

### IMService

职责：

- 获取联系人会话列表
- 获取聊天历史
- 标记已读
- 发送联系人消息
- 创建/获取联系人会话

### SocketManager

职责：

- 管理 IM Socket.IO 连接
- 接收 `new_message`
- 接收 `message_sent`
- 接收 `sync_result`
- 维护连接状态

说明：

- 当前 SocketManager 只服务 IM
- Bot Chat 不走 SocketManager

### IMConversationStore

职责：

- 会话列表真源
- 打开会话流程状态
- 选中会话状态
- 会话预览更新

### IMMessageStore

职责：

- 消息真源
- 发送消息
- 收到新消息后更新本地状态
- 已读处理
- 错误状态与重试

### ChatService / ChatViewModel

职责：

- Bot 列表
- Bot 会话
- Bot 消息
- Bot 卡片跳转

---

## 当前 API 约定

### IM

- REST 主发送链路
- Socket 负责实时接收与增强

关键接口：

- `/api/messages/conversations/list`
- `/api/messages/:userId`
- `/api/messages/mark-chat-read`
- `/api/messages/send`
- `/api/conversations/create-or-get`

### Bot Chat

关键接口：

- `/api/bot`
- `/api/chat-message/conversations`
- `/api/chat-message/:botId/messages`
- `/api/chat-message/:botId/send`
- `/api/scan`

---

## 集成检查点

当前需要确认的，不是“是否有旧文件”，而是下面这些关键关系是否持续成立：

1. `RootView` 始终进入 `SidebarNavigationView`
2. IM 发送消息走 REST
3. Socket 握手时带 token
4. `IMConversationStore` 是会话状态真源
5. `IMMessageStore` 是消息状态真源
6. Bot Chat 与 IM 不混目录、不混 API

---

## 整理后的结论

当前结构已经适合继续作为后续 Web / Android 对齐参考。

推荐跨端直接沿用这套边界：

- `Main Shell`
- `IM Core`
- `Bot Chat`
- `Contacts`
- `Core Reusable UI`
