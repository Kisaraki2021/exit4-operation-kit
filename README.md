# 4番出口 運営システム

文化祭出し物運営用システム

## 技術スタック
- HTML, CSS, JavaScript
- Node.js + Express
- WebSocket (リアルタイム通信)
- WebRTC (カメラ映像送受信)
- nginx (Webサーバーホスティング)

## セットアップ

### 1. 依存関係のインストール
```bash
npm install
```

### 2. サーバーの起動
```bash
npm start
```

サーバーは http://localhost:3000 で起動します。

### 3. イベント画像の配置
`public/image/` ディレクトリに `1.png` から `20.png` の画像ファイルを配置してください。

## 画面一覧
- ホーム画面: `/`
- 管理画面: `/admin.html`
- 参加者案内: `/participant.html`
- スタッフ指示: `/staff.html`
- タイマー: `/timer.html`
- 進行状況画面: `/progress.html`
- カメラ映像送信: `/camera-sender.html`
- カメラ映像受信: `/camera-receiver.html`

## nginx設定
SSL証明書を使用する場合は、`nginx.conf.example` を参考にnginxを設定してください。

## システム仕様

### データ構造
- **回数**: 30秒ごとに1増加
- **進行度合**: 管理画面で手動で増加
- **イベントナンバー**: 事前に用意された1-20のランダム配列から回数に応じて取得
- **スタッフ指示ステータス**: 回数ごとにリセットされるブール値(デフォルト: false)
