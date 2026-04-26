#!/usr/bin/env bash
# 本地 release helper：在 Mac 上跑（需要装好 DevEco Studio 5.x 并已签好 build-profile signingConfig）。
# 用法: ./release.sh v0.3.0 "feat: redirect-gateway 修复"
#  - tag 必须是 v 开头的 semver
#  - 第二个参数当 release notes
# 流程: dep-build (若 dep-ohos 不存在) → hvigorw assembleHap release → git tag/push → gh release create
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vTAG> [release-notes]" >&2
    exit 1
fi
TAG="$1"
NOTES="${2:-Release $TAG}"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "ERROR: tag 必须是 vX.Y.Z 格式" >&2
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 1. native deps（缺则 build）
if [ ! -d "$DIR/dep-ohos/lib" ]; then
    echo "==> dep-ohos 不存在，跑 dep-build.sh"
    bash ./dep-build.sh
fi

# 2. 找 hvigorw
HVIGORW=""
if [ -x "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw" ]; then
    HVIGORW="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw"
elif [ -x "$DIR/hvigorw" ]; then
    HVIGORW="$DIR/hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
    HVIGORW="$(command -v hvigorw)"
else
    echo "ERROR: 找不到 hvigorw，请确认 DevEco Studio 5.x 已安装或 PATH 中有 hvigorw" >&2
    exit 1
fi
echo "==> hvigorw: $HVIGORW"

# 3. clean + assembleHap release
"$HVIGORW" --mode module -p product=default -p buildMode=release assembleHap --no-daemon

# 4. 找产物
HAP=$(find "$DIR/entry/build" -name "*-default-signed.hap" -o -name "*-default-signed.hsp" 2>/dev/null | head -1)
if [ -z "$HAP" ]; then
    echo "ERROR: 没找到 signed hap，请检查 build-profile signingConfigs 是否配置好" >&2
    exit 1
fi
echo "==> hap: $HAP"

# 5. tag + push
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "tag $TAG 已存在，跳过 git tag"
else
    git tag -a "$TAG" -m "$NOTES"
    git push origin "$TAG"
fi

# 6. gh release
if ! command -v gh >/dev/null 2>&1; then
    echo "WARN: 没装 gh，跳过 release 创建。手动 upload: $HAP"
    exit 0
fi
gh release create "$TAG" "$HAP" --title "$TAG" --notes "$NOTES" || \
    gh release upload "$TAG" "$HAP" --clobber

echo "==> done: $TAG"
