# 苹湖少儿空间 iOS App

基于 SwiftUI 构建的 iPad 教育应用，为少儿提供智能学习辅导平台。

## 技术栈

| 类别 | 技术选型 |
|------|---------|
| UI 框架 | SwiftUI (iOS 15+) |
| 架构模式 | MVVM + 单向数据流 |
| 网络层 | URLSession + async/await |
| 本地存储 | CoreData + UserDefaults |
| PDF 渲染 | PDFKit |
| 手写输入 | PencilKit |
| 语音识别 | Speech Framework |

## 项目结构

```
pinghu12250/
├── Core/                    # 核心基础设施
│   ├── Network/            # 网络层 (APIService, APIConfig)
│   ├── Services/           # 通用服务 (Cache, Download, Settings)
│   ├── Models/             # 数据模型
│   ├── Extensions/         # Swift 扩展
│   ├── UI/                 # 通用 UI 组件
│   ├── Stability/          # 稳定性保障 (SafeJSONDecoder, RangeGuard)
│   ├── Watchdog/           # 三级看门狗系统
│   ├── Sync/               # 数据同步服务
│   ├── Audio/              # 音频录制与上传
│   ├── Speech/             # 语音输入
│   └── Concurrency/        # 并发工具 (TaskBag, AsyncSemaphore)
│
├── Features/               # 功能模块
│   ├── Auth/              # 登录注册
│   ├── Home/              # 首页 + 主 Tab
│   ├── Dashboard/         # 学习仪表盘
│   ├── Textbook/          # 教材列表
│   ├── Study/             # 学习模块 (阅读器、笔记、练习)
│   │   ├── Reader/        # PDF/EPUB 阅读器
│   │   ├── Notes/         # 笔记系统
│   │   ├── Practice/      # AI 练习题
│   │   ├── Annotation/    # 批注系统 (PencilKit)
│   │   └── Handwriting/   # 手写识别
│   ├── Diary/             # 日记模块
│   ├── Growth/            # 成长记录
│   ├── Wallet/            # 钱包 & 积分
│   ├── Works/             # 作品展示
│   ├── Parent/            # 家长端
│   └── Settings/          # 系统设置
│
└── Assets.xcassets/        # 图片资源
```

## 核心特性

### 1. 智能学习阅读器
- PDF/EPUB 双格式支持
- Apple Pencil 手写批注
- OCR 文字识别
- AI 辅导对话 (流式响应)
- 区域选择 + AI 分析

### 2. 稳定性保障系统
- **三级看门狗**: 监控主线程卡顿，自动恢复
  - Level 1 (2s): 记录快照
  - Level 2 (5s): 取消后台任务
  - Level 3 (10s): 状态重置
- **内存水位监控**: 70%/80%/90% 三级预警，自动清理缓存
- **安全 JSON 解码**: 容错解析，失败记录

### 3. 离线支持
- PDF 教材本地缓存
- 笔记本地优先 + 后台同步
- 冲突解决界面

### 4. 并发控制
- `RequestController`: 请求去重 + 优先级队列
- `AsyncSemaphore`: 并发数限制
- `TaskBag`: 生命周期管理

## 后端对接

后端服务: Express + Prisma + PostgreSQL

```swift
// API 配置 (Core/Network/APIConfig.swift)
static let localBaseURL = "http://192.168.88.228:12251/api"
static let productionBaseURL = "https://pinghu.706tech.cn/api"
```

主要 API 模块:
- `/auth` - 认证
- `/textbooks` - 教材
- `/textbook-notes` - 笔记
- `/ai-analysis` - AI 分析 (支持 SSE 流式)
- `/submissions` - 作业提交
- `/wallet` - 钱包积分

## 开发环境

### 要求
- macOS 13+
- Xcode 15+
- iOS 15+ (iPad 优先)

### 运行步骤

```bash
# 1. 克隆仓库
git clone https://github.com/huangjinxin/pinghu12250ios.git
cd pinghu12250ios

# 2. 打开项目
open pinghu12250.xcodeproj

# 3. 在 Xcode 中配置签名
#    Signing & Capabilities → Team → 选择开发者账号

# 4. 选择目标设备 (iPad 模拟器或真机)

# 5. 运行 (Cmd + R)
```

### 服务器切换

在设置页面可切换服务器环境：
- 本地开发: `http://192.168.88.228:12251/api`
- 生产环境: `https://pinghu.706tech.cn/api`

## 代码规范

### 命名约定
| 类型 | 规范 | 示例 |
|------|------|------|
| View | `[功能]View` | `TextbookListView` |
| ViewModel | `[功能]ViewModel` | `DashboardViewModel` |
| Service | `[功能]Service` | `NotesService` |
| Manager | `[功能]Manager` | `DownloadManager` |

### 架构原则
- View 只负责 UI 渲染
- 业务逻辑放在 ViewModel 或 Service
- 网络请求统一通过 `APIService`
- 使用 `@Published` + Combine 响应式更新

## 测试账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 学生 | xiaoming | 123456 |
| 家长 | parent_ming | 123456 |
| 老师 | teacher_wang | 123456 |

## 相关仓库

- 主项目 (前后端): [pinghu12250](https://github.com/huangjinxin/pinghu12250)
- iOS 独立仓库: [pinghu12250ios](https://github.com/huangjinxin/pinghu12250ios)

## 版本记录

- **v1.0** - 初始版本
  - 教材阅读 + AI 辅导
  - 笔记系统 + 手写批注
  - 练习题 + 积分系统
  - 家长端监控

## License

Private - All rights reserved
