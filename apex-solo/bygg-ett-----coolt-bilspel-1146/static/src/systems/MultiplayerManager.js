/**
 * MultiplayerManager.js
 * Multiplayer system for online racing and ghost challenges
 * Handles matchmaking, room management, and real-time sync
 * Note: This is a client-side implementation - requires backend server
 */

class MultiplayerManager {
    constructor() {
        // Connection state
        this.isConnected = false;
        this.connectionState = 'disconnected';
        this.playerId = null;
        this.playerName = 'Player';
        
        // Room state
        this.currentRoom = null;
        this.roomPlayers = [];
        this.isHost = false;
        
        // Game state
        this.gameState = 'lobby';
        this.otherPlayers = new Map();
        this.localPlayerData = null;
        
        // Network settings
        this.serverUrl = 'wss://gravshift-server.example.com';
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.heartbeatInterval = null;
        this.lastPing = 0;
        this.ping = 0;
        
        // Interpolation
        this.interpolationBuffer = new Map();
        this.interpolationDelay = 100; // ms
        
        // Event callbacks
        this.callbacks = {
            onConnect: null,
            onDisconnect: null,
            onRoomJoin: null,
            onRoomLeave: null,
            onPlayerJoin: null,
            onPlayerLeave: null,
            onGameStart: null,
            onGameEnd: null,
            onPlayerUpdate: null,
            onChatMessage: null,
            onError: null
        };
        
        // Mock mode for offline testing
        this.mockMode = true;
        this.mockPlayers = [];
        
        // Initialize
        this.initialize();
    }
    
    /**
     * Initialize multiplayer manager
     */
    initialize() {
        // Generate player ID
        this.playerId = this.generatePlayerId();
        
        // Load saved name
        this.loadPlayerData();
        
        console.log('MultiplayerManager initialized');
    }
    
    /**
     * Generate unique player ID
     */
    generatePlayerId() {
        const saved = localStorage.getItem('gravshift_player_id');
        if (saved) return saved;
        
        const id = 'player_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 9);
        localStorage.setItem('gravshift_player_id', id);
        return id;
    }
    
    /**
     * Load player data
     */
    loadPlayerData() {
        try {
            const saved = localStorage.getItem('gravshift_multiplayer');
            if (saved) {
                const data = JSON.parse(saved);
                this.playerName = data.name || 'Player';
            }
        } catch (e) {
            console.error('Failed to load player data:', e);
        }
    }
    
    /**
     * Save player data
     */
    savePlayerData() {
        try {
            const data = {
                name: this.playerName,
                id: this.playerId
            };
            localStorage.setItem('gravshift_multiplayer', JSON.stringify(data));
        } catch (e) {
            console.error('Failed to save player data:', e);
        }
    }
    
    /**
     * Set player name
     */
    setPlayerName(name) {
        this.playerName = name.slice(0, 20);
        this.savePlayerData();
        
        // Broadcast name change if connected
        if (this.isConnected) {
            this.sendMessage('name_change', { name: this.playerName });
        }
    }
    
    /**
     * Connect to server
     */
    connect() {
        if (this.mockMode) {
            return this.mockConnect();
        }
        
        return new Promise((resolve, reject) => {
            try {
                this.connectionState = 'connecting';
                
                this.socket = new WebSocket(this.serverUrl);
                
                this.socket.onopen = () => {
                    this.onConnected();
                    resolve();
                };
                
                this.socket.onclose = (event) => {
                    this.onDisconnected(event);
                };
                
                this.socket.onerror = (error) => {
                    this.onError(error);
                    reject(error);
                };
                
                this.socket.onmessage = (event) => {
                    this.onMessage(event);
                };
                
            } catch (e) {
                this.connectionState = 'error';
                reject(e);
            }
        });
    }
    
    /**
     * Mock connect for offline testing
     */
    mockConnect() {
        return new Promise((resolve) => {
            this.connectionState = 'connecting';
            
            setTimeout(() => {
                this.isConnected = true;
                this.connectionState = 'connected';
                
                if (this.callbacks.onConnect) {
                    this.callbacks.onConnect();
                }
                
                // Generate mock players
                this.generateMockPlayers();
                
                resolve();
            }, 500);
        });
    }
    
    /**
     * Generate mock players for testing
     */
    generateMockPlayers() {
        const names = ['SpeedDemon', 'GravityKing', 'NeonRacer', 'DriftMaster', 'TurboNinja'];
        const vehicles = ['racer', 'speeder', 'tank', 'drifter'];
        
        this.mockPlayers = names.map((name, index) => ({
            id: `mock_${index}`,
            name: name,
            vehicle: vehicles[index % vehicles.length],
            ready: Math.random() > 0.5,
            score: 0,
            position: { x: 200, y: 300 + index * 50 },
            rotation: 0,
            velocity: 0
        }));
    }
    
    /**
     * Disconnect from server
     */
    disconnect() {
        if (this.mockMode) {
            this.isConnected = false;
            this.connectionState = 'disconnected';
            this.currentRoom = null;
            this.roomPlayers = [];
            return;
        }
        
        if (this.socket) {
            this.socket.close();
        }
        
        this.stopHeartbeat();
        this.isConnected = false;
        this.connectionState = 'disconnected';
    }
    
    /**
     * Handle connected event
     */
    onConnected() {
        this.isConnected = true;
        this.connectionState = 'connected';
        this.reconnectAttempts = 0;
        
        // Start heartbeat
        this.startHeartbeat();
        
        // Send join message
        this.sendMessage('join', {
            playerId: this.playerId,
            name: this.playerName
        });
        
        if (this.callbacks.onConnect) {
            this.callbacks.onConnect();
        }
    }
    
    /**
     * Handle disconnected event
     */
    onDisconnected(event) {
        this.isConnected = false;
        this.connectionState = 'disconnected';
        
        this.stopHeartbeat();
        
        // Attempt reconnect
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            setTimeout(() => this.connect(), 2000 * this.reconnectAttempts);
        }
        
        if (this.callbacks.onDisconnect) {
            this.callbacks.onDisconnect(event);
        }
    }
    
    /**
     * Handle error event
     */
    onError(error) {
        console.error('Multiplayer error:', error);
        
        if (this.callbacks.onError) {
            this.callbacks.onError(error);
        }
    }
    
    /**
     * Handle incoming message
     */
    onMessage(event) {
        try {
            const message = JSON.parse(event.data);
            this.handleMessage(message);
        } catch (e) {
            console.error('Failed to parse message:', e);
        }
    }
    
    /**
     * Handle parsed message
     */
    handleMessage(message) {
        switch (message.type) {
            case 'room_joined':
                this.handleRoomJoined(message.data);
                break;
            case 'room_left':
                this.handleRoomLeft(message.data);
                break;
            case 'player_joined':
                this.handlePlayerJoined(message.data);
                break;
            case 'player_left':
                this.handlePlayerLeft(message.data);
                break;
            case 'player_update':
                this.handlePlayerUpdate(message.data);
                break;
            case 'game_start':
                this.handleGameStart(message.data);
                break;
            case 'game_end':
                this.handleGameEnd(message.data);
                break;
            case 'chat':
                this.handleChatMessage(message.data);
                break;
            case 'pong':
                this.handlePong(message.data);
                break;
            case 'error':
                this.handleServerError(message.data);
                break;
        }
    }
    
    /**
     * Send message to server
     */
    sendMessage(type, data) {
        if (this.mockMode) {
            return this.mockSendMessage(type, data);
        }
        
        if (!this.isConnected || !this.socket) return;
        
        const message = JSON.stringify({
            type: type,
            data: data,
            timestamp: Date.now()
        });
        
        this.socket.send(message);
    }
    
    /**
     * Mock send message
     */
    mockSendMessage(type, data) {
        // Simulate server responses
        switch (type) {
            case 'create_room':
                setTimeout(() => {
                    this.handleRoomJoined({
                        roomId: 'mock_room_' + Date.now(),
                        roomName: data.name,
                        isHost: true,
                        players: [{ id: this.playerId, name: this.playerName, ready: false }]
                    });
                }, 100);
                break;
                
            case 'join_room':
                setTimeout(() => {
                    const players = [
                        { id: this.playerId, name: this.playerName, ready: false },
                        ...this.mockPlayers.slice(0, 3)
                    ];
                    
                    this.handleRoomJoined({
                        roomId: data.roomId,
                        roomName: 'Test Room',
                        isHost: false,
                        players: players
                    });
                }, 100);
                break;
                
            case 'quick_match':
                setTimeout(() => {
                    const players = [
                        { id: this.playerId, name: this.playerName, ready: false },
                        ...this.mockPlayers.slice(0, Math.floor(Math.random() * 3) + 1)
                    ];
                    
                    this.handleRoomJoined({
                        roomId: 'quick_' + Date.now(),
                        roomName: 'Quick Match',
                        isHost: false,
                        players: players
                    });
                }, 500);
                break;
        }
    }
    
    /**
     * Create a room
     */
    createRoom(options = {}) {
        const roomData = {
            name: options.name || `${this.playerName}'s Room`,
            maxPlayers: options.maxPlayers || 4,
            level: options.level || 'level_1',
            gameMode: options.gameMode || 'race',
            isPrivate: options.isPrivate || false
        };
        
        this.sendMessage('create_room', roomData);
    }
    
    /**
     * Join a room by ID
     */
    joinRoom(roomId) {
        this.sendMessage('join_room', { roomId: roomId });
    }
    
    /**
     * Leave current room
     */
    leaveRoom() {
        if (this.currentRoom) {
            this.sendMessage('leave_room', { roomId: this.currentRoom.id });
            
            if (this.mockMode) {
                this.handleRoomLeft({});
            }
        }
    }
    
    /**
     * Quick match - join random room
     */
    quickMatch(options = {}) {
        const matchOptions = {
            gameMode: options.gameMode || 'race',
            level: options.level || 'any',
            skillRange: options.skillRange || 'any'
        };
        
        this.sendMessage('quick_match', matchOptions);
    }
    
    /**
     * Set ready status
     */
    setReady(ready) {
        this.sendMessage('ready', { ready: ready });
        
        if (this.mockMode) {
            // Update local player in room
            const localPlayer = this.roomPlayers.find(p => p.id === this.playerId);
            if (localPlayer) {
                localPlayer.ready = ready;
            }
        }
    }
    
    /**
     * Start game (host only)
     */
    startGame() {
        if (!this.isHost) return;
        
        this.sendMessage('start_game', { roomId: this.currentRoom?.id });
        
        if (this.mockMode) {
            setTimeout(() => {
                this.handleGameStart({
                    countdown: 3,
                    level: this.currentRoom?.level || 'level_1'
                });
            }, 100);
        }
    }
    
    /**
     * Send player update
     */
    sendPlayerUpdate(playerData) {
        this.localPlayerData = playerData;
        
        this.sendMessage('player_update', {
            position: playerData.position,
            rotation: playerData.rotation,
            velocity: playerData.velocity,
            boost: playerData.boost,
            powerups: playerData.powerups,
            score: playerData.score,
            distance: playerData.distance
        });
    }
    
    /**
     * Send chat message
     */
    sendChatMessage(text) {
        if (!text.trim()) return;
        
        this.sendMessage('chat', {
            text: text.slice(0, 200),
            playerId: this.playerId,
            playerName: this.playerName
        });
        
        if (this.mockMode && this.callbacks.onChatMessage) {
            this.callbacks.onChatMessage({
                playerId: this.playerId,
                playerName: this.playerName,
                text: text,
                timestamp: Date.now()
            });
        }
    }
    
    /**
     * Handle room joined
     */
    handleRoomJoined(data) {
        this.currentRoom = {
            id: data.roomId,
            name: data.roomName,
            level: data.level,
            gameMode: data.gameMode
        };
        
        this.isHost = data.isHost;
        this.roomPlayers = data.players || [];
        this.gameState = 'lobby';
        
        if (this.callbacks.onRoomJoin) {
            this.callbacks.onRoomJoin(this.currentRoom, this.roomPlayers);
        }
    }
    
    /**
     * Handle room left
     */
    handleRoomLeft(data) {
        this.currentRoom = null;
        this.isHost = false;
        this.roomPlayers = [];
        this.gameState = 'lobby';
        this.otherPlayers.clear();
        
        if (this.callbacks.onRoomLeave) {
            this.callbacks.onRoomLeave();
        }
    }
    
    /**
     * Handle player joined
     */
    handlePlayerJoined(data) {
        const player = {
            id: data.playerId,
            name: data.playerName,
            ready: false,
            vehicle: data.vehicle
        };
        
        this.roomPlayers.push(player);
        
        if (this.callbacks.onPlayerJoin) {
            this.callbacks.onPlayerJoin(player);
        }
    }
    
    /**
     * Handle player left
     */
    handlePlayerLeft(data) {
        const index = this.roomPlayers.findIndex(p => p.id === data.playerId);
        if (index !== -1) {
            const player = this.roomPlayers[index];
            this.roomPlayers.splice(index, 1);
            this.otherPlayers.delete(data.playerId);
            
            if (this.callbacks.onPlayerLeave) {
                this.callbacks.onPlayerLeave(player);
            }
        }
    }
    
    /**
     * Handle player update
     */
    handlePlayerUpdate(data) {
        const playerId = data.playerId;
        if (playerId === this.playerId) return; // Ignore own updates
        
        // Add to interpolation buffer
        if (!this.interpolationBuffer.has(playerId)) {
            this.interpolationBuffer.set(playerId, []);
        }
        
        const buffer = this.interpolationBuffer.get(playerId);
        buffer.push({
            timestamp: Date.now(),
            position: data.position,
            rotation: data.rotation,
            velocity: data.velocity,
            boost: data.boost,
            score: data.score
        });
        
        // Keep buffer limited
        while (buffer.length > 10) {
            buffer.shift();
        }
        
        // Store latest state
        this.otherPlayers.set(playerId, data);
        
        if (this.callbacks.onPlayerUpdate) {
            this.callbacks.onPlayerUpdate(playerId, data);
        }
    }
    
    /**
     * Handle game start
     */
    handleGameStart(data) {
        this.gameState = 'playing';
        
        if (this.callbacks.onGameStart) {
            this.callbacks.onGameStart(data);
        }
    }
    
    /**
     * Handle game end
     */
    handleGameEnd(data) {
        this.gameState = 'results';
        
        if (this.callbacks.onGameEnd) {
            this.callbacks.onGameEnd(data);
        }
    }
    
    /**
     * Handle chat message
     */
    handleChatMessage(data) {
        if (this.callbacks.onChatMessage) {
            this.callbacks.onChatMessage(data);
        }
    }
    
    /**
     * Handle pong response
     */
    handlePong(data) {
        this.ping = Date.now() - this.lastPing;
    }
    
    /**
     * Handle server error
     */
    handleServerError(data) {
        console.error('Server error:', data.message);
        
        if (this.callbacks.onError) {
            this.callbacks.onError(new Error(data.message));
        }
    }
    
    /**
     * Start heartbeat
     */
    startHeartbeat() {
        this.heartbeatInterval = setInterval(() => {
            this.lastPing = Date.now();
            this.sendMessage('ping', {});
        }, 5000);
    }
    
    /**
     * Stop heartbeat
     */
    stopHeartbeat() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
    }
    
    /**
     * Get interpolated position for a player
     */
    getInterpolatedPosition(playerId) {
        const buffer = this.interpolationBuffer.get(playerId);
        if (!buffer || buffer.length < 2) {
            const player = this.otherPlayers.get(playerId);
            return player?.position || null;
        }
        
        const renderTime = Date.now() - this.interpolationDelay;
        
        // Find two states to interpolate between
        let beforeState = null;
        let afterState = null;
        
        for (let i = 0; i < buffer.length - 1; i++) {
            if (buffer[i].timestamp <= renderTime && buffer[i + 1].timestamp >= renderTime) {
                beforeState = buffer[i];
                afterState = buffer[i + 1];
                break;
            }
        }
        
        if (!beforeState || !afterState) {
            return buffer[buffer.length - 1].position;
        }
        
        // Interpolate
        const timeDiff = afterState.timestamp - beforeState.timestamp;
        const t = timeDiff > 0 ? (renderTime - beforeState.timestamp) / timeDiff : 0;
        
        return {
            x: beforeState.position.x + (afterState.position.x - beforeState.position.x) * t,
            y: beforeState.position.y + (afterState.position.y - beforeState.position.y) * t
        };
    }
    
    /**
     * Get room list
     */
    getRoomList() {
        if (this.mockMode) {
            return this.generateMockRoomList();
        }
        
        return new Promise((resolve) => {
            this.sendMessage('get_rooms', {});
            // In real implementation, wait for response
            resolve([]);
        });
    }
    
    /**
     * Generate mock room list
     */
    generateMockRoomList() {
        return [
            {
                id: 'room_1',
                name: 'SpeedDemon\'s Room',
                host: 'SpeedDemon',
                players: 2,
                maxPlayers: 4,
                level: 'level_1',
                gameMode: 'race',
                isPrivate: false
            },
            {
                id: 'room_2',
                name: 'Pro Racing',
                host: 'GravityKing',
                players: 3,
                maxPlayers: 4,
                level: 'level_5',
                gameMode: 'race',
                isPrivate: false
            },
            {
                id: 'room_3',
                name: 'Casual Fun',
                host: 'NeonRacer',
                players: 1,
                maxPlayers: 4,
                level: 'level_2',
                gameMode: 'race',
                isPrivate: false
            }
        ];
    }
    
    /**
     * Get current ping
     */
    getPing() {
        return this.ping;
    }
    
    /**
     * Get connection state
     */
    getConnectionState() {
        return this.connectionState;
    }
    
    /**
     * Check if in a room
     */
    isInRoom() {
        return this.currentRoom !== null;
    }
    
    /**
     * Get current room
     */
    getCurrentRoom() {
        return this.currentRoom;
    }
    
    /**
     * Get room players
     */
    getRoomPlayers() {
        return [...this.roomPlayers];
    }
    
    /**
     * Check if player is host
     */
    isRoomHost() {
        return this.isHost;
    }
    
    /**
     * Get game state
     */
    getGameState() {
        return this.gameState;
    }
    
    /**
     * Set callback
     */
    on(event, callback) {
        if (this.callbacks.hasOwnProperty(event)) {
            this.callbacks[event] = callback;
        }
    }
    
    /**
     * Remove callback
     */
    off(event) {
        if (this.callbacks.hasOwnProperty(event)) {
            this.callbacks[event] = null;
        }
    }
    
    /**
     * Update (call each frame for mock mode)
     */
    update(delta) {
        if (this.mockMode && this.gameState === 'playing') {
            // Update mock players
            this.mockPlayers.forEach(player => {
                // Simulate movement
                player.position.y -= 2;
                if (player.position.y < 100) {
                    player.position.y = 500;
                }
                player.score += Math.floor(delta * 10);
                player.rotation = Math.sin(Date.now() * 0.001) * 10;
                
                this.otherPlayers.set(player.id, { ...player });
            });
        }
    }
    
    /**
     * Destroy and clean up
     */
    destroy() {
        this.disconnect();
        this.callbacks = {};
    }
}

// Create singleton
if (typeof window !== 'undefined') {
    window.MultiplayerManager = new MultiplayerManager();
}
