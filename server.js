const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// 静的ファイルの提供
app.use(express.static('public'));

// システム状態
const state = {
    count: 0,              // 回数
    progress: 0,           // 進行度合
    eventNumbers: [],      // イベントナンバー配列
    staffStatus: false,    // スタッフ指示ステータス
    shouldIncreaseProgress: false, // 進行度合を増やすかどうか
};

// イベントナンバー配列を初期化（1-20をシャッフル）
function initializeEventNumbers() {
    state.eventNumbers = Array.from({ length: 20 }, (_, i) => i + 1);
    // Fisher-Yatesシャッフル
    for (let i = state.eventNumbers.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [state.eventNumbers[i], state.eventNumbers[j]] = [state.eventNumbers[j], state.eventNumbers[i]];
    }
}

// 初期化
initializeEventNumbers();

// 全クライアントに状態を送信
function broadcastState() {
    const currentEventNumber = state.eventNumbers[state.count % state.eventNumbers.length];
    const nextEventNumber = state.eventNumbers[(state.count + 1) % state.eventNumbers.length];

    const message = JSON.stringify({
        type: 'state',
        data: {
            count: state.count,
            progress: state.progress,
            currentEventNumber,
            nextEventNumber,
            staffStatus: state.staffStatus,
        },
    });

    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// タイマー更新を全クライアントに送信
function broadcastTimer(remainingSeconds) {
    const message = JSON.stringify({
        type: 'timer',
        data: {
            remainingSeconds,
        },
    });

    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// 30秒タイマー
let timerInterval;
let currentTimerSeconds = 30;

function startTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
    }

    currentTimerSeconds = 30;

    timerInterval = setInterval(() => {
        currentTimerSeconds--;
        broadcastTimer(currentTimerSeconds);

        if (currentTimerSeconds <= 0) {
            // 回数を増やす
            state.count++;

            // 進行度合を増やすかチェック
            if (state.shouldIncreaseProgress) {
                state.progress++;
                state.shouldIncreaseProgress = false;
            }

            // スタッフ指示ステータスをリセット
            state.staffStatus = false;

            // タイマーをリセット
            currentTimerSeconds = 30;

            // 状態をブロードキャスト
            broadcastState();
        }
    }, 1000);
}

// タイマー開始
startTimer();

// WebSocket接続
wss.on('connection', (ws) => {
    console.log('新しいクライアントが接続しました');

    // クライアント識別用のID
    ws.clientId = Math.random().toString(36).substr(2, 9);
    ws.streamId = null; // ストリームID（送信側のみ設定）
    ws.role = null; // 'sender' または 'receiver'

    // 接続時に現在の状態を送信
    const currentEventNumber = state.eventNumbers[state.count % state.eventNumbers.length];
    const nextEventNumber = state.eventNumbers[(state.count + 1) % state.eventNumbers.length];

    ws.send(JSON.stringify({
        type: 'state',
        data: {
            count: state.count,
            progress: state.progress,
            currentEventNumber,
            nextEventNumber,
            staffStatus: state.staffStatus,
        },
    }));

    ws.send(JSON.stringify({
        type: 'timer',
        data: {
            remainingSeconds: currentTimerSeconds,
        },
    }));

    // メッセージ受信
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'setProgressIncrease':
                    // 進行度合を増やすかどうかを設定
                    state.shouldIncreaseProgress = data.value;
                    break;

                case 'setStaffStatus':
                    // スタッフ指示ステータスを更新
                    state.staffStatus = data.value;
                    broadcastState();
                    break;

                case 'reset':
                    // すべてをリセット
                    state.count = 0;
                    state.progress = 0;
                    state.staffStatus = false;
                    state.shouldIncreaseProgress = false;
                    initializeEventNumbers();
                    currentTimerSeconds = 30;
                    broadcastState();
                    broadcastTimer(currentTimerSeconds);
                    break;

                // クライアント登録（送信側/受信側の識別）
                case 'register':
                    ws.role = data.role;
                    if (data.role === 'sender') {
                        ws.streamId = data.streamId || ws.clientId;
                        console.log(`送信側登録: ${ws.streamId}`);
                    } else if (data.role === 'receiver') {
                        console.log(`受信側登録: ${ws.clientId}`);
                        // 既存の送信側のリストを送信
                        const senders = Array.from(wss.clients)
                            .filter(c => c.role === 'sender' && c.readyState === WebSocket.OPEN)
                            .map(c => ({ streamId: c.streamId, clientId: c.clientId }));
                        ws.send(JSON.stringify({
                            type: 'sender-list',
                            senders: senders
                        }));
                    }
                    // 受信側に新しい送信側を通知
                    if (data.role === 'sender') {
                        wss.clients.forEach((client) => {
                            if (client.role === 'receiver' && client.readyState === WebSocket.OPEN) {
                                client.send(JSON.stringify({
                                    type: 'new-sender',
                                    streamId: ws.streamId,
                                    clientId: ws.clientId
                                }));
                            }
                        });
                    }
                    break;

                // 受信側からの接続要求
                case 'request-connection':
                    const requestedStreamId = data.streamId;
                    const receiverId = data.receiverId;
                    console.log(`接続要求: streamId=${requestedStreamId}, receiverId=${receiverId}`);

                    // 該当する送信側に通知
                    wss.clients.forEach((client) => {
                        if (client.role === 'sender' && client.streamId === requestedStreamId && client.readyState === WebSocket.OPEN) {
                            client.send(JSON.stringify({
                                type: 'new-receiver',
                                receiverId: receiverId
                            }));
                        }
                    });
                    break;

                // WebRTCシグナリング - ストリームIDベースで転送
                case 'webrtc-offer':
                case 'webrtc-answer':
                case 'webrtc-ice-candidate':
                    const targetStreamId = data.streamId;
                    const targetReceiverId = data.receiverId;
                    console.log(`WebRTCシグナリング: ${data.type} streamId=${targetStreamId} receiverId=${targetReceiverId} from ${ws.clientId} (${ws.role})`);

                    // ストリームIDに基づいて適切なクライアントに転送
                    const forwardMessage = JSON.stringify(data);
                    wss.clients.forEach((client) => {
                        if (client !== ws && client.readyState === WebSocket.OPEN) {
                            // 送信側からのメッセージは該当する受信側へ
                            if (ws.role === 'sender' && client.role === 'receiver' && client.clientId === targetReceiverId) {
                                client.send(forwardMessage);
                            }
                            // 受信側からのメッセージは該当する送信側へ
                            else if (ws.role === 'receiver' && client.role === 'sender' && client.streamId === targetStreamId) {
                                client.send(forwardMessage);
                            }
                        }
                    });
                    break;
            }
        } catch (error) {
            console.error('メッセージ処理エラー:', error);
        }
    });

    ws.on('close', () => {
        console.log(`クライアントが切断しました: ${ws.clientId} (${ws.role})`);
        // 送信側が切断した場合、受信側に通知
        if (ws.role === 'sender') {
            wss.clients.forEach((client) => {
                if (client.role === 'receiver' && client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify({
                        type: 'sender-disconnected',
                        streamId: ws.streamId
                    }));
                }
            });
        }
        // 受信側が切断した場合、送信側に通知
        else if (ws.role === 'receiver') {
            wss.clients.forEach((client) => {
                if (client.role === 'sender' && client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify({
                        type: 'receiver-disconnected',
                        receiverId: ws.clientId
                    }));
                }
            });
        }
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`サーバーが起動しました: http://localhost:${PORT}`);
});
