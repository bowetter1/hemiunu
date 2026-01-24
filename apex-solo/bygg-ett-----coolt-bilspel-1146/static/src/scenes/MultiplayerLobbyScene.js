/**
 * MultiplayerLobbyScene.js
 * Multiplayer lobby for joining/creating rooms and matchmaking
 */

class MultiplayerLobbyScene extends Phaser.Scene {
    constructor() {
        super({ key: 'MultiplayerLobbyScene' });
        
        // UI state
        this.currentTab = 'browse';
        this.tabs = ['browse', 'create', 'quick'];
        this.selectedRoom = null;
        this.roomList = [];
        this.scrollOffset = 0;
        this.maxScroll = 0;
        
        // Connection state
        this.isConnecting = false;
        this.isConnected = false;
        
        // Chat
        this.chatMessages = [];
        this.maxChatMessages = 50;
    }
    
    /**
     * Initialize scene
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
    }
    
    /**
     * Create scene
     */
    create() {
        const { width, height } = this.cameras.main;
        
        // Background
        this.createBackground(width, height);
        
        // Header
        this.createHeader(width);
        
        // Connection status
        this.createConnectionStatus(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Content area
        this.contentContainer = this.add.container(0, 150);
        
        // Initial connection
        this.connectToServer();
        
        // Back button
        this.createBackButton(width, height);
        
        // Input
        this.setupInput();
        
        // Animation
        this.animateIn();
    }
    
    /**
     * Create background
     */
    createBackground(width, height) {
        const graphics = this.add.graphics();
        
        for (let y = 0; y < height; y++) {
            const t = y / height;
            const r = Math.floor(10 + t * 10);
            const g = Math.floor(15 + t * 15);
            const b = Math.floor(35 + t * 20);
            graphics.fillStyle(Phaser.Display.Color.GetColor(r, g, b), 1);
            graphics.fillRect(0, y, width, 1);
        }
        
        // Network grid effect
        graphics.lineStyle(1, 0x00ffff, 0.05);
        for (let x = 0; x < width; x += 30) {
            graphics.lineBetween(x, 0, x, height);
        }
        for (let y = 0; y < height; y += 30) {
            graphics.lineBetween(0, y, width, y);
        }
    }
    
    /**
     * Create header
     */
    createHeader(width) {
        const headerBg = this.add.graphics();
        headerBg.fillStyle(0x0a1020, 0.95);
        headerBg.fillRect(0, 0, width, 70);
        headerBg.lineStyle(2, 0x00ffff, 0.5);
        headerBg.lineBetween(0, 70, width, 70);
        
        // Multiplayer icon
        const icon = this.add.graphics();
        icon.fillStyle(0x00ffff, 0.8);
        icon.fillCircle(35, 35, 8);
        icon.fillCircle(55, 25, 6);
        icon.fillCircle(55, 45, 6);
        icon.lineStyle(2, 0x00ffff, 0.6);
        icon.lineBetween(35, 35, 55, 25);
        icon.lineBetween(35, 35, 55, 45);
        
        this.add.text(75, 35, 'MULTIPLAYER', {
            fontFamily: 'Arial Black',
            fontSize: '26px',
            color: '#00ffff',
            stroke: '#004455',
            strokeThickness: 3
        }).setOrigin(0, 0.5);
    }
    
    /**
     * Create connection status
     */
    createConnectionStatus(width) {
        this.statusContainer = this.add.container(width - 20, 35);
        
        this.statusDot = this.add.graphics();
        this.statusDot.fillStyle(0xff4444, 1);
        this.statusDot.fillCircle(-60, 0, 6);
        this.statusContainer.add(this.statusDot);
        
        this.statusText = this.add.text(-50, 0, 'Disconnected', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ff4444'
        }).setOrigin(0, 0.5);
        this.statusContainer.add(this.statusText);
        
        this.pingText = this.add.text(0, 0, '', {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        }).setOrigin(1, 0.5);
        this.statusContainer.add(this.pingText);
    }
    
    /**
     * Update connection status display
     */
    updateConnectionStatus(status, ping = 0) {
        this.statusDot.clear();
        
        switch (status) {
            case 'connected':
                this.statusDot.fillStyle(0x00ff88, 1);
                this.statusText.setText('Connected');
                this.statusText.setColor('#00ff88');
                this.pingText.setText(`${ping}ms`);
                break;
            case 'connecting':
                this.statusDot.fillStyle(0xffaa00, 1);
                this.statusText.setText('Connecting...');
                this.statusText.setColor('#ffaa00');
                this.pingText.setText('');
                break;
            case 'disconnected':
            default:
                this.statusDot.fillStyle(0xff4444, 1);
                this.statusText.setText('Disconnected');
                this.statusText.setColor('#ff4444');
                this.pingText.setText('');
                break;
        }
        
        this.statusDot.fillCircle(-60, 0, 6);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabY = 85;
        const tabWidth = width / this.tabs.length;
        
        this.tabElements = [];
        
        const tabLabels = {
            browse: 'BROWSE ROOMS',
            create: 'CREATE ROOM',
            quick: 'QUICK MATCH'
        };
        
        this.tabs.forEach((tab, index) => {
            const x = index * tabWidth;
            const active = tab === this.currentTab;
            
            const bg = this.add.graphics();
            this.drawTabBg(bg, x, tabY, tabWidth, 40, active);
            
            const text = this.add.text(x + tabWidth / 2, tabY + 20, tabLabels[tab], {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#00ffff' : '#667788'
            }).setOrigin(0.5);
            
            const zone = this.add.zone(x + tabWidth / 2, tabY + 20, tabWidth, 40)
                .setInteractive({ useHandCursor: true });
            
            zone.on('pointerdown', () => this.selectTab(tab));
            
            this.tabElements.push({ bg, text, tab });
        });
    }
    
    /**
     * Draw tab background
     */
    drawTabBg(graphics, x, y, width, height, active) {
        graphics.clear();
        
        if (active) {
            graphics.fillStyle(0x0a2535, 1);
            graphics.lineStyle(2, 0x00ffff, 0.8);
        } else {
            graphics.fillStyle(0x0a1525, 0.8);
            graphics.lineStyle(1, 0x334455, 0.5);
        }
        
        graphics.fillRect(x + 2, y, width - 4, height);
        graphics.strokeRect(x + 2, y, width - 4, height);
    }
    
    /**
     * Select a tab
     */
    selectTab(tab) {
        if (tab === this.currentTab) return;
        
        this.currentTab = tab;
        this.scrollOffset = 0;
        
        const width = this.cameras.main.width;
        const tabWidth = width / this.tabs.length;
        
        this.tabElements.forEach((elem, index) => {
            const active = elem.tab === tab;
            this.drawTabBg(elem.bg, index * tabWidth, 85, tabWidth, 40, active);
            elem.text.setColor(active ? '#00ffff' : '#667788');
        });
        
        this.renderTabContent();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Connect to multiplayer server
     */
    async connectToServer() {
        this.isConnecting = true;
        this.updateConnectionStatus('connecting');
        
        try {
            if (window.MultiplayerManager) {
                // Setup callbacks
                MultiplayerManager.on('onConnect', () => {
                    this.isConnected = true;
                    this.isConnecting = false;
                    this.updateConnectionStatus('connected');
                    this.loadRoomList();
                    this.renderTabContent();
                });
                
                MultiplayerManager.on('onDisconnect', () => {
                    this.isConnected = false;
                    this.updateConnectionStatus('disconnected');
                });
                
                MultiplayerManager.on('onRoomJoin', (room, players) => {
                    this.scene.start('MultiplayerRoomScene', { room, players });
                });
                
                MultiplayerManager.on('onError', (error) => {
                    this.showError(error.message);
                });
                
                await MultiplayerManager.connect();
            } else {
                // Mock connection
                setTimeout(() => {
                    this.isConnected = true;
                    this.isConnecting = false;
                    this.updateConnectionStatus('connected', 45);
                    this.loadRoomList();
                    this.renderTabContent();
                }, 1000);
            }
        } catch (error) {
            this.isConnecting = false;
            this.updateConnectionStatus('disconnected');
            this.showError('Failed to connect');
        }
    }
    
    /**
     * Load room list
     */
    async loadRoomList() {
        if (window.MultiplayerManager) {
            this.roomList = await MultiplayerManager.getRoomList();
        } else {
            // Mock room list
            this.roomList = [
                { id: '1', name: 'SpeedDemon\'s Room', host: 'SpeedDemon', players: 2, maxPlayers: 4, level: 'Level 1' },
                { id: '2', name: 'Pro Racing', host: 'GravityKing', players: 3, maxPlayers: 4, level: 'Level 5' },
                { id: '3', name: 'Casual Fun', host: 'NeonRacer', players: 1, maxPlayers: 4, level: 'Level 2' },
                { id: '4', name: 'Newbies Welcome', host: 'TurboNinja', players: 2, maxPlayers: 6, level: 'Level 1' }
            ];
        }
        
        this.renderTabContent();
    }
    
    /**
     * Render current tab content
     */
    renderTabContent() {
        this.contentContainer.removeAll(true);
        
        const { width, height } = this.cameras.main;
        
        switch (this.currentTab) {
            case 'browse':
                this.renderBrowseTab(width, height);
                break;
            case 'create':
                this.renderCreateTab(width, height);
                break;
            case 'quick':
                this.renderQuickMatchTab(width, height);
                break;
        }
    }
    
    /**
     * Render browse rooms tab
     */
    renderBrowseTab(width, height) {
        if (!this.isConnected) {
            this.renderDisconnectedMessage(width);
            return;
        }
        
        if (this.roomList.length === 0) {
            const noRooms = this.add.text(width / 2, 100, 'No rooms available', {
                fontFamily: 'Arial',
                fontSize: '16px',
                color: '#667788'
            }).setOrigin(0.5);
            this.contentContainer.add(noRooms);
            
            const createBtn = this.add.text(width / 2, 140, 'Create a Room', {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#00ffff',
                backgroundColor: '#1a3050',
                padding: { x: 20, y: 10 }
            }).setOrigin(0.5).setInteractive({ useHandCursor: true });
            
            createBtn.on('pointerdown', () => this.selectTab('create'));
            this.contentContainer.add(createBtn);
            return;
        }
        
        // Refresh button
        const refreshBtn = this.add.text(width - 30, 5, '↻', {
            fontSize: '24px',
            color: '#00ffff'
        }).setOrigin(1, 0).setInteractive({ useHandCursor: true });
        
        refreshBtn.on('pointerdown', () => {
            this.loadRoomList();
            if (window.SoundManager) SoundManager.play('ui_click');
        });
        
        this.contentContainer.add(refreshBtn);
        
        // Room list
        const itemHeight = 80;
        
        this.roomList.forEach((room, index) => {
            const y = 10 + index * (itemHeight + 10);
            const roomItem = this.createRoomListItem(room, y, width - 40, itemHeight);
            this.contentContainer.add(roomItem);
        });
        
        this.maxScroll = Math.max(0, this.roomList.length * (itemHeight + 10) - (height - 250));
    }
    
    /**
     * Create room list item
     */
    createRoomListItem(room, y, width, height) {
        const container = this.add.container(20, y);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x0a1525, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 8);
        bg.lineStyle(2, 0x334455, 0.5);
        bg.strokeRoundedRect(0, 0, width, height, 8);
        container.add(bg);
        
        // Room name
        const name = this.add.text(15, 15, room.name, {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: '#ffffff'
        });
        container.add(name);
        
        // Host
        const host = this.add.text(15, 40, `Host: ${room.host}`, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        container.add(host);
        
        // Level
        const level = this.add.text(150, 40, room.level, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#00ffff'
        });
        container.add(level);
        
        // Player count
        const playerColor = room.players >= room.maxPlayers ? '#ff4444' : '#00ff88';
        const players = this.add.text(width - 100, 25, `${room.players}/${room.maxPlayers}`, {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: playerColor
        }).setOrigin(0, 0.5);
        container.add(players);
        
        // Player icon
        const playerIcon = this.add.text(width - 115, 25, '👤', {
            fontSize: '16px'
        }).setOrigin(1, 0.5);
        container.add(playerIcon);
        
        // Join button
        if (room.players < room.maxPlayers) {
            const joinBtn = this.add.text(width - 15, 40, 'JOIN', {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#00ffff',
                backgroundColor: '#1a3050',
                padding: { x: 15, y: 5 }
            }).setOrigin(1, 0.5).setInteractive({ useHandCursor: true });
            
            joinBtn.on('pointerdown', () => this.joinRoom(room));
            container.add(joinBtn);
        }
        
        // Interactive background
        const zone = this.add.zone(width / 2, height / 2, width, height)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerover', () => {
            bg.clear();
            bg.fillStyle(0x1a2535, 0.95);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, 0x00ffff, 0.5);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        
        zone.on('pointerout', () => {
            bg.clear();
            bg.fillStyle(0x0a1525, 0.9);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, 0x334455, 0.5);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        
        container.add(zone);
        
        return container;
    }
    
    /**
     * Render create room tab
     */
    renderCreateTab(width, height) {
        if (!this.isConnected) {
            this.renderDisconnectedMessage(width);
            return;
        }
        
        // Room name input
        const nameLabel = this.add.text(20, 20, 'ROOM NAME', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.contentContainer.add(nameLabel);
        
        const nameInputBg = this.add.graphics();
        nameInputBg.fillStyle(0x1a2535, 1);
        nameInputBg.fillRoundedRect(20, 40, width - 40, 40, 5);
        nameInputBg.lineStyle(2, 0x334455, 0.8);
        nameInputBg.strokeRoundedRect(20, 40, width - 40, 40, 5);
        this.contentContainer.add(nameInputBg);
        
        this.roomNameText = this.add.text(30, 60, 'My Room', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(this.roomNameText);
        
        // Max players
        const maxLabel = this.add.text(20, 100, 'MAX PLAYERS', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.contentContainer.add(maxLabel);
        
        this.maxPlayers = 4;
        const maxOptions = [2, 4, 6, 8];
        
        maxOptions.forEach((num, index) => {
            const x = 20 + index * 60;
            const active = num === this.maxPlayers;
            
            const btn = this.add.text(x, 125, String(num), {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: active ? '#00ffff' : '#667788',
                backgroundColor: active ? '#1a3050' : 'transparent',
                padding: { x: 15, y: 8 }
            }).setInteractive({ useHandCursor: true });
            
            btn.on('pointerdown', () => {
                this.maxPlayers = num;
                this.renderTabContent();
            });
            
            this.contentContainer.add(btn);
        });
        
        // Level selection
        const levelLabel = this.add.text(20, 170, 'LEVEL', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.contentContainer.add(levelLabel);
        
        this.selectedLevel = 'level_1';
        const levels = ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5'];
        
        levels.forEach((lvl, index) => {
            const x = 20 + (index % 3) * 100;
            const y = 195 + Math.floor(index / 3) * 35;
            const active = this.selectedLevel === `level_${index + 1}`;
            
            const btn = this.add.text(x, y, lvl, {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#00ffff' : '#667788',
                backgroundColor: active ? '#1a3050' : 'transparent',
                padding: { x: 10, y: 5 }
            }).setInteractive({ useHandCursor: true });
            
            btn.on('pointerdown', () => {
                this.selectedLevel = `level_${index + 1}`;
                this.renderTabContent();
            });
            
            this.contentContainer.add(btn);
        });
        
        // Private toggle
        const privateLabel = this.add.text(20, 280, 'PRIVATE ROOM', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.contentContainer.add(privateLabel);
        
        this.isPrivate = false;
        const toggleBg = this.add.graphics();
        toggleBg.fillStyle(this.isPrivate ? 0x00ffff : 0x334455, 1);
        toggleBg.fillRoundedRect(130, 277, 50, 24, 12);
        this.contentContainer.add(toggleBg);
        
        const toggleKnob = this.add.graphics();
        toggleKnob.fillStyle(0xffffff, 1);
        toggleKnob.fillCircle(this.isPrivate ? 168 : 142, 289, 10);
        this.contentContainer.add(toggleKnob);
        
        const toggleZone = this.add.zone(155, 289, 50, 24)
            .setInteractive({ useHandCursor: true });
        
        toggleZone.on('pointerdown', () => {
            this.isPrivate = !this.isPrivate;
            this.renderTabContent();
        });
        this.contentContainer.add(toggleZone);
        
        // Create button
        const createBtn = this.add.text(width / 2, 350, 'CREATE ROOM', {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: '#ffffff',
            backgroundColor: '#00aaff',
            padding: { x: 40, y: 15 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        createBtn.on('pointerdown', () => this.createRoom());
        createBtn.on('pointerover', () => createBtn.setAlpha(0.8));
        createBtn.on('pointerout', () => createBtn.setAlpha(1));
        
        this.contentContainer.add(createBtn);
    }
    
    /**
     * Render quick match tab
     */
    renderQuickMatchTab(width, height) {
        if (!this.isConnected) {
            this.renderDisconnectedMessage(width);
            return;
        }
        
        // Quick match icon
        const iconBg = this.add.graphics();
        iconBg.fillStyle(0x1a3050, 0.8);
        iconBg.fillCircle(width / 2, 100, 60);
        iconBg.lineStyle(3, 0x00ffff, 0.8);
        iconBg.strokeCircle(width / 2, 100, 60);
        this.contentContainer.add(iconBg);
        
        const icon = this.add.text(width / 2, 100, '⚡', {
            fontSize: '48px'
        }).setOrigin(0.5);
        this.contentContainer.add(icon);
        
        // Description
        const title = this.add.text(width / 2, 185, 'QUICK MATCH', {
            fontFamily: 'Arial Black',
            fontSize: '24px',
            color: '#00ffff'
        }).setOrigin(0.5);
        this.contentContainer.add(title);
        
        const desc = this.add.text(width / 2, 220, 'Instantly join a random game', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#aabbcc'
        }).setOrigin(0.5);
        this.contentContainer.add(desc);
        
        // Quick match button
        const quickBtn = this.add.text(width / 2, 280, 'FIND MATCH', {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#ffffff',
            backgroundColor: '#00aa44',
            padding: { x: 50, y: 18 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        quickBtn.on('pointerdown', () => this.quickMatch());
        quickBtn.on('pointerover', () => quickBtn.setAlpha(0.8));
        quickBtn.on('pointerout', () => quickBtn.setAlpha(1));
        
        this.contentContainer.add(quickBtn);
        
        // Options
        const optLabel = this.add.text(width / 2, 340, 'or customize:', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        }).setOrigin(0.5);
        this.contentContainer.add(optLabel);
        
        // Level preference
        this.quickMatchLevel = 'any';
        const levelOpts = ['Any Level', 'Easy', 'Medium', 'Hard'];
        
        levelOpts.forEach((opt, index) => {
            const x = 20 + (index % 2) * (width / 2 - 10);
            const y = 365 + Math.floor(index / 2) * 35;
            const active = (index === 0 && this.quickMatchLevel === 'any') ||
                           (index === 1 && this.quickMatchLevel === 'easy') ||
                           (index === 2 && this.quickMatchLevel === 'medium') ||
                           (index === 3 && this.quickMatchLevel === 'hard');
            
            const btn = this.add.text(x + (width / 2 - 10) / 2, y, opt, {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#00ffff' : '#667788',
                backgroundColor: active ? '#1a3050' : 'transparent',
                padding: { x: 15, y: 8 }
            }).setOrigin(0.5).setInteractive({ useHandCursor: true });
            
            btn.on('pointerdown', () => {
                this.quickMatchLevel = ['any', 'easy', 'medium', 'hard'][index];
                this.renderTabContent();
            });
            
            this.contentContainer.add(btn);
        });
    }
    
    /**
     * Render disconnected message
     */
    renderDisconnectedMessage(width) {
        const msg = this.add.text(width / 2, 100, 'Not connected to server', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#ff4444'
        }).setOrigin(0.5);
        this.contentContainer.add(msg);
        
        const retryBtn = this.add.text(width / 2, 150, 'Retry Connection', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff',
            backgroundColor: '#1a3050',
            padding: { x: 20, y: 10 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        retryBtn.on('pointerdown', () => this.connectToServer());
        this.contentContainer.add(retryBtn);
    }
    
    /**
     * Join a room
     */
    joinRoom(room) {
        if (window.MultiplayerManager) {
            MultiplayerManager.joinRoom(room.id);
        } else {
            // Mock join
            this.scene.start('MultiplayerRoomScene', {
                room: room,
                players: [
                    { id: 'local', name: 'You', ready: false },
                    { id: 'mock1', name: room.host, ready: true }
                ]
            });
        }
        
        if (window.SoundManager) {
            SoundManager.play('ui_confirm');
        }
    }
    
    /**
     * Create a room
     */
    createRoom() {
        const roomName = this.roomNameText?.text || 'My Room';
        
        if (window.MultiplayerManager) {
            MultiplayerManager.createRoom({
                name: roomName,
                maxPlayers: this.maxPlayers,
                level: this.selectedLevel,
                isPrivate: this.isPrivate
            });
        } else {
            // Mock create
            this.scene.start('MultiplayerRoomScene', {
                room: {
                    id: 'new_room',
                    name: roomName,
                    maxPlayers: this.maxPlayers,
                    level: this.selectedLevel
                },
                players: [
                    { id: 'local', name: 'You', ready: false }
                ],
                isHost: true
            });
        }
        
        if (window.SoundManager) {
            SoundManager.play('ui_confirm');
        }
    }
    
    /**
     * Start quick match
     */
    quickMatch() {
        if (window.MultiplayerManager) {
            MultiplayerManager.quickMatch({
                level: this.quickMatchLevel
            });
        } else {
            // Show searching animation then mock join
            this.showSearchingOverlay();
        }
        
        if (window.SoundManager) {
            SoundManager.play('ui_confirm');
        }
    }
    
    /**
     * Show searching overlay
     */
    showSearchingOverlay() {
        const { width, height } = this.cameras.main;
        
        const overlay = this.add.graphics();
        overlay.fillStyle(0x000000, 0.8);
        overlay.fillRect(0, 0, width, height);
        overlay.setDepth(100);
        
        const searchText = this.add.text(width / 2, height / 2 - 20, 'Searching for match...', {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: '#00ffff'
        }).setOrigin(0.5).setDepth(101);
        
        // Spinner animation
        const spinner = this.add.graphics();
        spinner.setDepth(101);
        
        let angle = 0;
        const spinnerUpdate = this.time.addEvent({
            delay: 50,
            callback: () => {
                angle += 0.2;
                spinner.clear();
                spinner.lineStyle(4, 0x00ffff, 0.8);
                spinner.arc(width / 2, height / 2 + 40, 20, angle, angle + Math.PI * 1.5);
                spinner.strokePath();
            },
            loop: true
        });
        
        // Mock match found after delay
        this.time.delayedCall(2000, () => {
            spinnerUpdate.remove();
            overlay.destroy();
            searchText.destroy();
            spinner.destroy();
            
            this.scene.start('MultiplayerRoomScene', {
                room: {
                    id: 'quick_match',
                    name: 'Quick Match',
                    maxPlayers: 4,
                    level: 'level_1'
                },
                players: [
                    { id: 'local', name: 'You', ready: false },
                    { id: 'mock1', name: 'SpeedDemon', ready: true },
                    { id: 'mock2', name: 'NeonRacer', ready: false }
                ]
            });
        });
    }
    
    /**
     * Show error message
     */
    showError(message) {
        const { width, height } = this.cameras.main;
        
        const errorText = this.add.text(width / 2, height - 100, message, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ff4444',
            backgroundColor: '#330000',
            padding: { x: 20, y: 10 }
        }).setOrigin(0.5).setDepth(200);
        
        this.tweens.add({
            targets: errorText,
            alpha: 0,
            duration: 3000,
            delay: 2000,
            onComplete: () => errorText.destroy()
        });
    }
    
    /**
     * Create back button
     */
    createBackButton(width, height) {
        const container = this.add.container(width - 80, height - 50);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x1a2535, 0.9);
        bg.fillRoundedRect(0, 0, 60, 35, 5);
        bg.lineStyle(2, 0x00ffff, 0.5);
        bg.strokeRoundedRect(0, 0, 60, 35, 5);
        
        const text = this.add.text(30, 17, 'BACK', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#00ffff'
        }).setOrigin(0.5);
        
        const zone = this.add.zone(30, 17, 60, 35)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.goBack());
        
        container.add([bg, text, zone]);
    }
    
    /**
     * Setup input
     */
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            this.scrollOffset = Phaser.Math.Clamp(
                this.scrollOffset + deltaY * 0.5,
                0,
                this.maxScroll
            );
            this.contentContainer.y = 150 - this.scrollOffset;
        });
    }
    
    /**
     * Go back
     */
    goBack() {
        if (window.MultiplayerManager) {
            MultiplayerManager.disconnect();
        }
        
        if (window.SoundManager) {
            SoundManager.play('ui_back');
        }
        
        this.scene.start(this.returnScene);
    }
    
    /**
     * Animate scene in
     */
    animateIn() {
        this.cameras.main.setAlpha(0);
        this.tweens.add({
            targets: this.cameras.main,
            alpha: 1,
            duration: 300,
            ease: 'Power2'
        });
    }
    
    /**
     * Update
     */
    update(time, delta) {
        // Update ping display
        if (this.isConnected && window.MultiplayerManager) {
            const ping = MultiplayerManager.getPing();
            this.pingText.setText(`${ping}ms`);
        }
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.MultiplayerLobbyScene = MultiplayerLobbyScene;
}
