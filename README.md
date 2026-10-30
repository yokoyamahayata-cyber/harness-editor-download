# Harness Editor — ダウンロード配布用

このリポジトリは [takicoach/harness-editor](https://github.com/takicoach/harness-editor)（MIT License）を、
動画編集者へ配布するために **ビルド済み Mac アプリとして再配布** するためのものです。

- 配布ページ（編集者に渡すのはこちら）: https://yokoyamahayata-cyber.github.io/harness-editor-download/
- 本体のソース・開発は上流リポジトリを参照してください: https://github.com/takicoach/harness-editor
- ライセンス: MIT（[LICENSE](LICENSE)）
- 配布物: `Releases` の `Harness-Editor-<version>-mac-apple-silicon.pkg`（配布ページのボタン用）と `.zip`（install.sh 用）
  - Apple Silicon Mac 専用（M1 以降）
  - ad-hoc 署名（Apple の Developer ID 署名・公証なし）

## インストール（配布ページのボタン → .pkg）

編集者に渡すのは [配布ページ](https://yokoyamahayata-cyber.github.io/harness-editor-download/) のダウンロードボタンです。
ボタンから落ちるのは **`Harness-Editor-<version>-mac-apple-silicon.pkg`**（インストーラ）で、
ダブルクリック → 「完了」→ システム設定「プライバシーとセキュリティ」→「このまま開く」→ インストーラ実行、で入ります。
ターミナルは不要です。

### なぜ .pkg なのか

ad-hoc 署名のアプリ(.app)をブラウザでダウンロードすると `com.apple.quarantine` が付き、
macOS 26 では **「"Harness Editor" は壊れているため開けません」**（ゴミ箱/キャンセルの2択・回避手段なし）になります。
実機検証の結果:

| 配布形式 | ダブルクリック時 | 回避 |
|---|---|---|
| .zip（.app 直） | 「壊れているため開けません」 | 不可（quarantine 削除のみ） |
| .dmg | 同上（マウント元の quarantine がコピー先へ伝播するのを確認） | 不可 |
| **.pkg** | 「Apple は…検証できませんでした」＋**「完了」** | **システム設定「このまま開く」で可** |

さらに **quarantine 付き .pkg からインストールした中身には quarantine が一切付かない**ことを確認済み（`xattr -r` で 0 件）。
そのため 2 回目以降はアプリを普通にダブルクリックで開けます。

### .pkg のビルド方法

`pkgbuild` は `テロップテンプレート` のような日本語パスを含むペイロードで BOM 生成に失敗するため、
**ZIP 一個をペイロードにして postinstall で展開する**構成にしています。

```sh
W=./pkgwork
mkdir -p $W/staging $W/scripts $W/resources
cp Harness-Editor-<ver>-mac-apple-silicon.zip $W/staging/app.zip
# scripts/postinstall: /private/tmp/harness-editor-install/app.zip を ditto 展開 →
#   /Applications へ配置 → quarantine 削除 → ログインユーザとして open
pkgbuild --root $W/staging --scripts $W/scripts   --install-location /private/tmp/harness-editor-install   --identifier jp.takicoach.harness-editor.pkg --version <ver> $W/component.pkg
productbuild --distribution $W/dist.xml --package-path $W --resources $W/resources   Harness-Editor-<ver>-mac-apple-silicon.pkg
```

`dist.xml` は `enable_localSystem="true"` のみ・`customize="never"`・`hostArchitectures="arm64"`。

### ターミナルが使える人向け（確認画面を 1 回も出さない）

```sh
curl -fsSL https://yokoyamahayata-cyber.github.io/harness-editor-download/install.sh | bash
```

[`install.sh`](install.sh) が ZIP を curl で取得（＝quarantine が付かない）し、設置・起動まで行います。
テスト用の環境変数: `HARNESS_EDITOR_DEST` / `HARNESS_EDITOR_DOWNLOAD_DIR` / `HARNESS_EDITOR_OPEN=0`。

### 恒久対策

Apple Developer Program（年$99）で Developer ID 署名＋公証すれば、確認画面は一切出なくなります。
現状このマシンに署名証明書はありません（`security find-identity` が 0 件）。

## リリース手順

上流の最新タグからクリーンクローンし、

```sh
npm ci
npm --prefix desktop ci
npm --prefix desktop run build:media   # dist/desktop/media/ を使い回せば短縮可
npm run desktop:mac
```

で生成した ZIP を Release に添付します。約 475MB の upload は HTTP 408 で落ちやすいので、
先に release を作ってから `gh release upload --clobber` をリトライループで回します。

ZIP を Release に上げたら、上記手順で `.pkg` も作って同じ Release に添付します。
リリース後に [`install.sh`](install.sh) 内の `FALLBACK_URL` と、[`index.html`](index.html) のバージョン表記・
.pkg 直リンク・ファイルサイズを更新してください。
