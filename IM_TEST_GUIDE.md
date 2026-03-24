# iOS IM 功能测试指南

## ✅ 后端状态确认

**后端Socket.IO服务已就绪：**
- 服务运行在：`http://localhost:12251`
- Socket.IO已集成并配置完成
- 支持的事件：
  - 认证：JWT token通过 `socket.handshake.auth.token`
  - 发送消息：`send_message`
  - 接收消息：`new_message`
  - 消息确认：`message_sent`
  - 同步消息：`sync_messages` / `sync_result`
  - 在线状态：`user_online` / `user_offline`

---

## 📋 测试前准备

### 1. 添加Socket.IO依赖（必须）

在Xcode中：
1. 打开 `pinghu12250.xcodeproj`
2. 选择项目 → `Package Dependencies` 标签
3. 点击 `+` 按钮
4. 输入：`https://github.com/socketio/socket.io-client-swift`
5. 版本选择：`16.0.0` 或 `Up to Next Major`
6. 点击 `Add Package`
7. 确认添加 `SocketIO` 库

### 2. 取消SocketManager的import注释

打开 `Core/Network/SocketManager.swift`，修改第8行：
```swift
// 改为：
import SocketIO
```

### 3. 更新APIConfig

打开 `Core/Network/APIConfig.swift`，添加：
```swift
struct APIConfig {
    static let baseURL = "http://localhost:12251/api"
    static let socketURL = "http://localhost:12251"  // 新增

    struct Endpoints {
        // ... 现有的

        // IM相关（新增）
        static let conversations = "/api/conversations/list"
        static let messages = "/api/messages"
        static let markRead = "/api/messages/mark-chat-read"
        static let unreadCount = "/api/unread-count"
    }
}
```

### 4. 准备测试账号

使用现有测试账号：
- 账号1：`xiaoming` / `123456`
- 账号2：`parent_ming` / `123456`

**重要：确保两个账号已经是好友关系！**

检查好友关系：
```bash
# 在后端容器中执行
docker exec -it children-growth-backend npx prisma studio
# 查看 Friendship 表
```

---

## 🧪 测试步骤

### 测试1：Socket连接和认证

**目标：验证Socket能否成功连接并认证**

1. 在Xcode中运行项目
2. 使用 `xiaoming` 登录
3. 在 `AuthManager.login()` 成功后添加：
```swift
// 登录成功后连接Socket
if let token = self.token {
    SocketManager.shared.connect(token: token)
}
```

4. 观察Xcode控制台输出：
```
✅ 期望看到：
[Socket] 连接中...
[Socket] 已连接
[Socket] 认证成功

❌ 如果失败：
[Socket] 认证失败: ...
```

5. 同时观察后端日志：
```bash
docker logs -f children-growth-backend
```

期望看到：
```
[Socket] 用户 xiaoming(user_xxx) 已连接
```

### 测试2：发送消息

**目标：验证消息能否成功发送**

1. 打开聊天页面（需要先添加到导航）
2. 输入消息并发送
3. 观察控制台：

**iOS端期望输出：**
```
[Socket] 发送消息: toUserId=xxx, content=你好, tempId=xxx
[Socket] 收到确认: message_sent
```

**后端期望输出：**
```
[Socket] 消息发送成功: xiaoming -> parent_ming
```

4. 检查数据库：
```sql
SELECT * FROM "Message"
WHERE "fromUserId" = 'xiaoming_id'
ORDER BY "createdAt" DESC
LIMIT 5;
```

### 测试3：接收消息

**目标：验证能否实时接收消息**

**准备：**
- 设备A：登录 `xiaoming`
- 设备B（或Web）：登录 `parent_ming`

**步骤：**
1. 设备B发送消息给xiaoming
2. 观察设备A是否实时收到

**设备A期望输出：**
```
[Socket] 收到新消息: new_message
[Socket] 消息来自: parent_ming
[Socket] 内容: 你好
```

**UI期望：**
- 消息立即出现在聊天列表
- 会话列表的lastMessage更新
- 未读数+1

### 测试4：消息同步

**目标：验证离线消息同步**

**步骤：**
1. 设备A（xiaoming）断开Socket或关闭App
2. 设备B（parent_ming）发送3条消息
3. 设备A重新连接
4. 观察是否自动同步

**期望输出：**
```
[Socket] 同步消息: lastMessageId=xxx
[Socket] 收到同步结果: 3条消息
```

### 测试5：会话列表更新

**目标：验证会话列表实时更新**

1. 打开会话列表页面
2. 另一设备发送消息
3. 观察会话列表是否：
   - 该会话移到顶部
   - lastMessage更新
   - unreadCount增加
   - totalUnread增加

---

## 🔍 调试技巧

### 1. 启用Socket日志

在 `SocketManager.swift` 的 `connect()` 方法中：
```swift
manager = SocketIOClient.SocketManager(
    socketURL: socketURL,
    config: [.log(true), .compress, .forceWebsockets(true)]  // 改为true
)
```

### 2. 添加事件日志

在 `setupEventHandlers()` 中添加：
```swift
socket?.onAny { event in
    print("[Socket] 收到事件: \(event.event), 数据: \(event.items ?? [])")
}
```

### 3. 监控后端日志

```bash
# 实时查看后端Socket日志
docker logs -f children-growth-backend | grep Socket
```

### 4. 使用Postman测试Socket

安装Postman，使用Socket.IO客户端：
1. 连接到 `http://localhost:12251`
2. 添加认证：`auth` 事件，发送 `{"token": "your_jwt"}`
3. 发送消息：`send_message` 事件

---

## ⚠️ 常见问题排查

### 问题1：Socket连接失败

**症状：**
```
[Socket] 连接失败
```

**排查：**
1. 检查后端是否运行：`docker ps | grep backend`
2. 检查端口：`curl http://localhost:12251/health`
3. 检查URL配置：确保是 `http://localhost:12251`（不是 `/api`）
4. 检查CORS配置：后端已配置允许所有来源

### 问题2：认证失败

**症状：**
```
[Socket] 认证失败: 未提供token
```

**排查：**
1. 确认token已传递：
```swift
print("Token: \(token)")  // 在connect()中打印
```
2. 确认token格式正确（JWT）
3. 确认token未过期
4. 查看后端日志确认收到token

### 问题3：消息发送失败

**症状：**
```
[Socket] 发送消息失败: 只能向好友发送消息
```

**排查：**
1. 确认两个账号是好友关系
2. 检查数据库 `Friendship` 表
3. 如果不是好友，先添加好友：
```bash
# 使用Web端或API添加好友
POST /api/friend-requests
{
  "toUserId": "target_user_id",
  "message": "测试"
}

# 接受好友申请
POST /api/friend-requests/:requestId/accept
```

### 问题4：收不到实时消息

**症状：**
- 发送成功，但接收方收不到

**排查：**
1. 确认接收方Socket已连接：
```swift
print("Socket连接状态: \(SocketManager.shared.isConnected)")
```
2. 确认已注册 `onNewMessage` 回调
3. 查看后端日志，确认推送成功
4. 检查接收方userId是否正确

### 问题5：消息重复

**症状：**
- 同一条消息显示多次

**原因：**
- 多次注册了 `onNewMessage` 回调

**解决：**
- 确保回调只注册一次（在ViewModel的init中）
- 或在注册前先清除旧回调

---

## 📊 测试检查清单

- [ ] Socket连接成功
- [ ] JWT认证通过
- [ ] 发送消息成功（乐观更新）
- [ ] 收到message_sent确认
- [ ] 消息状态从sending变为sent
- [ ] 实时接收消息
- [ ] 会话列表实时更新
- [ ] 未读数正确计算
- [ ] 消息同步功能正常
- [ ] 前后台切换正常
- [ ] 断线重连正常

---

## 🚀 快速测试脚本

创建一个测试View来快速验证Socket功能：

```swift
// TestSocketView.swift
struct TestSocketView: View {
    @State private var logs: [String] = []
    @State private var token = ""

    var body: some View {
        VStack {
            TextField("JWT Token", text: $token)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("连接Socket") {
                testConnect()
            }

            Button("发送测试消息") {
                testSendMessage()
            }

            ScrollView {
                ForEach(logs, id: \.self) { log in
                    Text(log)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
    }

    func testConnect() {
        logs.append("开始连接...")
        SocketManager.shared.connect(token: token)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            logs.append("连接状态: \(SocketManager.shared.isConnected)")
        }
    }

    func testSendMessage() {
        logs.append("发送测试消息...")
        SocketManager.shared.sendMessage(
            toUserId: "target_user_id",
            content: "测试消息",
            tempId: UUID().uuidString
        )
    }
}
```

---

**测试时间估计：** 30-60分钟
**前置条件：** 后端运行 + 两个测试账号互为好友
**测试环境：** iOS模拟器或真机
