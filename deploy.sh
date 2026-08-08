#!/bin/bash
# ============================================================
# NEXUS 工作台 · 一键部署脚本
# 用法：bash deploy.sh
# 会自动把 workbench-desktop.html 上传到 GitHub Pages 仓库
# ============================================================

# ---- 配置（改这里） ----
OWNER="grand-avenir"          # 你的 GitHub 用户名
REPO="Workplace-website"      # 公开仓库名（GitHub Pages 托管）
REMOTE_FILE="index.html"      # 远程文件名
LOCAL_FILE="workbench-desktop.html"  # 本地文件名

# Token 从环境变量读取，不硬编码
TOKEN="${GITHUB_TOKEN}"

# ---- 以下无需修改 ----
set -e
cd "$(dirname "$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXUS 部署脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查 Token
if [ -z "$TOKEN" ]; then
  echo ""
  echo "❌ 未检测到 GITHUB_TOKEN 环境变量"
  echo ""
  echo "请先设置 Token（三选一）："
  echo ""
  echo "  【临时使用】在终端执行："
  echo "    export GITHUB_TOKEN='你的token'"
  echo "    bash deploy.sh"
  echo ""
  echo "  【永久保存 · Mac/Linux】在终端执行："
  echo "    echo 'export GITHUB_TOKEN=你的token' >> ~/.bashrc"
  echo "    source ~/.bashrc"
  echo ""
  echo "  【永久保存 · Mac zsh】在终端执行："
  echo "    echo 'export GITHUB_TOKEN=你的token' >> ~/.zshrc"
  echo "    source ~/.zshrc"
  echo ""
  exit 1
fi

# 检查本地文件
if [ ! -f "$LOCAL_FILE" ]; then
  echo "❌ 找不到文件: $LOCAL_FILE"
  echo "   请确保脚本和 $LOCAL_FILE 在同一目录下"
  exit 1
fi

API="https://api.github.com/repos/${OWNER}/${REPO}/contents/${REMOTE_FILE}"

echo ""
echo "📦 仓库:  ${OWNER}/${REPO}"
echo "📄 文件:  ${LOCAL_FILE} → ${REMOTE_FILE}"
echo ""

# 1. 获取当前文件的 SHA（如果存在）
echo "⏳ 检查远程文件..."
SHA=$(curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "$API" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$SHA" ]; then
  echo "   远程文件已存在 (sha: ${SHA:0:7}...)，将执行替换"
else
  echo "   远程文件不存在，将创建新文件"
fi

# 2. Base64 编码本地文件
echo "🔐 编码文件..."
CONTENT=$(base64 -i "$LOCAL_FILE" | tr -d '\n')

# 3. 构建请求体
if [ -n "$SHA" ]; then
  PAYLOAD=$(jq -n \
    --arg msg "deploy: $(date '+%Y-%m-%d %H:%M:%S')" \
    --arg content "$CONTENT" \
    --arg sha "$SHA" \
    '{message: $msg, content: $content, sha: $sha}')
else
  PAYLOAD=$(jq -n \
    --arg msg "deploy: $(date '+%Y-%m-%d %H:%M:%S')" \
    --arg content "$CONTENT" \
    '{message: $msg, content: $content}')
fi

# 4. 上传
echo "🚀 上传中..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$API")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo ""
  echo "✅ 上传成功！(HTTP $HTTP_CODE)"
  echo ""
  echo "🌐 访问地址:"
  echo "   https://${OWNER}.github.io/${REPO}/"
  echo ""
  echo "   （GitHub Pages 可能需要 1-2 分钟生效）"
  echo ""
else
  echo ""
  echo "❌ 上传失败！(HTTP $HTTP_CODE)"
  echo ""
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  echo ""
  if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "💡 Token 可能已过期或权限不足，请检查："
    echo "   - Token 是否有效"
    echo "   - Token 是否有该仓库的 Contents: Read and write 权限"
    echo "   - 仓库名和用户名是否正确"
  fi
  exit 1
fi
