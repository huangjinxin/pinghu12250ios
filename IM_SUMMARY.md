# iOS 消息域实现总结

## 当前结论

iOS 端消息功能已经形成清晰边界，当前不是单一 Chat 模块，而是拆成三部分：

- `Features/Main`：消息壳层与导航编排
- `Features/IM`：联系人 IM Core
- `Features/Chat`：Bot Chat

本次整理后，旧入口、空目录和混放文件已清理，结构已可作为后续 Web / Android 参考。

---

## 当前主入口

实际运行入口：

- `pinghu12250/RootView.swift`
- `pinghu12250/Features/Main/SidebarNavigationView.swift`

说明：

- 不再使用 `ContentView.swift`
- 不再使用 `Features/Home/AppRootView.swift`
- 不再使用 `Features/Deprecated/MainTabView.swift`
- 不再使用 `Features/Deprecated/NewMainTabView.swift`

---

## 当前消息域结构

### 1. IM Core

联系人即时通讯核心模块：

- 会话列表
- 打开会话
- 消息发送
- 消息接收
- 已读/未读
- 新朋友/加好友

核心文件：

- `Features/IM/IMCoordinator.swift`
- `Features/IM/IMConversationStore.swift`
- `Features/IM/IMMessageStore.swift`
- `Features/IM/Services/IMService.swift`
- `Features/IM/Views/IMChatView.swift`
- `Features/IM/Views/IMConversationListView.swift`

### 2. Bot Chat

Bot Chat 单独保留，不与 IM 混用：

- `Features/Chat/Models/ChatModels.swift`
- `Features/Chat/Services/ChatService.swift`
- `Features/Chat/ViewModels/ChatViewModel.swift`
- `Features/Chat/Views/ChatView.swift`
- `Features/Chat/Views/CardMessageView.swift`
- `Features/Chat/Views/ChatBubble.swift`
- `Features/Chat/Views/BotAvatarView.swift`

### 3. Main Shell

消息页容器与导航编排：

- `Features/Main/SidebarNavigationView.swift`
- `Features/Main/ConversationListSidebarView.swift`
- `Features/Main/MessageSelection.swift`

### 4. Core UI

通用扫码基础组件：

- `Core/UI/QRCameraView.swift`

---

## 已完成的结构整理

### 已删除

- `pinghu12250/ContentView.swift`
- `pinghu12250/Features/Home/AppRootView.swift`
- `pinghu12250/Features/Deprecated/`
- `pinghu12250/Features/Works/ios-app/` 异常嵌套目录
- `Features/Chat/Views/ConversationListView.swift`
- `Features/Chat/Views/QRScannerView.swift`
- `Features/Chat/Views/HomeworkCardView.swift`
- `Features/Chat/Views/TextbookCardView.swift`

### 已移动

- `Features/Chat/Views/ConversationListSidebarView.swift`
  → `Features/Main/ConversationListSidebarView.swift`
- `Features/Chat/Views/QRCameraView.swift`
  → `Core/UI/QRCameraView.swift`

---

## 当前 API 关系

### IM

- REST：拉会话、拉历史、标记已读、发送消息、创建会话
- Socket：实时接收、同步补偿、连接状态

关键点：

- IM 发送消息主通道是 REST
- Socket 不承担主发送链路

### Bot Chat

- 当前是纯 REST 模式
- 与 IM 的 Socket 实时链路分离

---

## 当前是否整理完成

结论：**已基本整理完成。**

具体表现：

1. 主入口已统一
2. 旧消息入口已移除
3. IM 与 Bot Chat 目录职责已分开
4. 通用扫码组件已上移到 Core
5. 异常嵌套目录已清理
6. 构建已通过

---

## 后续建议

当前结构已经可用，但还有一个中期可继续优化点：

- `SidebarNavigationView` 目前仍偏大，承担了消息页整体装配职责

短期这是合理的；后续如果继续演进，可以再把它拆成：

- `MessageShellView`
- `MessagesPaneView`
- `ContactsPaneView`
- `BotDetailContainerView`
- `IMDetailContainerView`

当前阶段不用继续拆，已经足够健康。
