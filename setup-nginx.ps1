# Exit4 Operation Kit - nginx自動セットアップスクリプト
# Windows用 (PowerShell)

# 管理者権限チェック
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Exit4 Operation Kit" -ForegroundColor Cyan
Write-Host "  nginx + SSL セットアップスクリプト" -ForegroundColor Cyan
Write-Host "  (Windows版)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "警告: このスクリプトは管理者権限で実行することを推奨します。" -ForegroundColor Yellow
    Write-Host ""
}

# プロジェクトルートディレクトリ
$PROJECT_ROOT = $PSScriptRoot
Write-Host "プロジェクトルート: $PROJECT_ROOT"
Write-Host ""

# nginxのインストール確認
$nginxPaths = @(
    "C:\nginx\nginx.exe",
    "C:\Program Files\nginx\nginx.exe",
    "$env:ProgramFiles\nginx\nginx.exe"
)

$nginxPath = $null
foreach ($path in $nginxPaths) {
    if (Test-Path $path) {
        $nginxPath = $path
        break
    }
}

if ($null -eq $nginxPath) {
    # PATHからも探す
    $nginxCmd = Get-Command nginx -ErrorAction SilentlyContinue
    if ($null -ne $nginxCmd) {
        $nginxPath = $nginxCmd.Source
    }
}

if ($null -eq $nginxPath) {
    Write-Host "エラー: nginxが見つかりません。" -ForegroundColor Red
    Write-Host ""
    Write-Host "nginxのインストール方法:" -ForegroundColor Yellow
    Write-Host "1. https://nginx.org/en/download.html からダウンロード" -ForegroundColor Yellow
    Write-Host "2. C:\nginx に解凍" -ForegroundColor Yellow
    Write-Host "3. このスクリプトを再実行" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$nginxDir = Split-Path -Parent $nginxPath
Write-Host "✓ nginxが見つかりました: $nginxPath" -ForegroundColor Green
Write-Host ""

# 1. SSL証明書の生成
Write-Host "【ステップ1】SSL証明書の生成" -ForegroundColor Cyan
Write-Host "----------------------------------------"

$sslCertPath = Join-Path $PROJECT_ROOT "ssl\certificate.crt"
$sslKeyPath = Join-Path $PROJECT_ROOT "ssl\private.key"

if ((Test-Path $sslCertPath) -and (Test-Path $sslKeyPath)) {
    Write-Host "⚠ SSL証明書が既に存在します" -ForegroundColor Yellow
    $regenerate = Read-Host "再生成しますか？ (y/N)"
    if ($regenerate -eq "y" -or $regenerate -eq "Y") {
        & "$PROJECT_ROOT\generate-ssl-cert.ps1"
    }
} else {
    & "$PROJECT_ROOT\generate-ssl-cert.ps1"
}

Write-Host "✓ SSL証明書の準備完了" -ForegroundColor Green
Write-Host ""

# 2. nginx設定ファイルの準備
Write-Host "【ステップ2】nginx設定ファイルの準備" -ForegroundColor Cyan
Write-Host "----------------------------------------"

$domain = Read-Host "使用するドメイン名またはIPアドレス [exit4-operation.local]"
if ([string]::IsNullOrWhiteSpace($domain)) {
    $domain = "exit4-operation.local"
}

# 設定ファイルの読み込みと置換
$nginxConfExample = Join-Path $PROJECT_ROOT "nginx.conf.example"
$nginxConfContent = Get-Content $nginxConfExample -Raw

# パスをWindows形式に変換（バックスラッシュをスラッシュに）
$sslCertPathUnix = $sslCertPath -replace '\\', '/'
$sslKeyPathUnix = $sslKeyPath -replace '\\', '/'

# プレースホルダーを置換
$nginxConfContent = $nginxConfContent -replace 'server_name exit4-operation\.local', "server_name $domain"
$nginxConfContent = $nginxConfContent -replace '/path/to/exit4-operation-kit/ssl/certificate\.crt', $sslCertPathUnix
$nginxConfContent = $nginxConfContent -replace '/path/to/exit4-operation-kit/ssl/private\.key', $sslKeyPathUnix

# 一時ファイルに保存
$tempConf = Join-Path $env:TEMP "exit4-nginx.conf"
$nginxConfContent | Out-File -FilePath $tempConf -Encoding UTF8

Write-Host "✓ 設定ファイルを準備しました" -ForegroundColor Green
Write-Host ""

# 3. nginx設定のインストール
Write-Host "【ステップ3】nginx設定のインストール" -ForegroundColor Cyan
Write-Host "----------------------------------------"

$nginxConfDir = Join-Path $nginxDir "conf"
$nginxConfFile = Join-Path $nginxConfDir "exit4.conf"

try {
    Copy-Item $tempConf $nginxConfFile -Force
    Write-Host "✓ 設定ファイルをコピーしました: $nginxConfFile" -ForegroundColor Green
} catch {
    Write-Host "エラー: 設定ファイルのコピーに失敗しました: $_" -ForegroundColor Red
    exit 1
}

# nginx.confにincludeが必要
$nginxMainConf = Join-Path $nginxConfDir "nginx.conf"
$nginxMainConfContent = Get-Content $nginxMainConf -Raw

if ($nginxMainConfContent -notmatch 'include\s+exit4\.conf') {
    Write-Host ""
    Write-Host "nginx.confに以下の行を追加する必要があります:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    include exit4.conf;" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "http { } ブロックの中に追加してください。" -ForegroundColor Yellow
    Write-Host ""
    
    $addInclude = Read-Host "今すぐ追加しますか？ (y/N)"
    if ($addInclude -eq "y" -or $addInclude -eq "Y") {
        # http { の直後に追加
        $nginxMainConfContent = $nginxMainConfContent -replace '(http\s*\{)', "`$1`n    include exit4.conf;"
        $nginxMainConfContent | Out-File -FilePath $nginxMainConf -Encoding UTF8
        Write-Host "✓ nginx.confを更新しました" -ForegroundColor Green
    }
}
Write-Host ""

# 4. 設定のテスト
Write-Host "【ステップ4】nginx設定のテスト" -ForegroundColor Cyan
Write-Host "----------------------------------------"

Push-Location $nginxDir
$testResult = & ".\nginx.exe" -t 2>&1
Pop-Location

Write-Host $testResult

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ nginx設定が正常です" -ForegroundColor Green
} else {
    Write-Host "エラー: nginx設定にエラーがあります。設定を確認してください。" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 5. nginxの再起動
Write-Host "【ステップ5】nginxの再起動" -ForegroundColor Cyan
Write-Host "----------------------------------------"

# nginxのプロセスを確認
$nginxProcess = Get-Process nginx -ErrorAction SilentlyContinue

if ($nginxProcess) {
    Write-Host "nginxをリロードしています..."
    Push-Location $nginxDir
    & ".\nginx.exe" -s reload
    Pop-Location
    Write-Host "✓ nginxをリロードしました" -ForegroundColor Green
} else {
    Write-Host "nginxを起動しています..."
    Push-Location $nginxDir
    Start-Process ".\nginx.exe" -WindowStyle Hidden
    Pop-Location
    Start-Sleep -Seconds 2
    
    $nginxProcess = Get-Process nginx -ErrorAction SilentlyContinue
    if ($nginxProcess) {
        Write-Host "✓ nginxを起動しました" -ForegroundColor Green
    } else {
        Write-Host "警告: nginxの起動を確認できませんでした" -ForegroundColor Yellow
    }
}
Write-Host ""

# 6. hostsファイルの設定案内
Write-Host "【ステップ6】hostsファイルの設定（オプション）" -ForegroundColor Cyan
Write-Host "----------------------------------------"
Write-Host "ローカルでテストする場合、hostsファイルに以下を追加してください:"
Write-Host ""
Write-Host "127.0.0.1  $domain" -ForegroundColor Yellow
Write-Host ""
Write-Host "hostsファイルの場所: C:\Windows\System32\drivers\etc\hosts"
Write-Host ""

if ($isAdmin) {
    $editHosts = Read-Host "今すぐhostsファイルに追加しますか？ (y/N)"
    if ($editHosts -eq "y" -or $editHosts -eq "Y") {
        $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
        $hostsContent = Get-Content $hostsFile -Raw
        
        if ($hostsContent -notmatch [regex]::Escape($domain)) {
            Add-Content $hostsFile "`n127.0.0.1  $domain"
            Write-Host "✓ hostsファイルに追加しました" -ForegroundColor Green
        } else {
            Write-Host "⚠ 既にhostsファイルに存在します" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "注意: hostsファイルの編集には管理者権限が必要です" -ForegroundColor Yellow
}
Write-Host ""

# 7. 完了
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  セットアップが完了しました！" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "次のステップ:"
Write-Host "1. Node.jsサーバーを起動: npm start"
Write-Host "2. ブラウザで https://$domain にアクセス"
Write-Host "3. 自己署名証明書の警告が表示された場合は「続行」を選択"
Write-Host ""
Write-Host "トラブルシューティング:"
Write-Host "- エラーログ確認: $nginxDir\logs\error.log"
Write-Host "- nginx再起動: $nginxDir\nginx.exe -s reload"
Write-Host "- 設定確認: $nginxDir\nginx.exe -t"
Write-Host "- nginxプロセス確認: Get-Process nginx"
Write-Host ""

# クリーンアップ
Remove-Item $tempConf -ErrorAction SilentlyContinue
