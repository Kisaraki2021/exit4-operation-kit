# iOSデバイスからのアクセス手順

## 現在の設定

✅ **サーバー起動中**: `https://localhost:3000`  
✅ **SSL証明書に含まれるアドレス**:
- localhost
- exit4-operation.local
- 127.0.0.1
- **10.0.12.197** 

## iOSデバイスからアクセスする方法

### 前提条件
- iOSデバイスとPCが同じWi-Fiネットワークに接続されている
- サーバーが起動している（`npm start`）
- ファイアウォールでポート3000が許可されている

### アクセス手順

1. **iOSのSafariを開く**

2. **以下のURLにアクセス**:
   ```
   https://10.0.12.197:3000
   ```

3. **セキュリティ警告が表示される**:
   - 「このWebサイトを閲覧」または「続ける」をタップ
   - これは自己署名証明書のため表示される正常な警告です

4. **ホーム画面が表示される**:
   - 📹 カメラ映像送信: `https://10.0.12.197:3000/camera-sender.html`
   - 📺 カメラ映像受信: `https://10.0.12.197:3000/camera-receiver.html`

5. **カメラ映像送信ページでカメラを許可**:
   - 「📹 送信開始」ボタンをタップ
   - カメラとマイクへのアクセスを許可
   - カメラ映像が表示されたら成功！

## トラブルシューティング

### 問題: "サーバーに接続できません"

**解決方法:**
```powershell
# Windows ファイアウォールでポート3000を許可
New-NetFirewallRule -DisplayName "Exit4 HTTPS" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### 問題: "このサイトにアクセスできません"

**確認事項:**
1. PCとiOSデバイスが同じネットワークに接続されているか
2. PCのIPアドレスが10.0.12.197であることを確認:
   ```powershell
   ipconfig | Select-String "IPv4"
   ```
3. サーバーが起動しているか確認:
   ```powershell
   Get-Process node
   ```

### 問題: "undefined is not an object (evaluating 'navigator.mediaDevices.getUserMedia')"

**原因:** HTTP接続でアクセスしている

**解決方法:**
- URLが `https://`（HTTPSの"s"に注意）で始まることを確認
- `http://` では動作しません

### 問題: カメラの許可が求められない

**確認事項:**
1. iOSの設定を確認:
   - 設定 > Safari > カメラ = 「確認」または「許可」
2. 他のタブやアプリでカメラを使用していないか確認
3. Safariを完全に閉じて再度開く

## PCのIPアドレスが変わった場合

PCのIPアドレスが変わった場合、SSL証明書を再生成する必要があります。

```powershell
# 新しいIPアドレスを確認
ipconfig | Select-String "IPv4"

# 証明書を再生成（IPアドレスを実際の値に変更）
& "C:\Program Files\Git\usr\bin\openssl.exe" req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/private.key -out ssl/certificate.crt -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Exit4 Operation/OU=IT/CN=localhost" -addext "subjectAltName=DNS:localhost,DNS:exit4-operation.local,IP:127.0.0.1,IP:新しいIPアドレス"

# サーバーを再起動
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
npm start
```

## 便利なコマンド

### 証明書の内容を確認
```powershell
& "C:\Program Files\Git\usr\bin\openssl.exe" x509 -in ssl/certificate.crt -text -noout | Select-String "Subject:|DNS:|IP Address:"
```

### サーバーのステータス確認
```powershell
# Node.jsプロセスが起動しているか確認
Get-Process node -ErrorAction SilentlyContinue

# ポート3000が使用されているか確認
netstat -ano | findstr :3000
```

### サーバーの停止
```powershell
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
```

### サーバーの起動
```powershell
npm start
```

## 参考リンク

- [詳細なセットアップガイド](CAMERA_SETUP.md)
- [README](README.md)
- [nginx設定例](nginx.conf.example)
