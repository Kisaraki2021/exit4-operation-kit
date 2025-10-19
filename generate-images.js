const fs = require('fs');
const path = require('path');
const { createCanvas } = require('canvas');

// テスト用のプレースホルダー画像を生成
function generatePlaceholderImages() {
    const imageDir = path.join(__dirname, 'public', 'image');

    // canvasモジュールがインストールされているか確認
    try {
        require.resolve('canvas');
    } catch (e) {
        console.log('⚠️  canvas モジュールがインストールされていません。');
        console.log('プレースホルダー画像を生成するには以下のコマンドを実行してください:');
        console.log('  npm install canvas');
        console.log('');
        console.log('または、public/image/ ディレクトリに手動で 1.png ~ 20.png を配置してください。');
        return;
    }

    // 画像を生成
    for (let i = 1; i <= 20; i++) {
        const canvas = createCanvas(1280, 720);
        const ctx = canvas.getContext('2d');

        // 背景色（グラデーション）
        const gradient = ctx.createLinearGradient(0, 0, 1280, 720);
        gradient.addColorStop(0, '#667eea');
        gradient.addColorStop(1, '#764ba2');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, 1280, 720);

        // テキスト
        ctx.fillStyle = 'white';
        ctx.font = 'bold 120px Arial';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(`イベント ${i}`, 640, 300);

        ctx.font = 'bold 60px Arial';
        ctx.fillText('作業内容', 640, 420);

        // 枠線
        ctx.strokeStyle = 'white';
        ctx.lineWidth = 10;
        ctx.strokeRect(50, 50, 1180, 620);

        // 画像を保存
        const buffer = canvas.toBuffer('image/png');
        const filePath = path.join(imageDir, `${i}.png`);
        fs.writeFileSync(filePath, buffer);
        console.log(`✅ 生成: ${filePath}`);
    }

    console.log('');
    console.log('🎉 プレースホルダー画像の生成が完了しました！');
}

if (require.main === module) {
    generatePlaceholderImages();
}

module.exports = { generatePlaceholderImages };
