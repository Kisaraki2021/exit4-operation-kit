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

### 2. SSL証明書の生成（iOSデバイス対応に必要）

**重要:** iOSデバイスでカメラを使用するには、HTTPS接続が必須です。

**Windows (PowerShell):**
```powershell
.\generate-ssl-cert.ps1
# または
npm run generate-ssl
```

**Linux/macOS:**
```bash
./generate-ssl-cert.sh
```

これにより、`ssl/`ディレクトリに以下のファイルが生成されます:
- `certificate.crt` - SSL証明書
- `private.key` - 秘密鍵

Node.jsサーバーは自動的にSSL証明書を検出してHTTPSモードで起動します。

### 3. サーバーの起動
```bash
npm start
```

- SSL証明書がある場合: `https://localhost:3000` で起動
- SSL証明書がない場合: `http://localhost:3000` で起動（iOS非対応）

### 📱 iOSデバイスでの使用方法

#### オプション1: nginxでHTTPSリバースプロキシを使用（推奨）

自動セットアップスクリプトを実行:
```powershell
.\setup-nginx.ps1
```

その後、`https://exit4-operation.local` でアクセス

#### オプション2: 直接HTTPSサーバーを使用

1. SSL証明書を生成（上記参照）
2. サーバーを起動: `npm start`
3. 同じネットワーク内のPCのIPアドレスを確認
4. iOSデバイスのSafariで `https://[PCのIPアドレス]:3000` にアクセス
5. 証明書の警告が表示されたら「詳細」→「続ける」を選択

#### オプション3: トンネリングサービスを使用

開発環境で簡単にHTTPS接続をテストする場合:
```bash
# ngrokを使用する例
npx ngrok http 3000
```

生成されたHTTPS URLでアクセス可能になります。

### 4. イベント画像の配置
`public/image/` ディレクトリに `1.png` から `20.png` の画像ファイルを配置してください。

## 画面一覧
- ホーム画面: `/`
- 管理画面: `/admin.html`
- 参加者案内: `/participant.html`
- スタッフ指示: `/staff.html`
- タイマー: `/timer.html`
- 進行状況画面: `/progress.html`
- カメラ映像送信: `/camera-sender.html` 📹
- カメラ映像受信: `/camera-receiver.html` 📺

**📱 iOSデバイスでカメラを使用する場合:**
- [カメラセットアップガイド](CAMERA_SETUP.md) - 詳細な技術情報
- [iOSアクセス手順](iOS-ACCESS.md) - すぐに始めるクイックガイド（推奨）

**🎥 複数カメラの送受信:**
- [複数ペア送受信ガイド](MULTI-STREAM-GUIDE.md) - 複数カメラの運用方法

## nginx設定
SSL証明書を使用する場合は、`nginx.conf.example` を参考にnginxを設定してください。

### SSL証明書の生成と設定

#### 簡単セットアップ（推奨）

自動セットアップスクリプトを使用すると、SSL証明書の生成からnginx設定まで一括で実行できます。

**Linux/macOS:**
```bash
./setup-nginx.sh
```

**Windows (PowerShell - 管理者権限推奨):**
```powershell
.\setup-nginx.ps1
```

このスクリプトは以下を自動で実行します:
1. SSL証明書の生成
2. nginx設定ファイルの準備と配置
3. nginx設定のテストと再起動
4. hostsファイルの設定（オプション）

#### 手動セットアップ

##### 1. SSL証明書の生成
**Linux/macOS:**
```bash
./generate-ssl-cert.sh
```

**Windows (PowerShell):**
```powershell
.\generate-ssl-cert.ps1
```

スクリプトを実行すると、`./ssl/` ディレクトリに以下のファイルが生成されます:
- `certificate.crt` - SSL証明書
- `private.key` - 秘密鍵

**注意:** `ssl/`ディレクトリは`.gitignore`に含まれており、Gitで管理されません。

##### 2. nginx設定ファイルの配置

**Linux/macOS:**
```bash
# 設定ファイルをコピー
sudo cp nginx.conf.example /etc/nginx/sites-available/exit4

# シンボリックリンクを作成
sudo ln -s /etc/nginx/sites-available/exit4 /etc/nginx/sites-enabled/

# 設定ファイルを編集（証明書のパスとserver_nameを変更）
sudo nano /etc/nginx/sites-available/exit4

# 設定テスト
sudo nginx -t

# nginxを再起動
sudo systemctl restart nginx
```

**Windows:**
```powershell
# 設定ファイルをコピー
copy nginx.conf.example C:\nginx\conf\exit4.conf

# nginx.confに以下を追加:
# include conf/exit4.conf;

# 設定ファイルを編集（証明書のパスとserver_nameを変更）
notepad C:\nginx\conf\exit4.conf

# 設定テスト
C:\nginx\nginx.exe -t

# nginxをリロード
C:\nginx\nginx.exe -s reload
```

##### 3. hostsファイルの設定（ローカルテスト用）

**Linux/macOS:**
```bash
sudo nano /etc/hosts
```

**Windows (管理者権限):**
```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

以下の行を追加:
```
127.0.0.1  exit4-operation.local
```

##### 4. アクセス確認

ブラウザで `https://exit4-operation.local` にアクセス

**注意:** 自己署名証明書のため、ブラウザでセキュリティ警告が表示されます。
「詳細設定」→「サイトにアクセスする」を選択してください。

### nginx設定のポイント

- **リバースプロキシ:** Node.jsサーバー(ポート3000)へのリクエストを転送
- **WebSocket対応:** `/ws` エンドポイントで長時間接続をサポート
- **SSL/TLS:** TLSv1.2/1.3をサポート、安全な暗号化設定
- **セキュリティヘッダー:** XSS、クリックジャッキング対策のヘッダーを追加
- **静的ファイルキャッシュ:** 画像/CSS/JSファイルのキャッシュでパフォーマンス向上

詳細な設定手順とトラブルシューティングは `nginx.conf.example` を参照してください。

## トラブルシューティング

### カメラ映像が送受信できない

#### 問題: "undefined is not an object (evaluating 'navigator.mediaDevices.getUserMedia')"

**原因:** iOS SafariではHTTP接続でカメラAPIが使用できません。

**解決方法:**
1. HTTPS接続を使用する（上記「iOSデバイスでの使用方法」参照）
2. SSL証明書を生成: `npm run generate-ssl`
3. サーバーを再起動
4. `https://`でアクセス

#### 問題: カメラの許可が求められない

**確認事項:**
- ブラウザのカメラ権限設定を確認
- iOSの場合: 設定 > Safari > カメラ が「確認」または「許可」になっているか
- 他のアプリやタブでカメラを使用していないか

#### 問題: WebSocket接続エラー

**解決方法:**
- HTTPSで接続している場合、WebSocketも自動的にWSS（セキュア）になります
- nginxを使用している場合、WebSocketプロキシ設定を確認
- ファイアウォールでポート3000（またはnginxのポート）が開放されているか確認

#### 問題: 映像が受信側に表示されない

**確認事項:**
1. 送信側と受信側の両方が同じサーバーに接続しているか
2. ブラウザのコンソールでエラーメッセージを確認
3. ネットワーク環境（ファイアウォール、プロキシ）を確認
4. STUNサーバーへの接続を確認（インターネット接続が必要）

### SSL証明書の警告が表示される

**これは正常です。** 自己署名証明書を使用しているためです。

**対処方法:**
1. ブラウザで「詳細」または「Advanced」をクリック
2. 「サイトにアクセスする」または「Proceed」を選択

本番環境では Let's Encrypt などの正式な証明書を使用してください。

### ポート3000が既に使用されている

**解決方法:**
```bash
# 環境変数でポート番号を変更
set PORT=3001
npm start
```

または他のアプリケーションが3000番ポートを使用していないか確認してください。

## システム仕様

### データ構造
- **回数**: 30秒ごとに1増加
- **進行度合**: 管理画面で手動で増加
- **イベントナンバー**: 事前に用意された1-20のランダム配列から回数に応じて取得
- **スタッフ指示ステータス**: 回数ごとにリセットされるブール値(デフォルト: false)
