# Git Hooks

此目录包含项目的 Git Hooks 脚本，用于自动化代码质量检查。

## 安装

在首次克隆仓库或更新 hooks 后，需要运行安装脚本：

```bash
bash .githooks/install.sh
```

或者使用 Git 配置自动使用此目录（Git 2.9+）：

```bash
git config core.hooksPath .githooks
```

## 可用的 Hooks

### pre-commit

在 `git commit` 之前自动执行：

- **功能**：自动格式化待提交的 Swift 代码
- **工具**：使用 Apple 官方的 `swift-format` 进行格式化
- **行为**：
  - 检测所有待提交的 `.swift` 文件
  - 使用 `swift-format` 格式化这些文件
  - 自动将格式化后的文件重新暂存
  - 如果未安装 `swift-format`，会给出警告但不会阻止提交

## 安装 swift-format

### 使用 Homebrew（推荐）

```bash
brew install swift-format
```

### 使用 Mint

```bash
mint install apple/swift-format
```

### 从源码构建

```bash
git clone https://github.com/apple/swift-format.git
cd swift-format
swift build -c release
```

## 配置

`swift-format` 使用 Apple 官方的默认规则，也可以在项目根目录创建 `.swift-format` 配置文件进行自定义。

## 跳过 Hook 检查

如果需要暂时跳过 hook 检查（不推荐）：

```bash
git commit --no-verify
```

或使用简写：

```bash
git commit -n
```

## 卸载

删除已安装的 hooks：

```bash
rm -rf .git/hooks/pre-commit
```

## 故障排查

### Hook 没有执行

1. 检查 hook 是否有执行权限：
   ```bash
   ls -l .git/hooks/pre-commit
   ```

2. 重新安装：
   ```bash
   bash .githooks/install.sh
   ```

### swift-format 找不到

确保 `swift-format` 在 PATH 中：

```bash
which swift-format
```

如果没有，请重新安装或将其添加到 PATH。

## 维护

更新 hooks 后，团队成员需要重新运行安装脚本：

```bash
bash .githooks/install.sh
```
