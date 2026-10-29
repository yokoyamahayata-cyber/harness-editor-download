# Harness Editor — ダウンロード配布用

このリポジトリは [takicoach/harness-editor](https://github.com/takicoach/harness-editor)（MIT License）を、
動画編集者へ配布するために **ビルド済み Mac アプリとして再配布** するためのものです。

- 本体のソース・開発は上流リポジトリを参照してください: https://github.com/takicoach/harness-editor
- ライセンス: MIT（[LICENSE](LICENSE)）
- 配布物: `Releases` の `Harness-Editor-0.8.2-mac-apple-silicon.zip`
  - Apple Silicon Mac 専用（M1〜M4）
  - ad-hoc 署名（Apple の公証なし）のため、初回起動時に macOS の確認画面が出ます

## インストール手順

[配布ページ](https://github.com/yokoyamahayata-cyber/harness-editor-download/releases/latest) から ZIP をダウンロードし、
解凍して出てくる `Harness Editor.app` を「アプリケーション」フォルダへ入れてください。

初回のみ、macOS のセキュリティ確認を通す必要があります:

1. アプリをダブルクリック →「開発元を確認できないため開けません」と出る
2. システム設定 →「プライバシーとセキュリティ」を開く
3. 下の方にある「"Harness Editor" は開発元を確認できないため…」の横の **「このまま開く」** を押す
4. もう一度ダブルクリックして「開く」を選ぶ（2回目以降は不要）
