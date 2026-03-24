#!/bin/bash
# sync.sh - Git 智能同步脚本
# 用途：解决 AI CLI 修改代码后 Git 无法检测变化的问题
# 使用：./sync.sh [push|pull]

set -e  # 遇到错误立即退出

MODE=$1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查是否在 Git 仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "当前目录不是 Git 仓库"
    exit 1
fi

# Push 模式：将本地代码推送到 GitHub
do_push() {
    print_info "🚀 开始推送模式"
    echo ""

    # 1. 刷新 Git 索引
    print_info "📝 刷新 Git 索引..."
    git update-index -q --refresh || true

    # 2. 扫描工作区变化
    print_info "📦 扫描工作区变化..."
    git add -A

    # 3. 检查是否有变化
    if git diff --cached --quiet; then
        print_success "没有变化需要推送"
        echo ""
        print_info "当前分支状态："
        git status -sb
        exit 0
    fi

    # 4. 显示变化统计
    echo ""
    print_info "📊 变化统计："
    git diff --cached --stat
    echo ""

    # 5. 提交
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "💾 创建提交..."
    git commit -m "sync: AI 代码同步 - $TIMESTAMP" -m "🤖 通过 sync.sh 自动同步"

    # 6. 推送到远程
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_info "🌐 推送到 GitHub ($CURRENT_BRANCH)..."
    if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" > /dev/null 2>&1; then
        git push
    else
        git push -u origin "$CURRENT_BRANCH"
    fi

    echo ""
    print_success "推送完成！"
    print_info "查看提交历史：git log --oneline -3"
}

# Pull 模式：从 GitHub 拉取最新代码
do_pull() {
    print_info "⬇️  开始拉取模式"
    echo ""

    # 1. 检查本地是否有未提交的修改
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_warning "检测到本地有未提交的修改"
        print_info "尝试暂存本地修改..."
        git stash save "auto-stash before pull at $(date '+%Y-%m-%d %H:%M:%S')"
        print_success "本地修改已暂存"
        echo ""
    fi

    # 2. 获取远程更新
    print_info "🌐 从 GitHub 获取更新..."
    git fetch origin

    # 3. 显示将要同步的变化
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})

    if [ $LOCAL = $REMOTE ]; then
        print_success "本地代码已是最新"
        exit 0
    fi

    print_info "发现远程更新："
    git log --oneline --graph --decorate HEAD..origin/main | head -5
    echo ""

    # 4. 强制同步到远程状态
    print_info "📥 同步远程代码..."
    git reset --hard origin/main

    # 5. 清理未跟踪的文件（可选）
    print_info "🧹 清理未跟踪的文件..."
    git clean -fd

    echo ""
    print_success "拉取完成！"
    print_info "当前分支状态："
    git status -sb
}

# 显示使用帮助
show_help() {
    echo "Git 智能同步脚本"
    echo ""
    echo "用途："
    echo "  解决 AI CLI 修改代码后，Git 无法检测到文件变化的问题"
    echo ""
    echo "使用方法："
    echo "  ./sync.sh push    - 将本地代码推送到 GitHub"
    echo "  ./sync.sh pull    - 从 GitHub 拉取最新代码"
    echo "  ./sync.sh help    - 显示此帮助信息"
    echo ""
    echo "工作原理："
    echo "  push 模式："
    echo "    1. 刷新 Git 索引 (git update-index --refresh)"
    echo "    2. 扫描工作区变化 (git add -A)"
    echo "    3. 基于文件内容检测变化"
    echo "    4. 自动提交并推送当前分支"
    echo ""
    echo "  pull 模式："
    echo "    1. 暂存本地未提交的修改"
    echo "    2. 强制同步到远程状态 (git reset --hard)"
    echo "    3. 清理未跟踪的文件"
    echo ""
    echo "示例："
    echo "  # 在开发机器上（AI 修改代码后）"
    echo "  ./sync.sh push"
    echo ""
    echo "  # 在服务器上（需要同步最新代码）"
    echo "  ./sync.sh pull"
}

# 主逻辑
case "$MODE" in
    push)
        do_push
        ;;
    pull)
        do_pull
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "无效的参数: $MODE"
        echo ""
        show_help
        exit 1
        ;;
esac
