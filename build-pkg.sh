#!/bin/bash
#
# 配布用 .pkg インストーラを作る
#   ./build-pkg.sh <version> <path/to/Harness-Editor-<ver>-mac-apple-silicon.zip>
#
# pkgbuild は「テロップテンプレート」のような日本語パスを含むペイロードで
# BOM 生成に失敗する（parent directory ... does not exist）ため、
# ZIP 一個をペイロードにして postinstall で /Applications へ展開する。
#
set -euo pipefail

VERSION="${1:-}"
ZIP="${2:-}"
if [ -z "$VERSION" ] || [ -z "$ZIP" ]; then
  echo "usage: $0 <version> <app zip>" >&2; exit 1
fi
[ -f "$ZIP" ] || { echo "ZIP が見つかりません: $ZIP" >&2; exit 1; }

OUT="Harness-Editor-${VERSION}-mac-apple-silicon.pkg"
W=$(mktemp -d /tmp/he-pkgbuild.XXXXXX)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W"/{staging,scripts,resources}

cp "$ZIP" "$W/staging/app.zip"

cat > "$W/scripts/postinstall" <<'EOF'
#!/bin/sh
# staging に置いた ZIP を /Applications へ展開する
STAGE="/private/tmp/harness-editor-install"
ZIP="$STAGE/app.zip"
APP_DEST="/Applications/Harness Editor.app"

[ -f "$ZIP" ] || exit 1

/usr/bin/pkill -f "/Harness Editor.app/Contents/MacOS/" 2>/dev/null
/bin/sleep 1

TMP=$(/usr/bin/mktemp -d /private/tmp/he-unpack.XXXXXX) || exit 1
if ! /usr/bin/ditto -x -k "$ZIP" "$TMP"; then
  /bin/rm -rf "$TMP"; exit 1
fi

APP_SRC=$(/usr/bin/find "$TMP" -maxdepth 2 -name "Harness Editor.app" -type d -print 2>/dev/null | /usr/bin/head -1)
if [ -z "$APP_SRC" ]; then
  /bin/rm -rf "$TMP"; exit 1
fi

/bin/rm -rf "$APP_DEST"
if ! /bin/mv "$APP_SRC" "$APP_DEST"; then
  /bin/rm -rf "$TMP"; exit 1
fi

/usr/sbin/chown -R root:wheel "$APP_DEST" 2>/dev/null
/usr/bin/xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null
/bin/rm -rf "$TMP" "$STAGE"

CONSOLE_UID=$(/usr/bin/stat -f %u /dev/console 2>/dev/null)
if [ -n "$CONSOLE_UID" ] && [ "$CONSOLE_UID" -ne 0 ] 2>/dev/null; then
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/open -a "$APP_DEST" 2>/dev/null
fi
exit 0
EOF
chmod +x "$W/scripts/postinstall"

cat > "$W/resources/welcome.html" <<'EOF'
<html><body style="font-family:-apple-system,'Hiragino Kaku Gothic ProN',sans-serif;font-size:13px;line-height:1.85;color:#1d1d1f">
<p>Harness Editor を「アプリケーション」フォルダにインストールします。</p>
<p>「続ける」を押して進めてください。途中で Mac のパスワード（または Touch ID）を求められます。</p>
<p style="color:#6e6e73">・インストールには 1〜2 分かかります<br>・終わると自動で Harness Editor が開きます<br>・2 回目からは Launchpad からダブルクリックで開けます</p>
</body></html>
EOF

cat > "$W/resources/conclusion.html" <<'EOF'
<html><body style="font-family:-apple-system,'Hiragino Kaku Gothic ProN',sans-serif;font-size:13px;line-height:1.85;color:#1d1d1f">
<p><b>インストールが完了しました。</b></p>
<p>Harness Editor が自動で開きます（初回は立ち上がるまで少し時間がかかります）。</p>
<p>もし開かない場合は、Launchpad または「アプリケーション」フォルダの Harness Editor をダブルクリックしてください。</p>
<p style="color:#6e6e73">ダウンロードした .pkg ファイルは、もう消してかまいません。</p>
</body></html>
EOF

cat > "$W/dist.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Harness Editor</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
  <choices-outline><line choice="default"/></choices-outline>
  <choice id="default" visible="false"><pkg-ref id="jp.takicoach.harness-editor.pkg"/></choice>
  <pkg-ref id="jp.takicoach.harness-editor.pkg">component.pkg</pkg-ref>
</installer-gui-script>
EOF

echo "▶ pkgbuild"
pkgbuild --root "$W/staging" --scripts "$W/scripts" \
  --install-location /private/tmp/harness-editor-install \
  --identifier jp.takicoach.harness-editor.pkg --version "$VERSION" \
  "$W/component.pkg"

echo "▶ productbuild"
productbuild --distribution "$W/dist.xml" --package-path "$W" --resources "$W/resources" "$OUT"

echo "▶ 検証"
pkgutil --expand-full "$OUT" "$W/expanded" >/dev/null
a=$(shasum -a 256 "$W/expanded/component.pkg/Payload/app.zip" | cut -c1-64)
b=$(shasum -a 256 "$ZIP" | cut -c1-64)
[ "$a" = "$b" ] || { echo "✗ ペイロードが元の ZIP と一致しません" >&2; exit 1; }
echo "✓ ペイロード整合 OK"
ls -lh "$OUT"
echo
echo "次: gh release upload v${VERSION} \"$OUT\" --clobber -R yokoyamahayata-cyber/harness-editor-download"
