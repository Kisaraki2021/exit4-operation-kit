#!/bin/bash

# Exit4 Operation Kit - nginx自動セットアップスクリプト
# Linux/macOS用

set -e

echo "=========================================="
echo "  Exit4 Operation Kit"
echo "  nginx + SSL セットアップスクリプト"
echo "=========================================="
echo ""

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# エラー処理
error_exit() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

# 成功メッセージ
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 警告メッセージ
warning_msg() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# nginxがインストールされているか確認
if ! command -v nginx &> /dev/null; then
    error_exit "nginxがインストールされていません。先にnginxをインストールしてください。"
fi

success_msg "nginxが見つかりました"

# プロジェクトルートディレクトリ
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "プロジェクトルート: $PROJECT_ROOT"
echo ""

# 1. SSL証明書の生成
echo "【ステップ1】SSL証明書の生成"
echo "----------------------------------------"

if [ -f "$PROJECT_ROOT/ssl/certificate.crt" ] && [ -f "$PROJECT_ROOT/ssl/private.key" ]; then
    warning_msg "SSL証明書が既に存在します"
    read -p "再生成しますか？ (y/N): " REGENERATE
    if [[ $REGENERATE =~ ^[Yy]$ ]]; then
        bash "$PROJECT_ROOT/generate-ssl-cert.sh"
    fi
else
    bash "$PROJECT_ROOT/generate-ssl-cert.sh"
fi

success_msg "SSL証明書の準備完了"
echo ""

# 2. nginx設定ファイルの準備
echo "【ステップ2】nginx設定ファイルの準備"
echo "----------------------------------------"

# ドメイン名の入力
read -p "使用するドメイン名またはIPアドレス [exit4-operation.local]: " DOMAIN
DOMAIN=${DOMAIN:-exit4-operation.local}

# 設定ファイルの一時コピーを作成
TEMP_CONF="/tmp/exit4-nginx.conf"
cp "$PROJECT_ROOT/nginx.conf.example" "$TEMP_CONF"

# プレースホルダーを置換
sed -i.bak "s|server_name exit4-operation.local|server_name $DOMAIN|g" "$TEMP_CONF"
sed -i.bak "s|/path/to/exit4-operation-kit/ssl/certificate.crt|$PROJECT_ROOT/ssl/certificate.crt|g" "$TEMP_CONF"
sed -i.bak "s|/path/to/exit4-operation-kit/ssl/private.key|$PROJECT_ROOT/ssl/private.key|g" "$TEMP_CONF"

success_msg "設定ファイルを準備しました"
echo ""

# 3. nginx設定のインストール
echo "【ステップ3】nginx設定のインストール"
echo "----------------------------------------"

# sites-availableディレクトリの確認
if [ -d "/etc/nginx/sites-available" ]; then
    NGINX_AVAILABLE="/etc/nginx/sites-available/exit4"
    NGINX_ENABLED="/etc/nginx/sites-enabled/exit4"
    
    echo "設定ファイルを /etc/nginx/sites-available/exit4 にコピーします"
    echo "管理者権限が必要です..."
    
    sudo cp "$TEMP_CONF" "$NGINX_AVAILABLE"
    sudo chown root:root "$NGINX_AVAILABLE"
    sudo chmod 644 "$NGINX_AVAILABLE"
    
    # シンボリックリンクの作成
    if [ -L "$NGINX_ENABLED" ]; then
        warning_msg "シンボリックリンクが既に存在します"
    else
        sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
        success_msg "シンボリックリンクを作成しました"
    fi
else
    # macOS や他のディストリビューション
    NGINX_CONF_DIR="/usr/local/etc/nginx"
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        NGINX_CONF_DIR="/etc/nginx"
    fi
    
    echo "設定ファイルを $NGINX_CONF_DIR/servers/exit4.conf にコピーします"
    
    sudo mkdir -p "$NGINX_CONF_DIR/servers"
    sudo cp "$TEMP_CONF" "$NGINX_CONF_DIR/servers/exit4.conf"
    sudo chown root:wheel "$NGINX_CONF_DIR/servers/exit4.conf" 2>/dev/null || sudo chown root:root "$NGINX_CONF_DIR/servers/exit4.conf"
    sudo chmod 644 "$NGINX_CONF_DIR/servers/exit4.conf"
fi

success_msg "nginx設定をインストールしました"
echo ""

# 4. 設定のテスト
echo "【ステップ4】nginx設定のテスト"
echo "----------------------------------------"

if sudo nginx -t; then
    success_msg "nginx設定が正常です"
else
    error_exit "nginx設定にエラーがあります。設定を確認してください。"
fi
echo ""

# 5. nginxの再起動
echo "【ステップ5】nginxの再起動"
echo "----------------------------------------"

if command -v systemctl &> /dev/null; then
    sudo systemctl restart nginx
    sudo systemctl status nginx --no-pager
elif command -v service &> /dev/null; then
    sudo service nginx restart
else
    sudo nginx -s reload
fi

success_msg "nginxを再起動しました"
echo ""

# 6. hostsファイルの設定案内
echo "【ステップ6】hostsファイルの設定（オプション）"
echo "----------------------------------------"
echo "ローカルでテストする場合、hostsファイルに以下を追加してください:"
echo ""
echo -e "${YELLOW}127.0.0.1  $DOMAIN${NC}"
echo ""
echo "hostsファイルの場所: /etc/hosts"
echo ""
read -p "今すぐhostsファイルを編集しますか？ (y/N): " EDIT_HOSTS

if [[ $EDIT_HOSTS =~ ^[Yy]$ ]]; then
    sudo sh -c "echo '127.0.0.1  $DOMAIN' >> /etc/hosts"
    success_msg "hostsファイルに追加しました"
fi
echo ""

# 7. 完了
echo "=========================================="
echo -e "${GREEN}  セットアップが完了しました！${NC}"
echo "=========================================="
echo ""
echo "次のステップ:"
echo "1. Node.jsサーバーを起動: npm start"
echo "2. ブラウザで https://$DOMAIN にアクセス"
echo "3. 自己署名証明書の警告が表示された場合は「続行」を選択"
echo ""
echo "トラブルシューティング:"
echo "- エラーログ確認: sudo tail -f /var/log/nginx/exit4_error.log"
echo "- nginx再起動: sudo systemctl restart nginx (または sudo nginx -s reload)"
echo "- 設定確認: sudo nginx -t"
echo ""

# クリーンアップ
rm -f "$TEMP_CONF" "$TEMP_CONF.bak"
