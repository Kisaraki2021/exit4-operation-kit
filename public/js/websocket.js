// WebSocket接続管理
class WebSocketClient {
    constructor() {
        this.ws = null;
        this.reconnectInterval = 3000;
        this.statusCallbacks = [];
        this.messageCallbacks = [];
        this.connect();
    }

    connect() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;

        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('WebSocket接続成功');
            this.notifyStatus(true);
        };

        this.ws.onmessage = (event) => {
            try {
                // Blobの場合はテキストに変換
                if (event.data instanceof Blob) {
                    event.data.text().then(text => {
                        try {
                            const data = JSON.parse(text);
                            this.notifyMessage(data);
                        } catch (error) {
                            console.error('Blob内のJSON解析エラー:', error, 'データ:', text);
                        }
                    });
                } else {
                    const data = JSON.parse(event.data);
                    this.notifyMessage(data);
                }
            } catch (error) {
                console.error('メッセージ解析エラー:', error, 'データ型:', typeof event.data, 'データ:', event.data);
            }
        };

        this.ws.onclose = () => {
            console.log('WebSocket接続切断');
            this.notifyStatus(false);
            // 再接続を試みる
            setTimeout(() => this.connect(), this.reconnectInterval);
        };

        this.ws.onerror = (error) => {
            console.error('WebSocketエラー:', error);
        };
    }

    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(data));
        } else {
            console.error('WebSocketが接続されていません');
        }
    }

    onStatusChange(callback) {
        this.statusCallbacks.push(callback);
    }

    onMessage(callback) {
        this.messageCallbacks.push(callback);
    }

    notifyStatus(isConnected) {
        this.statusCallbacks.forEach(callback => callback(isConnected));
    }

    notifyMessage(data) {
        this.messageCallbacks.forEach(callback => callback(data));
    }
}

// グローバルWebSocketクライアント
const wsClient = new WebSocketClient();
