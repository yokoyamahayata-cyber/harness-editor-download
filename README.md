# Harness Editor — ダウンロード配布用

このリポジトリは [takicoach/harness-editor](https://github.com/takicoach/harness-editor)（MIT License）を、
動画編集者へ配布するために **ビルド済み Mac アプリとして再配布** するためのものです。

- 配布ページ（編集者に渡すのはこちら）: https://yokoyamahayata-cyber.github.io/harness-editor-download/
- 本体のソース・開発は上流リポジトリを参照してください: https://github.com/takicoach/harness-editor
- ライセンス: MIT（[LICENSE](LICENSE)）
- 配布物: `Releases` の `Harness-Editor-<version>-mac-apple-silicon.zip`
  - Apple Silicon Mac 専用（M1 以降）
  - ad-hoc 署名（Apple の Developer ID 署名・公証なし）

## インストール（ターミナルに 1 行）

```sh
curl -fsSL https://yokoyamahayata-cyber.github.io/harness-editor-download/install.sh | bash
```

[`install.sh`](install.sh) が、最新リリースの取得 → `ditto` で解凍 → `/Applications` へ設置 →
quarantine 属性の削除 → 起動 までを行います。`sudo` は使いません。
「ダウンロード」フォルダに同じサイズの ZIP があればそれを再利用し、途中で切れた場合は続きから再開します。

テスト用の環境変数: `HARNESS_EDITOR_DEST`（設置先）、`HARNESS_EDITOR_DOWNLOAD_DIR`、`HARNESS_EDITOR_OPEN=0`（起動しない）。

## なぜターミナルが必要か

ad-hoc 署名のアプリをブラウザでダウンロードすると、macOS が付ける `com.apple.quarantine` 属性により
**「"Harness Editor" は壊れているため開けません。ゴミ箱に入れる必要があります。」** と表示されます。
アプリは壊れていません。この表示には「このまま開く」の選択肢が無く、システム設定からの回避もできないため、
quarantine 属性を外す（＝ブラウザを経由せず `curl` で取得する）必要があります。

恒久的に解決するには Apple Developer Program（年額）での Developer ID 署名 + 公証が必要です。

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

リリース後に [`install.sh`](install.sh) 内の `FALLBACK_URL`（GitHub API が使えないときの退避先）と、
[`index.html`](index.html) のバージョン表記・ZIP 直リンクを更新してください。
