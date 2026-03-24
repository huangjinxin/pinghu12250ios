# iOS Chat-First Redesign Plan
# 苹湖App 聊天驱动改版计划

> 长期方向：App极简化，主界面=聊天列表，一切交互通过聊天进行
> 扫码连接现实，任务拟人化，为AI接入铺路

## 设计原则

1. **聊天即入口** — 没有功能菜单，Bot聊天是唯一交互方式
2. **扫码即连接** — 物理二维码替代App按钮
3. **卡片即导航** — 功能模块从卡片push进入，返回回到聊天
4. **渐进增强** — 关键词回复 → AI回复，UI不变体验升级

## 当前状态 (Before)

```
MainTabView: 12个Tab侧边栏
  消息 | 仪表盘 | 日记 | 作业 | 读书 | 书写 | 笔记 | 照片 | 作品 | 购物 | 钱包 | 心路
```

## 目标状态 (After Phase 1+2)

```
AppRootView: NavigationStack
  └── ConversationListView (唯一主页)
        ├── 顶部: 用户头像(→设置) + 标题 + 扫码按钮
        ├── 列表: Bot联系人(iMessage风格)
        └── push destinations:
              ├── ChatView(bot) → 聊天详情
              │     └── 卡片push → 各功能模块(返回回到聊天)
              └── QRScannerView → 扫码→打开Bot聊天→发卡片
```

---

## Phase 1: 聊天主页化 ✅ COMPLETED

### 1.1 重写App入口 (MainTabView → AppRootView) ✅
- [x] 新建 AppRootView.swift 替代 MainTabView
- [x] 结构: NavigationStack + ConversationListView
- [x] 更新 RootView.swift 引用 AppRootView

### 1.2 升级 ConversationListView 为App主页 ✅
- [x] 顶部栏: 左=用户头像(点击→设置sheet), 中=标题"苹湖", 右=扫码按钮
- [x] Bot列表: iMessage风格, 头像+名称+最后消息+时间+未读
- [x] 空状态优化
- [x] 下拉刷新

### 1.3 ChatView 增加页面push能力 ✅
- [x] 定义 ChatDestination enum (writing, diary, reading, works, dashboard, wallet, photos)
- [x] 添加 .navigationDestination 注册所有功能页
- [x] 卡片点击 → push destination (不再发通知切Tab)

### 1.4 CardMessageView 改造 ✅
- [x] 删除 NotificationCenter.post(.switchTab)
- [x] 改为 onNavigate callback push页面
- [x] 补全所有 target → destination 映射
- [x] 修复图标映射 + 彩色图标背景

### 1.5 功能页适配 ✅
- [x] WorksGalleryView: 支持初始subTab参数(诗词古文), 移除NavigationStack
- [x] WritingView: 添加 .navigationTitle("书写")
- [x] DiaryListView: 移除NavigationStack
- [x] ReadingView: 移除NavigationStack
- [x] HomeworkListView: 移除NavigationStack

### 1.6 设置入口迁移 ✅
- [x] ConversationListView左上角头像 → 设置sheet
- [x] SystemSettingsView 保持不变

### 1.7 清理废弃代码 ✅
- [x] DashboardViewModel.navigateToMySubmissions 移除通知
- [x] MainTabView 保留(Parent端用), 添加兼容代码

## Phase 2: 扫码闭环 ✅ COMPLETED

### 2.1 扫码流程改造 ✅
- [x] QRScannerView 改造: onScanResult callback 替代 NotificationCenter
- [x] 新格式解析: pinghu://chat?bot={botId}&keyword={keyword}
- [x] 旧格式兼容: pinghu://scan?type=xxx&target=xxx
- [x] ChatNavigation 类型: 携带 bot + keyword 导航到 ChatView
- [x] ChatView autoSendKeyword: 打开后自动发送关键词触发Bot回复

### 2.2 后端扫码API适配
- [ ] 扫码返回 { botId, triggerKeyword } 而非直接跳转目标 (待后端配合)
- [ ] Bot收到triggerKeyword自动回复对应卡片 (已有关键词回复机制)

### 2.3 二维码规范 ✅
- [x] 统一格式: pinghu://chat?bot={botId}&keyword={keyword}
- [ ] Web管理端二维码生成工具适配新格式 (待前端配合)

## UI/UX 美化要点

### 聊天列表页
- 大标题 "苹湖" 居中, SF Rounded字体
- Bot头像: 圆形, 带彩色边框(每个Bot不同颜色)
- 未读气泡: 红色圆点, 右上角
- 最后消息预览: 单行, 灰色, 卡片消息显示"[📎 卡片名称]"
- 分隔线: 从头像右侧开始(iMessage风格)

### 聊天详情页
- iMessage气泡保持现有风格
- 卡片消息: 圆角卡片, 左侧彩色图标, 右侧箭头, 点击有按压反馈
- 输入栏: Capsule样式, 蓝色发送按钮
- 导航栏: Bot头像+名称, 返回按钮

### 功能页(从卡片push进入)
- 顶部导航栏自动显示返回按钮
- 页面标题显示功能名称
- 整体风格与聊天页保持一致

---

## Bot → Target → Destination 映射表

| Bot | 关键词 | Backend target | iOS Destination |
|-----|--------|---------------|-----------------|
| 语文老师 | 课文 | /books | .works(subTab: "poetry") |
| 语文老师 | 古诗 | /poetry | .works(subTab: "poetry") |
| 书法老师 | 练字 | /writing | .writing |
| 日记伙伴 | 写日记 | /diaries | .diary |
| 日记伙伴 | 拍照 | /photos | .photos |
| 阅读伙伴 | 读书 | /books | .reading |
| 成长助手 | 任务 | /submit | .dashboard |
| 成长助手 | 积分 | /points | .dashboard |

## 文件变更清单

### 新建
- Features/Home/AppRootView.swift — 聊天驱动主界面

### 重写
- Features/Chat/Views/ConversationListView.swift — App主页(iMessage风格)
- Features/Chat/Views/CardMessageView.swift — callback导航+彩色图标
- Features/Chat/Views/ChatView.swift — NavigationPath push + autoSendKeyword
- Features/Chat/Views/QRScannerView.swift — onScanResult callback + 新QR格式

### 修改
- Features/Chat/Models/ChatModels.swift — ChatDestination, ChatNavigation
- Features/Chat/Views/ChatBubble.swift — CardMessageView参数适配
- Features/Works/WorksGalleryView.swift — initialTab参数, 移除NavigationStack
- Features/Writing/Views/WritingView.swift — 添加navigationTitle
- Features/Diary/DiaryListView.swift — 移除NavigationStack
- Features/Reading/ReadingView.swift — 移除NavigationStack
- Features/Homework/HomeworkListView.swift — 移除NavigationStack
- Features/Dashboard/DashboardViewModel.swift — 移除通知调用
- Features/Home/MainTabView.swift — 兼容修复(chatPath, switchTab)
- RootView.swift — MainTabView() → AppRootView()

### 保留不动
- Features/Home/MainTabView.swift (Parent端用, 保留编译)
- 所有功能View内部逻辑 (只改入口方式)
