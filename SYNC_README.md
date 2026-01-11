# Git 智能同步脚本使用指南

## 问题背景

当使用 AI CLI (如 Claude Code) 修改代码时，Git 可能无法正确检测到文件变化，原因包括：
- 文件元数据（修改时间）未更新
- Git 索引缓存导致的检测失败
- 文件 inode 或其他系统属性问题

## 解决方案

使用 `sync.sh` 脚本，通过**强制刷新 Git 索引**来确保 Git 基于文件内容而非元数据检测变化。

## 快速开始

### 1. 给脚本添加执行权限（首次使用）

```bash
chmod +x sync.sh
```

### 2. 推送代码到 GitHub

在开发机器上（AI 修改代码后）：

```bash
./sync.sh push
```

### 3. 从 GitHub 拉取代码

在服务器或另一台机器上：

```bash
./sync.sh pull
```

## 详细使用说明

### Push 模式（推送）

```bash
./sync.sh push
```

**执行流程：**
1. ✅ 清除 Git 索引缓存：`git rm -r --cached .`
2. ✅ 重新扫描所有文件：`git add -A`
3. ✅ 检测文件内容变化（忽略元数据）
4. ✅ 自动创建提交
5. ✅ 推送到 GitHub

**适用场景：**
- AI CLI 修改代码后
- 手动修改代码后
- 确保所有变化都被提交

**示例输出：**
```
ℹ️  🚀 开始推送模式

ℹ️  📝 强制刷新 Git 索引...
ℹ️  📦 重新扫描所有文件...

ℹ️  📊 变化统计：
 pinghu12250/Features/Reading/ReadingView.swift     | 82 +-------
 pinghu12250/Features/Textbook/TextbookDetailView.swift | 209 ++++++++++++------
 15 files changed, 329 insertions(+), 240 deletions(-)

ℹ️  💾 创建提交...
ℹ️  🌐 推送到 GitHub...

✅ 推送完成！
```

### Pull 模式（拉取）

```bash
./sync.sh pull
```

**执行流程：**
1. ✅ 检测并暂存本地未提交的修改
2. ✅ 从 GitHub 获取最新代码
3. ✅ 强制同步到远程状态：`git reset --hard origin/main`
4. ✅ 清理未跟踪的文件

**⚠️ 警告：**
- Pull 模式会**丢弃本地所有未提交的修改**
- 建议在 Pull 前先确认本地没有重要的未提交代码
- 或者先执行 `./sync.sh push` 保存本地修改

**适用场景：**
- 从 GitHub 同步最新代码
- 重置本地仓库到远程状态
- 清理本地混乱的 Git 状态

### 查看帮助

```bash
./sync.sh help
```

## 工作流示例

### 场景 1：单向同步（推荐）

**开发机（MacBook A）：**
```bash
# AI 修改代码后
./sync.sh push
```

**服务器（MacBook B）：**
```bash
# 同步最新代码
./sync.sh pull
```

### 场景 2：切换开发机

**在机器 A 上：**
```bash
# 保存当前工作
./sync.sh push
```

**在机器 B 上：**
```bash
# 获取最新代码
./sync.sh pull

# 继续开发...
# ...

# 完成后推送
./sync.sh push
```

**回到机器 A：**
```bash
# 同步机器 B 的修改
./sync.sh pull
```

## 技术原理

### 为什么需要强制刷新索引？

Git 使用**索引（Index/Staging Area）**来跟踪文件状态。索引中存储了：
- 文件路径
- 文件内容的 SHA-1 哈希
- 文件元数据（修改时间、大小、inode 等）

当 AI CLI 修改文件时，可能只更新了内容，但元数据未变化，导致 Git 误认为文件未修改。

### 强制刷新的工作流程

```bash
# 1. 清除索引中的所有文件（但不删除实际文件）
git rm -r --cached .

# 2. 重新添加所有文件，Git 会重新计算 SHA-1
git add -A

# 3. 此时 Git 基于文件内容（SHA-1）而非元数据判断变化
git diff --cached
```

### 与普通 `git add -A` 的区别

| 操作 | 普通 `git add -A` | 强制刷新索引 |
|------|------------------|-------------|
| 检测方式 | 元数据 + 内容 | 仅内容（SHA-1） |
| 速度 | 快 | 稍慢 |
| 可靠性 | 可能漏检 | 100% 可靠 |
| 适用场景 | 正常开发 | AI CLI 修改 |

## 常见问题

### Q1: Push 时提示 "没有变化需要推送"，但我明明改了代码？

**A:** 这通常不会发生，因为 `sync.sh` 会强制刷新索引。如果仍然出现，检查：
- 文件是否在 `.gitignore` 中
- 是否有文件权限问题
- 运行 `git status` 查看详情

### Q2: Pull 会丢失我的本地修改吗？

**A:** 是的。Pull 模式会：
1. 尝试 `git stash` 暂存本地修改
2. 然后 `git reset --hard` 强制同步

如果你有重要的本地修改，请先 `./sync.sh push` 保存。

### Q3: 如何查看 stash 中的内容？

```bash
# 查看 stash 列表
git stash list

# 恢复最近的 stash
git stash pop

# 查看 stash 内容但不恢复
git stash show -p stash@{0}
```

### Q4: 可以双向同步吗（两台机器都修改代码）？

**不推荐。** 当前脚本是为**单向同步**设计的。如果需要双向同步：
1. 在机器 A 上 `./sync.sh push`
2. 在机器 B 上 `./sync.sh pull`
3. 在机器 B 上继续开发
4. 在机器 B 上 `./sync.sh push`
5. 回到机器 A 上 `./sync.sh pull`

**避免同时在两台机器上修改同一文件。**

### Q5: 如何手动执行强制刷新？

如果不想使用脚本，可以手动执行：

```bash
# 清除索引
git rm -r --cached .

# 重新添加
git add -A

# 查看变化
git status

# 提交
git commit -m "force refresh index"
git push
```

## 故障排除

### 脚本执行失败

```bash
# 检查脚本权限
ls -l sync.sh

# 如果没有执行权限
chmod +x sync.sh

# 查看详细错误
bash -x sync.sh push
```

### Git 推送失败

```bash
# 检查远程仓库
git remote -v

# 检查网络连接
ping github.com

# 检查认证
git config --get user.name
git config --get user.email
```

### 强制重置仓库

如果 Git 仓库完全混乱：

```bash
# 方法 1：重新克隆
cd ..
rm -rf pinghu12250ios
git clone https://github.com/huangjinxin/pinghu12250ios.git

# 方法 2：强制同步到远程
git fetch origin
git reset --hard origin/main
git clean -fdx
```

## 高级配置

### 禁用文件元数据检查

在 `.git/config` 中添加：

```ini
[core]
    filemode = false
    trustctime = false
    checkStat = minimal
```

或使用命令：

```bash
git config core.filemode false
git config core.trustctime false
git config core.checkStat minimal
```

### 自定义提交消息

修改 `sync.sh` 中的这一行：

```bash
git commit -m "sync: AI 代码同步 - $TIMESTAMP" -m "🤖 通过 sync.sh 自动同步"
```

## 相关命令

```bash
# 查看提交历史
git log --oneline -10

# 查看文件修改
git diff HEAD~1

# 查看某个文件的历史
git log -p pinghu12250/Features/Reading/ReadingView.swift

# 撤销最近的提交（保留修改）
git reset --soft HEAD~1

# 查看远程仓库状态
git remote show origin

# 比较本地和远程
git fetch origin
git diff main origin/main
```

## 参考资料

- [Git 索引机制](https://git-scm.com/book/zh/v2/Git-%E5%86%85%E9%83%A8%E5%8E%9F%E7%90%86-Git-%E5%AF%B9%E8%B1%A1)
- [Git rm --cached 详解](https://git-scm.com/docs/git-rm)
- [为什么 Git 检测不到文件变化](https://stackoverflow.com/questions/7225313/git-does-not-detect-modification)

## 更新日志

- **2025-01-11**: 初始版本
  - 支持 push/pull 模式
  - 强制刷新 Git 索引
  - 彩色输出和错误处理

## 许可证

MIT License

## 贡献

如果发现问题或有改进建议，请提交 Issue 或 Pull Request。
