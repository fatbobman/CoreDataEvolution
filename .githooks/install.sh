#!/bin/bash

# Git Hooks 安装脚本
# 将 .githooks 目录中的钩子复制到 .git/hooks

echo "📦 安装 Git Hooks..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 创建 .git/hooks 目录（如果不存在）
mkdir -p "$PROJECT_ROOT/.git/hooks"

# 复制所有 hook 文件
for hook in "$SCRIPT_DIR"/*; do
    # 跳过安装脚本本身和 README
    if [[ "$(basename "$hook")" == "install.sh" ]] || [[ "$(basename "$hook")" == "README.md" ]]; then
        continue
    fi

    hook_name=$(basename "$hook")
    echo "  ✓ 安装 $hook_name"

    # 复制并设置执行权限
    cp "$hook" "$PROJECT_ROOT/.git/hooks/$hook_name"
    chmod +x "$PROJECT_ROOT/.git/hooks/$hook_name"
done

echo ""
echo "✅ Git Hooks 安装完成!"
echo ""
echo "提示:"
echo "  • 如需跳过 hook 检查: git commit --no-verify"
echo "  • 安装 swift-format: brew install swift-format"
echo ""
