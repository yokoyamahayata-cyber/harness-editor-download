#!/bin/bash
#
# Harness Editor インストーラ
#
#   curl -fsSL https://yokoyamahayata-cyber.github.io/harness-editor-download/install.sh | bash
#
# やること: ZIP のダウンロード → 解凍 → アプリケーションフォルダへ設置 →
#           macOS がダウンロードファイルに付ける隔離属性(quarantine)の削除 → 起動
# やらないこと: 外部への送信、sudo、システム設定の変更。
#
set -uo pipefail

REPO="yokoyamahayata-cyber/harness-editor-download"
FALLBACK_URL="https://github.com/${REPO}/releases/download/v0.8.2/Harness-Editor-0.8.2-mac-apple-silicon.zip"
APP_NAME="Harness Editor.app"
DEST_DIR="${HARNESS_EDITOR_DEST:-/Applications}"
DOWNLOAD_DIR="${HARNESS_EDITOR_DOWNLOAD_DIR:-$HOME/Downloads}"
OPEN_AFTER="${HARNESS_EDITOR_OPEN:-1}"

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else B=""; G=""; Y=""; R=""; N=""; fi

TMP_DIR=""
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

say()  { printf '%s\n' "$*"; }
step() { printf '\n%s▶ %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$R" "$1" "$N" >&2; shift; for l in "$@"; do printf '  %s\n' "$l" >&2; done; exit 1; }

say ""
say "${B}Harness Editor インストーラ${N}"
say "────────────────────────────────"

# 1. この Mac で動くか
if [ "$(uname -s)" != "Darwin" ]; then
  die "このインストーラは Mac 専用です。"
fi
if [ "$(uname -m)" != "arm64" ]; then
  die "このアプリは Apple Silicon（M1 以降）の Mac 専用です。" \
      "お使いの Mac は Intel のため、配布ページの「Intel Mac・Windows をお使いの方へ」" \
      "にあるソース版をご利用ください。"
fi

# 2. ダウンロード先 URL を決める（最新リリースを問い合わせ、失敗したら既定版）
step "最新版を確認しています"
API_JSON=$(curl -fsSL --max-time 20 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)
URL=$(printf '%s\n' "$API_JSON" | grep -o 'https://[^"]*\.zip' | head -1)
VERSION=$(printf '%s\n' "$API_JSON" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
if [ -z "$URL" ]; then
  URL="$FALLBACK_URL"
  VERSION="0.8.2"
  say "  （バージョン確認に失敗したので、既定の ${VERSION} を使います）"
fi
ZIP_NAME=$(basename "$URL")
ok "バージョン ${VERSION}"

# 3. すでに同じ ZIP があれば使い回す（475MB の再ダウンロードを避ける）
REMOTE_SIZE=$(curl -sIL --max-time 20 "$URL" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v+0}')
ZIP_PATH="${DOWNLOAD_DIR}/${ZIP_NAME}"
mkdir -p "$DOWNLOAD_DIR" 2>/dev/null
REUSED=0

if [ "${REMOTE_SIZE:-0}" -gt 0 ]; then
  # ブラウザで入れた「(1)」付きのファイル名も拾う。サイズ一致を完了の判定に使う。
  for candidate in "$DOWNLOAD_DIR"/Harness-Editor-*.zip; do
    [ -f "$candidate" ] || continue
    if [ "$(stat -f%z "$candidate" 2>/dev/null || echo 0)" = "$REMOTE_SIZE" ]; then
      ZIP_PATH="$candidate"; REUSED=1; break
    fi
  done
elif [ -f "$ZIP_PATH" ] && [ "$(stat -f%z "$ZIP_PATH" 2>/dev/null || echo 0)" -gt 400000000 ]; then
  REUSED=1
fi

if [ "$REUSED" = "1" ]; then
  step "ダウンロード済みの ZIP を使います"
  ok "$(basename "$ZIP_PATH")"
else
  # 中途半端に残っているファイルは、続きから落とせる場合だけ残す
  if [ -f "$ZIP_PATH" ] && [ "${REMOTE_SIZE:-0}" -gt 0 ] \
     && [ "$(stat -f%z "$ZIP_PATH" 2>/dev/null || echo 0)" -gt "$REMOTE_SIZE" ]; then
    rm -f "$ZIP_PATH"
  fi
  step "ダウンロードしています（約 475 MB・回線により 5〜15 分）"
  say "  進捗バーが伸びていれば動いています。終わるまでそのままお待ちください。"
  if ! curl -fL --progress-bar --retry 3 --retry-delay 2 -C - -o "$ZIP_PATH" "$URL"; then
    die "ダウンロードに失敗しました。" \
        "Wi-Fi の安定した場所で、もう一度同じコマンドを実行してください。" \
        "（途中まで落ちた分は残してあるので、次は続きから始まります）"
  fi
  ok "ダウンロード完了"
fi

# 4. 解凍（ZIP の中の署名を壊さないため unzip ではなく ditto を使う）
step "解凍しています"
TMP_DIR=$(mktemp -d /tmp/harness-editor.XXXXXX) || die "作業フォルダを作れませんでした。"
if ! ditto -x -k "$ZIP_PATH" "$TMP_DIR" 2>/dev/null; then
  rm -f "$ZIP_PATH"
  die "ZIP を解凍できませんでした（ダウンロードが途中で切れていました）。" \
      "壊れたファイルは削除したので、もう一度同じコマンドを実行してください。"
fi
APP_SRC=$(find "$TMP_DIR" -maxdepth 3 -name "$APP_NAME" -type d -print 2>/dev/null | head -1)
[ -n "$APP_SRC" ] || die "ZIP の中にアプリが見つかりませんでした。" "お手数ですが、配布元へご連絡ください。"
ok "解凍完了"

# 5. 起動中なら終了させる（上書きのため）
if pgrep -f "/${APP_NAME}/Contents/MacOS/" >/dev/null 2>&1; then
  step "起動中の Harness Editor を終了しています"
  osascript -e 'quit app "Harness Editor"' >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "/${APP_NAME}/Contents/MacOS/" >/dev/null 2>&1 || break
    /bin/sleep 1
  done
  pkill -f "/${APP_NAME}/Contents/MacOS/" >/dev/null 2>&1
  /bin/sleep 1
  ok "終了しました"
fi

# 6. アプリケーションフォルダへ設置
step "アプリケーションフォルダへ入れています"
if [ ! -w "$DEST_DIR" ]; then
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
  say "  （/Applications に書き込めないため ${DEST_DIR} へ入れます）"
fi
APP_DEST="${DEST_DIR}/${APP_NAME}"
if [ -e "$APP_DEST" ]; then
  rm -rf "$APP_DEST" || die "古いアプリを置き換えられませんでした。" "Harness Editor を終了してから、もう一度実行してください。"
fi
mv "$APP_SRC" "$APP_DEST" || die "アプリを移動できませんでした。"
ok "$APP_DEST"

# 7. 隔離属性を外す（これをしないと「壊れている」と表示される）
step "ダウンロード時の制限を外しています"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null
xattr -cr "$APP_DEST" 2>/dev/null
ok "完了"

# 8. 起動
say ""
say "${G}${B}インストールが終わりました。${N}"
say ""
say "  ・2 回目からは Launchpad やアプリケーションフォルダから、"
say "    普通にダブルクリックで開けます。"
say "  ・ダウンロードした ZIP は ${ZIP_PATH} に残っています。"
say "    消してかまいません。"
say ""
if [ "$OPEN_AFTER" = "1" ]; then
  open "$APP_DEST" || say "${Y}自動起動できませんでした。アプリケーションフォルダから開いてください。${N}"
  say "Harness Editor を起動しました。初回は立ち上がるまで少し時間がかかります。"
fi
say ""
