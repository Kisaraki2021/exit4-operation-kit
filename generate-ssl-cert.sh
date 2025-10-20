#!/bin/bash

# SSL証明書生成スクリプト (自己署名証明書)
# LAN内でのHTTPS通信用

set -e

echo "====================================="
echo "  SSL証明書生成スクリプト"
echo "====================================="
echo ""

# デフォルト値
DEFAULT_DOMAIN="exit4-operation.local"
DEFAULT_DAYS=365
CERT_DIR="./ssl"

# ドメイン名の入力
read -p "ドメイン名またはIPアドレスを入力してください [${DEFAULT_DOMAIN}]: " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

# 有効期限の入力
read -p "証明書の有効期限（日数）を入力してください [${DEFAULT_DAYS}]: " DAYS
DAYS=${DAYS:-$DEFAULT_DAYS}

# SSL証明書ディレクトリの作成
mkdir -p "${CERT_DIR}"

echo ""
echo "証明書を生成しています..."
echo "ドメイン: ${DOMAIN}"
echo "有効期限: ${DAYS}日"
echo "出力先: ${CERT_DIR}/"
echo ""

# 自己署名証明書の生成
openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
  -keyout "${CERT_DIR}/private.key" \
  -out "${CERT_DIR}/certificate.crt" \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Exit4 Operation/OU=IT/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"

# 権限設定
chmod 600 "${CERT_DIR}/private.key"
chmod 644 "${CERT_DIR}/certificate.crt"

echo ""
echo "====================================="
echo "  証明書の生成が完了しました！"
echo "====================================="
echo ""
echo "生成されたファイル:"
echo "  秘密鍵: ${CERT_DIR}/private.key"
echo "  証明書: ${CERT_DIR}/certificate.crt"
echo ""
echo "次のステップ:"
echo "1. nginx設定ファイルで証明書のパスを設定"
echo "2. ブラウザで https://${DOMAIN} にアクセス"
echo "3. セキュリティ警告が表示された場合は「詳細設定」→「続行」"
echo ""
echo "注意: これは自己署名証明書のため、ブラウザで警告が表示されます。"
echo "     LAN内での使用には問題ありませんが、本番環境では正式な証明書を使用してください。"
echo ""
