# iOS App UI 重设计方案
> 更新时间: 2026-03-05
> 状态: 设计阶段 → 实施中

## 核心设计理念

### 消息驱动学习
- **交互模式**: 类似 Telegram Bot，通过对话触发学习内容
- **卡片跳转**: 聊天中的卡片点击后跳转到学习界面
- **去菜单化**: 大部分学习内容不在菜单显示，通过聊天卡片访问

### 参考对象
- **微信**: 整体结构（4个Tab）+ 会话列表样式
- **Telegram**: Rich Message Card + 内嵌页面交互
- **iMessage**: 配色方案 + 气泡样式 + 毛玻璃效果

---

## 整体架构

### Tab Bar 结构（固定4个）
```
💬 消息    📖 通讯录    🌍 朋友圈    👤 我的
```

### 横屏布局（iPad Landscape）
```
┌────────────────┬─────────────────────────────────┐
│                │                                 │
│   左侧 1/3     │        右侧 2/3                 │
│   (列表区)     │        (详情区)                 │
│                │                                 │
└────────────────┴─────────────────────────────────┘
│💬消息  📖通讯录  🌍朋友圈  👤我的  │← Tab Bar
```

**布局规则**:
- 左侧宽度: 屏幕宽度的 33%（约 340-360pt）
- 右侧宽度: 屏幕宽度的 67%（约 680-720pt）
- 分割线: 1pt 系统灰色
- 左侧显示: 会话列表/通讯录列表/朋友圈列表/个人信息
- 右侧显示: 对话详情/联系人详情/朋友圈详情/设置页面

### 竖屏布局（iPad Portrait）
```
┌─────────────┐
│   全屏内容  │
│             │
└─────────────┘
│💬 📖 🌍 👤│← Tab Bar
```

**布局规则**:
- 列表页全屏显示
- 点击进入详情页（全屏）
- 左上角返回按钮
- 类似 iPhone 的导航逻辑

---

## 消息 Tab 设计（核心）

### 会话列表（左侧 1/3）

**样式**: 微信风格
```
┌──────────────┐
│ 消息  [搜索] │
│──────────────│
│ [🤖] AI助手  │
│ 今天学什么?  │
│ 刚刚         │
│──────────────│
│ [👨] 王老师  │
│ 作业已批改   │
│ 10分钟前     │
│──────────────│
│ [👥] 班级群  │
│ 小明:哈哈    │
│ 1小时前      │
└──────────────┘
```

**组件结构**:
- 头像: 60x60pt 圆形
- 昵称: 17pt 粗体
- 最后一条消息: 15pt 常规，灰色
- 时间: 13pt，浅灰色
- 未读角标: 红色圆形，白色数字
- 分割线: 0.5pt，浅灰色

### 对话详情（右侧 2/3）

**样式**: iMessage + Telegram 卡片
```
┌─────────────────────────────────────┐
│ [<] AI学习助手          [...] │
│─────────────────────────────────────│
│                                     │
│  你好！今天学什么？                 │
│                                     │
│  ┏━━━━━━━━━━━━━━━━━━━━┓            │
│  ┃📘 语文五年级上册            ┃            │
│  ┃  ─────────────────────────  ┃            │
│  ┃  第3课：桂林山水              ┃            │
│  ┃  学习进度:████████░░ 45%    ┃            │
│  ┃  [继续学习] [查看笔记]        ┃            │
│  ┗━━━━━━━━━━━━━━━━━━━━┛            │
│                                     │
│  我想学语文第3课                    │
│                                     │
│  [输入框]            [🎤] [+]       │
└─────────────────────────────────────┘
```

**气泡样式**:
- 用户消息: 蓝色渐变气泡，右对齐
- AI消息: 灰色气泡，左对齐
- 圆角: 18pt
- 内边距: 12pt 水平，8pt 垂直
- 最大宽度: 70%

**卡片样式**:
- 背景: 白色（浅色模式）/ `#2C2C2E`（深色模式）
- 圆角: 16pt
- 阴影: `shadow(color: .black.opacity(0.1), radius: 4, y: 2)`
- 内边距: 16pt
- 高度: 120-150pt（根据内容自适应）

---

## 卡片类型设计

### 1. 教材卡片
```swift
┏━━━━━━━━━━━━━━━━━━━━┓
┃ 📘 [封面缩略图]              ┃
┃ 语文五年级上册                ┃
┃ ─────────────────────────    ┃
┃ 当前: 第3课 桂林山水          ┃
┃ 进度: ████████░░ 45%        ┃
┃ [继续学习] [查看笔记]          ┃
┗━━━━━━━━━━━━━━━━━━━━┛
```

**数据结构**:
- 教材ID
- 封面图URL
- 标题
- 当前课程
- 学习进度（0-100%）
- 操作按钮（继续学习、查看笔记）

### 2. 作业卡片
```swift
┏━━━━━━━━━━━━━━━━━━━━┓
┃ ✍️ 今日作业                  ┃
┃ ─────────────────────────    ┃
┃ 语文：背诵第3课              ┃
┃ 数学：练习册P12-15            ┃
┃ 截止时间: 今天 20:00          ┃
┃ [开始完成]                    ┃
┗━━━━━━━━━━━━━━━━━━━━┛
```

### 3. AI对话卡片
```swift
┏━━━━━━━━━━━━━━━━━━━━┓
┃ 🤖 AI助手                    ┃
┃ ─────────────────────────    ┃
┃ 我可以帮你：                  ┃
┃ • 解答课文问题                ┃
┃ • 批改作业                    ┃
┃ • 推荐学习内容                ┃
┃ [开始对话]                    ┃
┗━━━━━━━━━━━━━━━━━━━━┛
```

### 4. 练习题卡片
```swift
┏━━━━━━━━━━━━━━━━━━━━┓
┃ 📝 课后练习                  ┃
┃ ─────────────────────────    ┃
┃ 第3课配套练习                ┃
┃ 共10题 | 预计15分钟           ┃
┃ [开始练习]                    ┃
┗━━━━━━━━━━━━━━━━━━━━┛
```

---

## 配色方案（iMessage 风格）

### 浅色模式
```swift
// 背景色
.background = Color(hex: "#FFFFFF")
.secondaryBackground = Color(hex: "#F2F2F7")

// 主色调
.primary = Color(hex: "#007AFF")        // 系统蓝
.success = Color(hex: "#34C759")        // 系统绿
.warning = Color(hex: "#FF9500")        // 系统橙
.danger = Color(hex: "#FF3B30")         // 系统红

// 文字颜色
.primaryText = Color(hex: "#000000")
.secondaryText = Color(hex: "#3C3C43")
.tertiaryText = Color(hex: "#8E8E93")

// 分割线
.separator = Color(hex: "#C6C6C8")

// 气泡颜色
.userBubble = LinearGradient(
    colors: [Color(hex: "#007AFF"), Color(hex: "#5AC8FA")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.aiBubble = Color(hex: "#E5E5EA")

// 卡片背景
.cardBackground = Color.white
.cardShadow = Color.black.opacity(0.1)
```

### 深色模式
```swift
// 背景色
.background = Color(hex: "#000000")
.secondaryBackground = Color(hex: "#1C1C1E")

// 主色调
.primary = Color(hex: "#0A84FF")        // 深色模式蓝
.success = Color(hex: "#30D158")
.warning = Color(hex: "#FF9F0A")
.danger = Color(hex: "#FF453A")

// 文字颜色
.primaryText = Color(hex: "#FFFFFF")
.secondaryText = Color(hex: "#EBEBF5")
.tertiaryText = Color(hex: "#8E8E93")

// 分割线
.separator = Color(hex: "#38383A")

// 气泡颜色
.userBubble = LinearGradient(
    colors: [Color(hex: "#0A84FF"), Color(hex: "#64D2FF")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.aiBubble = Color(hex: "#3A3A3C")

// 卡片背景
.cardBackground = Color(hex: "#2C2C2E")
.cardShadow = Color.black.opacity(0.3)
```

---

## 交互流程

### 1. 点击教材卡片（横屏）
```
会话列表（左1/3）保持不变
对话详情（右2/3）→ 教材阅读器（全屏占满右侧）
顶部导航: [<返回对话] 语文五年级上册 [笔记][AI]
底部工具栏: [目录] [书签] [笔记] [AI助手]
```

### 2. 点击教材卡片（竖屏）
```
对话详情 → 教材阅读器（全屏）
顶部导航: [<返回] 语文五年级上册 [...]
底部工具栏: [目录] [书签] [笔记] [AI助手]
```

### 3. 点击作业卡片
```
对话详情 → 作业详情页（右2/3 或全屏）
显示作业内容、提交按钮、截止时间
```

### 4. 点击AI对话卡片
```
在当前对话中继续（不跳转）
AI助手回复消息
```

---

## 其他 Tab 设计

### 通讯录 Tab
```
┌──────────────┐
│ 通讯录        │
│ [搜索框]     │
│──────────────│
│ 🤖 AI助手    │
│──────────────│
│ 👨‍🏫 我的老师  │
│ 王老师       │
│ 李老师       │
│──────────────│
│ 👥 我的同学  │
│ 小明         │
│ 小红         │
│──────────────│
│ 👨‍👩‍👧 家长      │
│ 爸爸         │
│ 妈妈         │
└──────────────┘
```

### 朋友圈 Tab
```
┌─────────────────────────────┐
│ 朋友圈                       │
│─────────────────────────────│
│ [头像] 小明  2小时前         │
│ 今天学会了桂林山水！         │
│ [图片] [图片]                │
│ ❤️ 10  💬 3                  │
│─────────────────────────────│
│ [头像] 小红  昨天             │
│ 完成了数学作业，好开心！     │
│ ❤️ 5  💬 1                   │
└─────────────────────────────┘
```

### 我的 Tab
```
┌─────────────────────────────┐
│ [头像]                       │
│ 小明                         │
│ 五年级1班                    │
│─────────────────────────────│
│ 💰 积分: 1250                │
│ 📚 学习天数: 45天            │
│ 🏆 获得奖励: 12个            │
│─────────────────────────────│
│ 📖 我的教材                  │
│ ✍️ 我的作业                  │
│ 📝 我的笔记                  │
│ 🎨 我的作品                  │
│ 📊 学习统计                  │
│ ⚙️ 设置                      │
└─────────────────────────────┘
```

---

## Mock 数据结构

### 会话数据
```swift
struct Conversation: Identifiable {
    let id: UUID
    let avatar: String          // 头像URL或SF Symbol
    let name: String            // 昵称
    let lastMessage: String     // 最后一条消息
    let timestamp: Date         // 时间
    let unreadCount: Int        // 未读数
    let type: ConversationType  // 类型
}

enum ConversationType {
    case aiAssistant
    case teacher
    case student
    case group
    case parent
}
```

### 消息数据
```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let content: MessageContent
    let isUser: Bool
    let timestamp: Date
}

enum MessageContent {
    case text(String)
    case card(MessageCard)
    case image(URL)
}

struct MessageCard {
    let type: CardType
    let title: String
    let subtitle: String?
    let progress: Double?       // 0-1
    let imageURL: URL?
    let actions: [CardAction]
}

enum CardType {
    case textbook
    case homework
    case practice
    case aiAssistant
}

struct CardAction {
    let title: String
    let action: () -> Void
}
```

---

## 技术实现要点

### 1. 响应式布局
```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass
@Environment(\.verticalSizeClass) var verticalSizeClass

var isLandscape: Bool {
    horizontalSizeClass == .regular && verticalSizeClass == .compact
}
```

### 2. 双栏布局（横屏）
```swift
GeometryReader { geometry in
    HStack(spacing: 0) {
        // 左侧列表（1/3）
        ConversationListView()
            .frame(width: geometry.size.width * 0.33)
        
        Divider()
        
        // 右侧详情（2/3）
        ConversationDetailView()
            .frame(width: geometry.size.width * 0.67)
    }
}
```

### 3. 卡片组件
```swift
struct MessageCardView: View {
    let card: MessageCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 卡片内容
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .cardShadow, radius: 4, y: 2)
    }
}
```

### 4. 气泡样式
```swift
struct ChatBubble: View {
    let message: String
    let isUser: Bool
    
    var body: some View {
        Text(message)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isUser ? Color.userBubble : Color.aiBubble)
            .foregroundColor(isUser ? .white : .primaryText)
            .cornerRadius(18)
    }
}
```

---

## 实施计划

### Phase 1: 基础框架（1-2天）
- [ ] 创建配色系统 `Color+Theme.swift`
- [ ] 创建新的主框架 `MainTabView`（4个Tab）
- [ ] 实现横屏/竖屏自适应布局检测
- [ ] 创建双栏布局组件 `SplitView`

### Phase 2: 消息模块 - 基础组件（2天）
- [ ] 创建会话列表 `ConversationListView`
- [ ] 创建会话行组件 `ConversationRowView`
- [ ] 创建对话详情 `ConversationDetailView`
- [ ] 创建气泡组件 `ChatBubbleView`

### Phase 3: 消息模块 - 卡片系统（2天）
- [ ] 创建基础卡片组件 `MessageCardView`
- [ ] 实现教材卡片 `TextbookCardView`
- [ ] 实现作业卡片 `HomeworkCardView`
- [ ] 实现练习题卡片 `PracticeCardView`
- [ ] 实现AI助手卡片 `AIAssistantCardView`

### Phase 4: 其他Tab（2天）
- [ ] 实现通讯录 Tab `ContactsView`
- [ ] 实现朋友圈 Tab `MomentsView`
- [ ] 实现我的 Tab `ProfileView`

### Phase 5: Mock数据和测试（1天）
- [ ] 创建Mock数据 `MockData.swift`
- [ ] 测试横屏/竖屏切换
- [ ] 测试卡片点击交互
- [ ] 测试深色模式

### Phase 6: 细节优化（1天）
- [ ] 添加动画效果
- [ ] 优化手势交互
- [ ] 性能优化（LazyVStack）
- [ ] 可访问性支持

---

## 文件结构

```
pinghu12250/
├── Core/
│   ├── Theme/
│   │   ├── Color+Theme.swift          # 配色系统
│   │   └── ThemeConstants.swift       # 主题常量
│   └── UI/
│       ├── SplitView.swift            # 双栏布局
│       └── AdaptiveLayout.swift       # 自适应布局
│
├── Features/
│   ├── Main/
│   │   └── MainTabView.swift          # 主框架（4个Tab）
│   │
│   ├── Messages/
│   │   ├── Views/
│   │   │   ├── ConversationListView.swift
│   │   │   ├── ConversationRowView.swift
│   │   │   ├── ConversationDetailView.swift
│   │   │   └── ChatBubbleView.swift
│   │   ├── Cards/
│   │   │   ├── MessageCardView.swift
│   │   │   ├── TextbookCardView.swift
│   │   │   ├── HomeworkCardView.swift
│   │   │   ├── PracticeCardView.swift
│   │   │   └── AIAssistantCardView.swift
│   │   ├── Models/
│   │   │   ├── Conversation.swift
│   │   │   ├── ChatMessage.swift
│   │   │   └── MessageCard.swift
│   │   └── ViewModels/
│   │       └── MessagesViewModel.swift
│   │
│   ├── Contacts/
│   │   └── ContactsView.swift
│   │
│   ├── Moments/
│   │   └── MomentsView.swift
│   │
│   └── Profile/
│       └── ProfileView.swift
│
└── Mock/
    └── MockData.swift                 # Mock数据
```

---

## 注意事项

1. **暂不实现后端**: 所有数据使用 Mock 数据
2. **保留现有功能**: 教材阅读器、笔记系统等核心功能保持不变
3. **渐进式迁移**: 先实现新框架，再逐步迁移现有功能
4. **性能优先**: 列表使用 `LazyVStack`，图片使用异步加载
5. **可访问性**: 支持 VoiceOver、动态字体
6. **深色模式**: 所有组件支持深色模式

---

## 开发规范

### 命名约定
- View: `[功能]View` (如 `ConversationListView`)
- ViewModel: `[功能]ViewModel`
- 卡片组件: `[类型]CardView` (如 `TextbookCardView`)
- 行组件: `[类型]RowView` (如 `ConversationRowView`)

### 代码风格
- 使用 SwiftUI 最佳实践
- 组件尽量小而专注
- 使用 `@StateObject` 管理 ViewModel
- 使用 `@EnvironmentObject` 共享状态
- 避免在 View 中写业务逻辑

### Git 提交规范
- `feat: 添加xxx功能`
- `ui: 实现xxx界面`
- `refactor: 重构xxx`
- `fix: 修复xxx问题`

---

## 参考资源

- [Apple HIG - Messages](https://developer.apple.com/design/human-interface-guidelines/messages)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [SwiftUI Layout](https://developer.apple.com/documentation/swiftui/layout)
- [Color Scheme](https://developer.apple.com/documentation/swiftui/colorscheme)
