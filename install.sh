#!/usr/bin/env bash
# Webcoding 一键安装脚本 (Linux / macOS)
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/HsMirage/webcoding/main/install.sh | bash
# 或指定安装目录:
#   curl -fsSL https://raw.githubusercontent.com/HsMirage/webcoding/main/install.sh | bash -s -- ~/mydir

set -e

REPO="https://github.com/HsMirage/webcoding.git"
INSTALL_DIR="${1:-$HOME/webcoding}"

# ── 颜色 ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
info()    { printf "%b[Webcoding]%b %s\n" "$CYAN" "$NC" "$*"; }
success() { printf "%b[Webcoding]%b %s\n" "$GREEN" "$NC" "$*"; }
warn()    { printf "%b[Webcoding]%b %s\n" "$YELLOW" "$NC" "$*"; }
error()   { printf "%b[Webcoding] ERROR:%b %s\n" "$RED" "$NC" "$*" >&2; exit 1; }

# ── 检查依赖 ──────────────────────────────────────────────────
info "检查依赖环境..."

command -v git  >/dev/null 2>&1 || error "未找到 git。请先安装 git: https://git-scm.com/"
command -v node >/dev/null 2>&1 || error "未找到 Node.js。请先安装 Node.js >= 18: https://nodejs.org/"
command -v npm  >/dev/null 2>&1 || error "未找到 npm，请确认 Node.js 安装完整。"

# 检查 Node.js 版本 >= 18
NODE_MAJOR=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 18 ]; then
  error "Node.js 版本过低 (当前: $(node -v))，需要 >= 18。请升级: https://nodejs.org/"
fi

success "Node.js $(node -v)  npm $(npm -v)  git $(git --version | awk '{print $3}') — 全部就绪"

# ── 安装 / 更新 ────────────────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
  warn "检测到已有安装目录: $INSTALL_DIR"
  if [ -t 0 ]; then
    printf "是否拉取最新代码进行更新? (y/N) "
    read -r yn
  else
    yn="n"
    warn "通过管道运行，跳过交互，默认不更新。如需更新请直接运行脚本文件。"
  fi
  case $yn in
    [Yy]*)
      info "拉取最新代码..."
      git -C "$INSTALL_DIR" pull --ff-only
      ;;
    *)
      info "跳过更新，使用现有安装目录继续。"
      ;;
  esac
elif [ -d "$INSTALL_DIR" ]; then
  error "目录已存在但不是 git 仓库: $INSTALL_DIR — 请手动删除后重试: rm -rf $INSTALL_DIR"
else
  info "克隆仓库到 $INSTALL_DIR ..."
  git clone --depth 1 "$REPO" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

info "安装 Node.js 依赖..."
npm install --omit=dev

# ── 写入快捷启动脚本 ───────────────────────────────────────────
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
LAUNCHER="$BIN_DIR/webcoding"
cat > "$LAUNCHER" << LAUNCHER_EOF
#!/usr/bin/env bash
exec node "$INSTALL_DIR/server.js" "\$@"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# 确保 ~/.local/bin 在 PATH 里
add_to_path() {
  local rc="$1"
  if [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" 2>/dev/null; then
    echo '' >> "$rc"
    echo '# Webcoding' >> "$rc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    warn "已将 ~/.local/bin 写入 $rc，请重开终端或运行: source $rc"
  fi
}

SHELL_NAME=$(basename "${SHELL:-bash}")
case "$SHELL_NAME" in
  zsh)  add_to_path "$HOME/.zshrc" ;;
  bash) add_to_path "$HOME/.bashrc" ;;
  fish)
    mkdir -p "$HOME/.config/fish/conf.d"
    echo "fish_add_path $BIN_DIR" > "$HOME/.config/fish/conf.d/webcoding.fish"
    ;;
esac

# ── 完成提示 ───────────────────────────────────────────────────
echo ""
success "================================================"
success " Webcoding 安装完成！"
success "================================================"
echo ""
echo "  启动命令 : webcoding"
echo "  或直接   : node $INSTALL_DIR/server.js"
echo "  访问地址 : http://localhost:8001"
echo ""
info "首次启动时会自动生成登录密码并打印在控制台。"
echo ""

# 询问是否立即启动（管道模式下跳过交互）
if [ -t 0 ]; then
  printf "现在立即启动 Webcoding? (Y/n) "
  read -r start_now
  case $start_now in
    [Nn]*) info "安装完成，稍后运行 'webcoding' 启动。" ;;
    *)     exec node "$INSTALL_DIR/server.js" ;;
  esac
else
  info "通过管道运行，跳过交互。稍后运行 'webcoding' 启动。"
fi
