# カメラ映像送受信機能 セットアップガイド

## 概要

このシステムはWebRTCを使用してカメラ映像をリアルタイムで送受信します。
**重要:** iOSデバイス（iPhone/iPad）でカメラを使用するには、HTTPS接続が必須です。

## クイックスタート

### 1. SSL証明書の生成

**重要:** SSL証明書には、アクセスするすべてのドメイン名とIPアドレスを含める必要があります。

```powershell
# Git for Windowsに含まれるOpenSSLを使用
# PCのIPアドレスを確認
ipconfig | Select-String "IPv4"

# 証明書を生成（IPアドレスを実際の値に置き換えてください）
& "C:\Program Files\Git\usr\bin\openssl.exe" req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/private.key -out ssl/certificate.crt -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Exit4 Operation/OU=IT/CN=localhost" -addext "subjectAltName=DNS:localhost,DNS:exit4-operation.local,IP:127.0.0.1,IP:10.0.12.197"
```

**注意:** `IP:10.0.12.197` の部分は、お使いのPCの実際のIPアドレスに変更してください。

### 2. サーバーの起動

```bash
npm start
```

サーバーは自動的にSSL証明書を検出し、HTTPSモードで起動します：
- **HTTPS**: https://localhost:3000
- **WebSocket**: wss://localhost:3000

### 3. アクセス

#### PC/Macから
1. ブラウザで `https://localhost:3000` にアクセス
2. 証明書の警告が表示されたら「詳細」→「続行」を選択
3. カメラ送信: `/camera-sender.html`
4. カメラ受信: `/camera-receiver.html`

#### iOSデバイスから（同じネットワーク内）
1. PCのIPアドレスを確認（既に証明書に含まれている場合はスキップ）:
   ```powershell
   ipconfig | Select-String "IPv4"
   ```
   
2. IPアドレスが証明書に含まれているか確認:
   ```powershell
   & "C:\Program Files\Git\usr\bin\openssl.exe" x509 -in ssl/certificate.crt -text -noout | Select-String "IP Address"
   ```
   
3. 含まれていない場合は、証明書を再生成（上記「SSL証明書の生成」参照）

4. iOSのSafariで `https://10.0.12.197:3000` にアクセス
   - **重要:** IPアドレスは証明書に含まれているものを使用してください
   
5. 証明書の警告が表示されたら「詳細」→「このWebサイトを閲覧」を選択

6. カメラの使用を許可

## 技術仕様

### WebRTC接続フロー

```
送信側 (Sender)           サーバー              受信側 (Receiver)
    |                        |                        |
    |-- register (sender) -->|                        |
    |                        |<-- register (receiver)-|
    |                        |-- sender-list -------->|
    |                        |<-- request-connection -|
    |<-- new-receiver -------|                        |
    |                        |                        |
    |-- webrtc-offer ------->|-- webrtc-offer ------->|
    |                        |<-- webrtc-answer ------|
    |<-- webrtc-answer ------|                        |
    |                        |                        |
    |-- ice-candidate ------>|-- ice-candidate ------>|
    |<-- ice-candidate ------|<-- ice-candidate ------|
    |                        |                        |
    |<====== RTC接続確立 ========================>|
    |                        |                        |
    |======== 映像ストリーム送信 =================>|
```

### STUNサーバー

WebRTC接続にはSTUNサーバーを使用してNAT越えを実現しています：
- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`

## トラブルシューティング

### 問題: iOSで "undefined is not an object (evaluating 'navigator.mediaDevices.getUserMedia')"

**原因:** iOS SafariではHTTP接続でカメラAPIが使用できません。

**解決方法:**
1. ✅ HTTPS接続を使用（上記手順1-2を実施）
2. ✅ `https://`でアクセス

### 問題: カメラの許可が求められない

**確認事項:**
- [ ] ブラウザのカメラ権限設定
- [ ] iOS: 設定 > Safari > カメラ = 「確認」または「許可」
- [ ] 他のアプリやタブでカメラを使用していないか
- [ ] HTTPSで接続しているか（URLが`https://`で始まる）

### 問題: 映像が受信側に表示されない

**チェックリスト:**
1. [ ] 送信側と受信側が同じサーバーに接続しているか
2. [ ] ブラウザのコンソールでエラーを確認
3. [ ] ファイアウォールでポート3000が開放されているか
4. [ ] インターネット接続が有効か（STUNサーバーへの接続に必要）
5. [ ] ネットワークがSTUN/TURNトラフィックをブロックしていないか

### 問題: "接続中..."のまま動かない

**解決方法:**
1. サーバーが起動しているか確認:
   ```powershell
   Get-Process node
   ```
2. WebSocketが正常に接続しているかブラウザのコンソールで確認:
   ```javascript
   // コンソールに "WebSocket接続成功" が表示されるはず
   ```
3. ファイアウォールを確認

### 問題: SSL証明書の警告が消えない

**これは正常です。** 自己署名証明書を使用しているためです。

**対処方法:**
1. ブラウザで「詳細」または「Advanced」をクリック
2. 「このWebサイトを閲覧」または「Proceed to localhost」を選択

**iOS Safari の場合:**
1. 「詳細」をタップ
2. 「このWebサイトを閲覧」をタップ

本番環境では Let's Encrypt などの正式な証明書を使用してください。

## nginxでのHTTPS運用（推奨）

本番環境やより安定した環境では、nginxをリバースプロキシとして使用することを推奨します。

### セットアップ

```powershell
.\setup-nginx.ps1
```

このスクリプトが自動的に以下を実行します:
- SSL証明書の生成
- nginx設定ファイルの配置
- nginx設定のテストと再起動

詳細は `nginx.conf.example` を参照してください。

## セキュリティに関する注意

### 本番環境での推奨事項

1. **正式なSSL証明書を使用**
   - Let's Encrypt（無料）
   - 商用SSL証明書

2. **ファイアウォール設定**
   - 必要なポートのみ開放（80, 443）
   - 不要なポートは閉じる

3. **定期的なアップデート**
   - Node.jsパッケージを最新に保つ
   - nginxを最新バージョンに更新
   - セキュリティパッチを適用

4. **アクセス制限**
   - IP制限の検討
   - 認証機能の追加

### 自己署名証明書の制限

- ブラウザで警告が表示される
- 公開インターネットには不適切
- LAN内での使用や開発環境に限定

## パフォーマンス最適化

### 推奨設定

1. **解像度の調整** (camera-sender.html)
   ```javascript
   const constraints = {
       video: {
           width: { ideal: 1280 },  // 解像度を下げてパフォーマンス向上
           height: { ideal: 720 },
           frameRate: { ideal: 30, max: 30 }  // フレームレートの制限
       },
       audio: true
   };
   ```

2. **複数受信者の場合**
   - 各受信者に個別のRTCPeerConnectionを作成
   - 帯域幅を考慮してストリーム数を制限

3. **ネットワーク最適化**
   - 可能な限り有線LAN接続を使用
   - WiFiの場合は5GHz帯を使用
   - ルーターのQoS設定でWebRTCトラフィックを優先

## よくある質問（FAQ）

### Q: HTTP接続でカメラは使えますか？
A: localhostまたは127.0.0.1からのアクセスの場合は可能ですが、iOSでは不可能です。HTTPS接続を推奨します。

### Q: 複数のカメラを同時に送信できますか？
A: 可能です。各送信側が個別のストリームIDを持ち、受信側は複数のストリームを同時に表示できます。

### Q: 音声のみ・映像のみの送信は可能ですか？
A: 可能です。`getUserMedia`の`constraints`で`audio: false`または`video: false`を設定してください。

### Q: 接続が頻繁に切断されます
A: 以下を確認してください:
- ネットワークの安定性
- ファイアウォール設定
- ルーターのUPnP/NAT設定
- STUNサーバーへの接続性

### Q: LANの外からアクセスできますか？
A: 以下のいずれかの方法で可能です:
1. ルーターでポートフォワーディングを設定
2. ngrokなどのトンネリングサービスを使用
3. VPNを使用してLAN内に接続

## サポート

問題が解決しない場合:
1. ブラウザのコンソールログを確認
2. サーバーのログを確認
3. `README.md`のトラブルシューティングセクションを参照
4. GitHubのIssuesで報告

## 関連ドキュメント

- [README.md](README.md) - 全体的なセットアップガイド
- [nginx.conf.example](nginx.conf.example) - nginx設定の詳細
- [WebRTC API - MDN](https://developer.mozilla.org/ja/docs/Web/API/WebRTC_API)
- [getUserMedia - MDN](https://developer.mozilla.org/ja/docs/Web/API/MediaDevices/getUserMedia)
