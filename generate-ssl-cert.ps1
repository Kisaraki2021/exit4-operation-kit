# SSL証明書生成スクリプト (PowerShell版)
# Windows環境用 - 自己署名証明書の生成

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  SSL証明書生成スクリプト (Windows)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# デフォルト値
$DEFAULT_DOMAIN = "exit4-operation.local"
$DEFAULT_DAYS = 365
$CERT_DIR = ".\ssl"

# 現在のIPアドレスを取得
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress

Write-Host "検出されたIPアドレス: $localIP" -ForegroundColor Cyan
Write-Host ""

# ドメイン名の入力
$DOMAIN = Read-Host "ドメイン名またはIPアドレスを入力してください [$DEFAULT_DOMAIN]"
if ([string]::IsNullOrWhiteSpace($DOMAIN)) {
    $DOMAIN = $DEFAULT_DOMAIN
}

# IPアドレスの入力
$IP_ADDRESS = Read-Host "追加するIPアドレスを入力してください（カンマ区切りで複数可） [$localIP]"
if ([string]::IsNullOrWhiteSpace($IP_ADDRESS)) {
    $IP_ADDRESS = $localIP
}

# 有効期限の入力
$DAYS_INPUT = Read-Host "証明書の有効期限（日数）を入力してください [$DEFAULT_DAYS]"
if ([string]::IsNullOrWhiteSpace($DAYS_INPUT)) {
    $DAYS = $DEFAULT_DAYS
} else {
    $DAYS = [int]$DAYS_INPUT
}

# SSL証明書ディレクトリの作成
if (-not (Test-Path $CERT_DIR)) {
    New-Item -ItemType Directory -Path $CERT_DIR | Out-Null
}

Write-Host ""
Write-Host "証明書を生成しています..." -ForegroundColor Yellow
Write-Host "ドメイン: $DOMAIN"
Write-Host "有効期限: $DAYS 日"
Write-Host "IPアドレス: $IP_ADDRESS"
Write-Host "出力先: $CERT_DIR\"
Write-Host ""

# OpenSSLがインストールされているか確認
$opensslPath = Get-Command openssl -ErrorAction SilentlyContinue

# SubjectAltNameの構築
$ipAddresses = $IP_ADDRESS -split ',' | ForEach-Object { $_.Trim() }
$sanIPs = ($ipAddresses | ForEach-Object { "IP:$_" }) -join ','
$sanEntries = "DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1,$sanIPs"

Write-Host "SAN エントリ: $sanEntries" -ForegroundColor Gray
Write-Host ""

if ($null -eq $opensslPath) {
    Write-Host "エラー: OpenSSLがインストールされていません。" -ForegroundColor Red
    Write-Host ""
    Write-Host "以下の方法でOpenSSLをインストールしてください:" -ForegroundColor Yellow
    Write-Host "1. Chocolatey経由: choco install openssl" -ForegroundColor Yellow
    Write-Host "2. 公式サイト: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    Write-Host "3. Git for Windowsに含まれるOpenSSLを使用" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "または、Windows証明書ストアを使用する場合:" -ForegroundColor Yellow
    Write-Host "以下のコマンドを実行してください（管理者権限が必要）:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "`$cert = New-SelfSignedCertificate -DnsName '$DOMAIN' -CertStoreLocation 'Cert:\LocalMachine\My' -NotAfter (Get-Date).AddDays($DAYS)" -ForegroundColor Cyan
    Write-Host "`$pwd = ConvertTo-SecureString -String 'YourPassword' -Force -AsPlainText" -ForegroundColor Cyan
    Write-Host "Export-PfxCertificate -Cert `$cert -FilePath '$CERT_DIR\certificate.pfx' -Password `$pwd" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 自己署名証明書の生成
$privateKeyPath = Join-Path $CERT_DIR "private.key"
$certificatePath = Join-Path $CERT_DIR "certificate.crt"

& openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 `
  -keyout $privateKeyPath `
  -out $certificatePath `
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Exit4 Operation/OU=IT/CN=$DOMAIN" `
  -addext "subjectAltName=$sanEntries"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  証明書の生成が完了しました！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "生成されたファイル:"
    Write-Host "  秘密鍵: $privateKeyPath" -ForegroundColor Cyan
    Write-Host "  証明書: $certificatePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "次のステップ:"
    Write-Host "1. nginx設定ファイルで証明書のパスを設定"
    Write-Host "2. ブラウザで https://$DOMAIN にアクセス"
    Write-Host "3. セキュリティ警告が表示された場合は「詳細設定」→「続行」"
    Write-Host ""
    Write-Host "注意: これは自己署名証明書のため、ブラウザで警告が表示されます。" -ForegroundColor Yellow
    Write-Host "     LAN内での使用には問題ありませんが、本番環境では正式な証明書を使用してください。" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "エラー: 証明書の生成に失敗しました。" -ForegroundColor Red
    Write-Host ""
    exit 1
}
