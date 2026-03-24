# iOS IM 集成测试操作清单

## ⚠️ 重要说明
此文档提供在Xcode中完成IM测试的精确步骤。所有代码已准备就绪。

---

## 📋 测试前准备（5分钟）

### 1. 在Xcode中添加Socket.IO依赖

1. 打开 `pinghu12250.xcodeproj`
2. 选择项目根节点 → `Package Dependencies` 标签
3. 点击 `+` 按钮
4. 输入：`https://github.com/socketio/socket.io-client-swift`
5. 版本选择：`16.0.0` 或 `Up to Next Major`
6. 点击 `Add Package`
7. 确认添加 `SocketIO` 库

### 2. 取消SocketManager的import注释

打开 `Core/Network/SocketManager.swift`，第8行改为：
```swift
import SocketIO  // 取消注释
```

### 3. 编译项目

按 `Cmd+B` 编译，确保无错误。

---

## 🧪 测试步骤

### 测试1：Socket连接（2分钟）

**目标：验证Socket能否连接和认证**

1. 在 `AuthManager.swift` 的登录成功回调中添加：
```swift
// 登录成功后
if let token = self.token {
    print("[Test] 🔑 Token: \(token.prefix(50))...")
    SocketManager.shared.connect(token: token)
}
```

2. 运行App，使用 `xiaoming/123456` 登录

3. 查看Xcode控制台，期望看到：
```
[Socket] 🔌 开始连接...
[Socket] 📍 URL: http://192.168.88.228:12251
[Socket] ✅ 连接成功，开始认证...
[Socket] 🔐 发送认证请求...
[Socket] ✅ 认证成功！
```

4. 同时查看后端日志：
```bash
docker logs -f children-growth-backend | grep Socket
```

期望看到：
```
[Socket] 用户 xiaoming(xxx) 已连接
```

**✅ 如果看到以上日志，连接测试通过！**

---

### 测试2：添加IM入口（3分钟）

在主TabView中添加IM标签：

```swift
// 在MainTabView.swift中
TabView {
    // ... 其他tabs

    IMConversationListView()
        .tabItem {
            Label("消息", systemImage: "message")
        }
}
```

---

### 测试3：发送消息（5分钟）

1. 打开Web测试工具：
```bash
open socket-test.html
```

2. 在Web端：
   - 使用 `parent_ming/123456` 登录
   - 点击"连接Socket"
   - 在"接收者用户ID"填入xiaoming的用户ID
   - 准备发送消息

3. 在iOS端：
   - 点击"消息"标签
   - 选择一个会话（如果有）
   - 输入消息并发送

4. 查看iOS控制台，期望看到：
```
[Socket] 📤 发送消息: toUserId=xxx, content=你好, tempId=xxx
[Socket] ✅ 收到确认: message_sent
```

5. 查看Web端是否收到消息

**✅ 如果iOS发送、Web收到，发送测试通过！**

---

### 测试4：接收消息（5分钟）

1. 在Web端发送消息给iOS端

2. 查看iOS控制台，期望看到：
```
[Socket] 📨 收到新消息: new_message
[Socket] 消息来自: parent_ming
[Socket] 内容: 你好
```

3. 查看iOS界面是否显示新消息

**✅ 如果iOS实时收到消息，接收测试通过！**

---

### 测试5：消息同步（3分钟）

1. iOS端断开Socket（关闭App或断网）

2. Web端发送3条消息

3. iOS端重新连接

4. 查看控制台，期望看到：
```
[Socket] 🔄 同步消息: lastMessageId=xxx
[Socket] 📥 收到同步结果: 3条消息
```

**✅ 如果离线消息同步成功，同步测试通过！**

---

## 🔍 调试技巧

### 查看所有Socket事件

在 `SocketManager.setupEventHandlers()` 末尾添加：
```swift
socket?.onAny { event in
    print("[Socket] 📡 事件: \(event.event)")
    print("[Socket] 📦 数据: \(event.items ?? [])")
}
```

### 查看后端日志

```bash
# 实时查看
docker logs -f children-growth-backend | grep Socket

# 查看最近100行
docker logs --tail 100 children-growth-backend | grep Socket
```

---

## ✅ 测试检查清单

完成后勾选：

- [ ] Socket连接成功
- [ ] JWT认证通过
- [ ] iOS → Web 发送消息成功
- [ ] Web → iOS 接收消息成功
- [ ] 消息状态正确（sending → sent）
- [ ] 离线消息同步成功
- [ ] 会话列表实时更新
- [ ] 未读数正确显示

---

## ⚠️ 常见问题

**Q: Socket连接失败？**
- 检查URL：应该是 `http://192.168.88.228:12251`（不含/api）
- 检查后端是否运行：`docker ps | grep backend`
- 检查网络：`curl http://192.168.88.228:12251/health`

**Q: 认证失败？**
- 确认token正确传递
- 查看后端日志确认收到认证请求

**Q: 发送消息失败"只能向好友发送消息"？**
- 确认两个账号是好友关系
- 使用Web端先添加好友

**Q: 编译错误"No such module 'SocketIO'"？**
- 确认已添加Socket.IO依赖包
- 清理项目：Cmd+Shift+K
- 重新编译：Cmd+B

---

## 📊 预期结果

**成功标准：**
1. ✅ Socket连接和认证成功
2. ✅ iOS ↔ Web 双向实时消息
3. ✅ 离线消息同步正常
4. ✅ 控制台日志清晰完整

**测试时间：** 约20分钟
**前置条件：** 后端运行 + 两个测试账号互为好友

---

**准备就绪！在Xcode中按照以上步骤操作即可完成测试。**
