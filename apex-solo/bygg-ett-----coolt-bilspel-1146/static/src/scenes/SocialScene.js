/**
 * SocialScene.js
 * Social hub scene for friends, parties, and activity feed
 * Part of GRAVSHIFT - A gravity-defying racing game
 */

class SocialScene extends Phaser.Scene {
    constructor() {
        super({ key: 'SocialScene' });
        
        // Scene state
        this.selectedTab = 'friends';
        this.socialManager = null;
        
        // UI elements
        this.container = null;
        this.tabButtons = [];
        this.contentContainer = null;
        
        // Search state
        this.searchText = '';
        this.searchResults = [];
        
        // Selected items
        this.selectedFriend = null;
        this.selectedRequest = null;
        
        // Animation
        this.animationTimer = 0;
        this.particles = [];
        
        // Colors
        this.colors = {
            background: 0x0a0a1a,
            panel: 0x1a1a3a,
            panelLight: 0x2a2a4a,
            accent: 0x00ffaa,
            accentAlt: 0xff6600,
            online: 0x00ff00,
            inGame: 0x00aaff,
            away: 0xffaa00,
            offline: 0x666666,
            text: 0xffffff,
            textDim: 0x888899,
            success: 0x00ff00,
            error: 0xff4444
        };
    }
    
    /**
     * Initialize scene
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
        this.preSelectedTab = data.tab || 'friends';
    }
    
    /**
     * Create scene elements
     */
    create() {
        const width = this.cameras.main.width;
        const height = this.cameras.main.height;
        
        // Initialize social manager if not exists
        if (!this.socialManager) {
            this.socialManager = new SocialManager(this);
        }
        
        // Background
        this.createBackground(width, height);
        
        // Main container
        this.container = this.add.container(0, 0);
        
        // Title
        this.createTitle(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Online friends indicator
        this.createOnlineIndicator(width);
        
        // Content area
        this.createContentArea(width, height);
        
        // Back button
        this.createBackButton();
        
        // Select initial tab
        this.selectTab(this.preSelectedTab);
        
        // Input handlers
        this.setupInput();
        
        // Fade in
        this.cameras.main.fadeIn(300);
    }
    
    /**
     * Create animated background
     */
    createBackground(width, height) {
        // Gradient background
        const bg = this.add.graphics();
        bg.fillGradientStyle(
            this.colors.background, this.colors.background,
            0x050510, 0x050510
        );
        bg.fillRect(0, 0, width, height);
        
        // Particles
        for (let i = 0; i < 30; i++) {
            this.particles.push({
                x: Math.random() * width,
                y: Math.random() * height,
                size: Math.random() * 2 + 1,
                speed: Math.random() * 0.2 + 0.1,
                alpha: Math.random() * 0.3 + 0.1,
                color: Math.random() > 0.5 ? this.colors.accent : 0x66aaff
            });
        }
        
        this.particleGraphics = this.add.graphics();
        
        // Connection lines pattern
        const pattern = this.add.graphics();
        pattern.lineStyle(1, 0x333355, 0.1);
        
        const points = [];
        for (let i = 0; i < 15; i++) {
            points.push({
                x: Math.random() * width,
                y: Math.random() * height
            });
        }
        
        points.forEach((p1, i) => {
            points.forEach((p2, j) => {
                if (i < j) {
                    const dist = Math.sqrt(Math.pow(p2.x - p1.x, 2) + Math.pow(p2.y - p1.y, 2));
                    if (dist < 200) {
                        pattern.lineBetween(p1.x, p1.y, p2.x, p2.y);
                    }
                }
            });
        });
    }
    
    /**
     * Create scene title
     */
    createTitle(width) {
        // Title background
        const titleBg = this.add.graphics();
        titleBg.fillStyle(this.colors.panel, 0.8);
        titleBg.fillRect(0, 0, width, 80);
        titleBg.lineStyle(2, this.colors.accent, 0.5);
        titleBg.lineBetween(0, 80, width, 80);
        this.container.add(titleBg);
        
        // Icon
        const icon = this.add.text(30, 40, '🌐', {
            fontSize: '36px'
        }).setOrigin(0, 0.5);
        this.container.add(icon);
        
        // Title text
        const title = this.add.text(80, 30, 'SOCIAL HUB', {
            fontSize: '32px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.container.add(title);
        
        // Subtitle
        const subtitle = this.add.text(80, 55, 'Connect with friends and compete', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.container.add(subtitle);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabs = [
            { key: 'friends', label: 'FRIENDS', icon: '👥' },
            { key: 'requests', label: 'REQUESTS', icon: '📨', badge: true },
            { key: 'party', label: 'PARTY', icon: '🎉' },
            { key: 'activity', label: 'ACTIVITY', icon: '📰' },
            { key: 'search', label: 'SEARCH', icon: '🔍' }
        ];
        
        const tabWidth = (width - 40) / tabs.length;
        const y = 90;
        
        this.tabContainer = this.add.container(0, y);
        
        tabs.forEach((tab, index) => {
            const x = 20 + index * tabWidth;
            
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, 0, tabWidth - 5, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
            this.tabContainer.add(bg);
            
            const text = this.add.text(x + tabWidth / 2, 20, `${tab.icon} ${tab.label}`, {
                fontSize: '11px',
                fontFamily: 'Arial',
                color: '#888899'
            }).setOrigin(0.5, 0.5);
            this.tabContainer.add(text);
            
            // Badge for requests
            if (tab.badge) {
                const count = this.socialManager.getPendingRequestCount();
                if (count > 0) {
                    const badge = this.add.graphics();
                    badge.fillStyle(this.colors.error, 1);
                    badge.fillCircle(x + tabWidth - 25, 12, 10);
                    this.tabContainer.add(badge);
                    
                    const badgeText = this.add.text(x + tabWidth - 25, 12, count.toString(), {
                        fontSize: '10px',
                        fontFamily: 'Arial Black',
                        color: '#ffffff'
                    }).setOrigin(0.5, 0.5);
                    this.tabContainer.add(badgeText);
                }
            }
            
            const zone = this.add.zone(x + tabWidth / 2, 20, tabWidth - 5, 40)
                .setInteractive({ useHandCursor: true })
                .on('pointerover', () => {
                    if (this.selectedTab !== tab.key) {
                        bg.clear();
                        bg.fillStyle(this.colors.panelLight, 0.8);
                        bg.fillRoundedRect(x, 0, tabWidth - 5, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
                    }
                })
                .on('pointerout', () => {
                    if (this.selectedTab !== tab.key) {
                        bg.clear();
                        bg.fillStyle(this.colors.panelLight, 0.5);
                        bg.fillRoundedRect(x, 0, tabWidth - 5, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
                    }
                })
                .on('pointerdown', () => {
                    this.selectTab(tab.key);
                });
            
            this.tabButtons.push({
                key: tab.key,
                bg,
                text,
                zone,
                x,
                width: tabWidth - 5
            });
        });
        
        this.container.add(this.tabContainer);
    }
    
    /**
     * Select a tab
     */
    selectTab(key) {
        this.selectedTab = key;
        
        this.tabButtons.forEach(tab => {
            const isSelected = tab.key === key;
            
            tab.bg.clear();
            tab.bg.fillStyle(isSelected ? this.colors.panel : this.colors.panelLight, isSelected ? 1 : 0.5);
            tab.bg.fillRoundedRect(tab.x, 0, tab.width, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
            
            if (isSelected) {
                tab.bg.lineStyle(2, this.colors.accent, 1);
                tab.bg.lineBetween(tab.x, 40, tab.x + tab.width, 40);
            }
            
            tab.text.setColor(isSelected ? '#ffffff' : '#888899');
        });
        
        this.showContent(key);
        this.playTabSound();
    }
    
    /**
     * Create online indicator
     */
    createOnlineIndicator(width) {
        this.onlineContainer = this.add.container(width - 30, 55);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panelLight, 0.8);
        bg.fillRoundedRect(-130, -20, 130, 40, 20);
        this.onlineContainer.add(bg);
        
        // Online dot
        const dot = this.add.graphics();
        dot.fillStyle(this.colors.online, 1);
        dot.fillCircle(-115, 0, 6);
        this.onlineContainer.add(dot);
        
        // Pulse animation
        this.tweens.add({
            targets: dot,
            alpha: 0.3,
            duration: 1000,
            yoyo: true,
            repeat: -1
        });
        
        // Text
        const onlineCount = this.socialManager.getOnlineCount();
        const totalCount = this.socialManager.getFriendCount();
        this.onlineText = this.add.text(-95, 0, `${onlineCount}/${totalCount} Online`, {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.online.toString(16)
        }).setOrigin(0, 0.5);
        this.onlineContainer.add(this.onlineText);
        
        this.container.add(this.onlineContainer);
    }
    
    /**
     * Create content area
     */
    createContentArea(width, height) {
        this.contentContainer = this.add.container(0, 145);
        
        // Content background
        const contentBg = this.add.graphics();
        contentBg.fillStyle(this.colors.panel, 0.5);
        contentBg.fillRoundedRect(20, 0, width - 40, height - 205, 15);
        this.contentContainer.add(contentBg);
        
        this.container.add(this.contentContainer);
    }
    
    /**
     * Show content for selected tab
     */
    showContent(key) {
        this.clearContent();
        
        switch (key) {
            case 'friends':
                this.showFriends();
                break;
            case 'requests':
                this.showRequests();
                break;
            case 'party':
                this.showParty();
                break;
            case 'activity':
                this.showActivity();
                break;
            case 'search':
                this.showSearch();
                break;
        }
    }
    
    /**
     * Clear content area
     */
    clearContent() {
        const children = [...this.contentContainer.list];
        children.forEach((child, index) => {
            if (index > 0) {
                child.destroy();
            }
        });
    }
    
    /**
     * Show friends list
     */
    showFriends() {
        const width = this.cameras.main.width;
        const friends = this.socialManager.getFriends();
        
        // Header
        const header = this.add.text(40, 20, `Friends (${friends.length})`, {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Filter buttons
        this.createFilterButtons(width);
        
        if (friends.length === 0) {
            this.showEmptyFriends();
            return;
        }
        
        // Friends list
        const listY = 70;
        const itemHeight = 65;
        
        friends.forEach((friend, index) => {
            this.createFriendItem(friend, 40, listY + index * itemHeight, width - 80);
        });
    }
    
    /**
     * Create filter buttons
     */
    createFilterButtons(width) {
        const filters = ['All', 'Online', 'In-Game', 'Offline'];
        const buttonWidth = 70;
        const startX = width - 40 - filters.length * (buttonWidth + 5);
        
        filters.forEach((filter, index) => {
            const x = startX + index * (buttonWidth + 5);
            const isSelected = index === 0;
            
            const bg = this.add.graphics();
            bg.fillStyle(isSelected ? this.colors.accent : this.colors.panelLight, isSelected ? 1 : 0.5);
            bg.fillRoundedRect(x, 15, buttonWidth, 25, 12);
            this.contentContainer.add(bg);
            
            const text = this.add.text(x + buttonWidth / 2, 27, filter, {
                fontSize: '10px',
                fontFamily: 'Arial Black',
                color: isSelected ? '#000000' : '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(text);
        });
    }
    
    /**
     * Create friend list item
     */
    createFriendItem(friend, x, y, width) {
        const itemContainer = this.add.container(x, y);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panelLight, 0.5);
        bg.fillRoundedRect(0, 0, width, 60, 10);
        itemContainer.add(bg);
        
        // Status indicator
        const statusColors = {
            'online': this.colors.online,
            'in-game': this.colors.inGame,
            'away': this.colors.away,
            'offline': this.colors.offline
        };
        
        const statusDot = this.add.graphics();
        statusDot.fillStyle(statusColors[friend.status] || this.colors.offline, 1);
        statusDot.fillCircle(20, 30, 6);
        itemContainer.add(statusDot);
        
        // Avatar
        const avatar = this.add.text(45, 30, friend.avatar, {
            fontSize: '28px'
        }).setOrigin(0, 0.5);
        itemContainer.add(avatar);
        
        // Username
        const username = this.add.text(85, 18, friend.username, {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        itemContainer.add(username);
        
        // Status text
        const statusText = this.getStatusText(friend);
        const status = this.add.text(85, 40, statusText, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        itemContainer.add(status);
        
        // Level
        const level = this.add.text(width - 100, 30, `Lv.${friend.level}`, {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#9966ff'
        }).setOrigin(1, 0.5);
        itemContainer.add(level);
        
        // Action buttons
        if (friend.status !== 'offline') {
            // Invite button
            const inviteBtn = this.add.graphics();
            inviteBtn.fillStyle(this.colors.accent, 1);
            inviteBtn.fillRoundedRect(width - 80, 15, 70, 30, 15);
            itemContainer.add(inviteBtn);
            
            const inviteText = this.add.text(width - 45, 30, 'INVITE', {
                fontSize: '10px',
                fontFamily: 'Arial Black',
                color: '#000000'
            }).setOrigin(0.5, 0.5);
            itemContainer.add(inviteText);
            
            const inviteZone = this.add.zone(width - 45, 30, 70, 30)
                .setInteractive({ useHandCursor: true })
                .on('pointerdown', () => {
                    this.inviteFriend(friend);
                });
            itemContainer.add(inviteZone);
        }
        
        // Make whole item interactive
        const zone = this.add.zone(width / 2, 30, width, 60)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                bg.clear();
                bg.fillStyle(this.colors.panelLight, 0.8);
                bg.fillRoundedRect(0, 0, width, 60, 10);
            })
            .on('pointerout', () => {
                bg.clear();
                bg.fillStyle(this.colors.panelLight, 0.5);
                bg.fillRoundedRect(0, 0, width, 60, 10);
            })
            .on('pointerdown', () => {
                this.selectFriend(friend);
            });
        itemContainer.add(zone);
        
        this.contentContainer.add(itemContainer);
    }
    
    /**
     * Get status text for friend
     */
    getStatusText(friend) {
        switch (friend.status) {
            case 'online':
                return 'Online';
            case 'in-game':
                return 'In Game - Racing';
            case 'away':
                return 'Away';
            case 'offline':
                return 'Last seen ' + this.socialManager.formatRelativeTime(friend.lastSeen);
            default:
                return 'Unknown';
        }
    }
    
    /**
     * Show empty friends message
     */
    showEmptyFriends() {
        const width = this.cameras.main.width;
        
        const emptyIcon = this.add.text(width / 2, 150, '👥', {
            fontSize: '48px'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyIcon);
        
        const emptyText = this.add.text(width / 2, 200, 'No friends yet', {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyText);
        
        const emptyDesc = this.add.text(width / 2, 230, 'Add friends to compete and play together!', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyDesc);
        
        // Add friend button
        const addBtn = this.add.graphics();
        addBtn.fillStyle(this.colors.accent, 1);
        addBtn.fillRoundedRect(width / 2 - 80, 260, 160, 40, 20);
        this.contentContainer.add(addBtn);
        
        const addText = this.add.text(width / 2, 280, '+ ADD FRIENDS', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(addText);
        
        const addZone = this.add.zone(width / 2, 280, 160, 40)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.selectTab('search');
            });
        this.contentContainer.add(addZone);
    }
    
    /**
     * Show friend requests
     */
    showRequests() {
        const width = this.cameras.main.width;
        const requests = this.socialManager.friendRequests;
        
        // Header
        const header = this.add.text(40, 20, `Friend Requests (${requests.length})`, {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        if (requests.length === 0) {
            const emptyText = this.add.text(width / 2, 150, 'No pending requests', {
                fontSize: '16px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(emptyText);
            return;
        }
        
        // Requests list
        requests.forEach((request, index) => {
            this.createRequestItem(request, 40, 60 + index * 70, width - 80);
        });
    }
    
    /**
     * Create request item
     */
    createRequestItem(request, x, y, width) {
        const itemContainer = this.add.container(x, y);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panelLight, 0.5);
        bg.fillRoundedRect(0, 0, width, 65, 10);
        itemContainer.add(bg);
        
        // Avatar
        const avatar = this.add.text(25, 32, request.avatar, {
            fontSize: '28px'
        }).setOrigin(0, 0.5);
        itemContainer.add(avatar);
        
        // Username
        const username = this.add.text(70, 20, request.username, {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        itemContainer.add(username);
        
        // Time
        const time = this.add.text(70, 42, this.socialManager.formatRelativeTime(request.sentAt), {
            fontSize: '11px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        itemContainer.add(time);
        
        // Accept button
        const acceptBtn = this.add.graphics();
        acceptBtn.fillStyle(this.colors.success, 1);
        acceptBtn.fillRoundedRect(width - 160, 17, 70, 30, 15);
        itemContainer.add(acceptBtn);
        
        const acceptText = this.add.text(width - 125, 32, 'ACCEPT', {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        itemContainer.add(acceptText);
        
        const acceptZone = this.add.zone(width - 125, 32, 70, 30)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.acceptRequest(request);
            });
        itemContainer.add(acceptZone);
        
        // Decline button
        const declineBtn = this.add.graphics();
        declineBtn.fillStyle(this.colors.error, 0.5);
        declineBtn.fillRoundedRect(width - 80, 17, 70, 30, 15);
        itemContainer.add(declineBtn);
        
        const declineText = this.add.text(width - 45, 32, 'DECLINE', {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        itemContainer.add(declineText);
        
        const declineZone = this.add.zone(width - 45, 32, 70, 30)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.declineRequest(request);
            });
        itemContainer.add(declineZone);
        
        this.contentContainer.add(itemContainer);
    }
    
    /**
     * Show party tab
     */
    showParty() {
        const width = this.cameras.main.width;
        const party = this.socialManager.currentParty;
        
        // Header
        const header = this.add.text(40, 20, 'Party', {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        if (!party) {
            this.showNoParty(width);
        } else {
            this.showCurrentParty(party, width);
        }
    }
    
    /**
     * Show no party message
     */
    showNoParty(width) {
        const emptyIcon = this.add.text(width / 2, 120, '🎉', {
            fontSize: '48px'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyIcon);
        
        const emptyText = this.add.text(width / 2, 170, "You're not in a party", {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyText);
        
        const emptyDesc = this.add.text(width / 2, 200, 'Create a party or join one to play with friends!', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(emptyDesc);
        
        // Create party button
        const createBtn = this.add.graphics();
        createBtn.fillStyle(this.colors.accent, 1);
        createBtn.fillRoundedRect(width / 2 - 80, 240, 160, 45, 22);
        this.contentContainer.add(createBtn);
        
        const createText = this.add.text(width / 2, 262, 'CREATE PARTY', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(createText);
        
        const createZone = this.add.zone(width / 2, 262, 160, 45)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.createParty();
            });
        this.contentContainer.add(createZone);
    }
    
    /**
     * Show current party
     */
    showCurrentParty(party, width) {
        const startY = 60;
        
        // Party info
        const partyInfo = this.add.text(40, startY, `Party ID: ${party.id.substring(0, 8)}...`, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(partyInfo);
        
        // Members
        const membersLabel = this.add.text(40, startY + 30, 'Members:', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(membersLabel);
        
        party.members.forEach((member, index) => {
            this.createPartyMemberItem(member, 40, startY + 60 + index * 50, width - 80);
        });
        
        // Leave button
        const leaveBtn = this.add.graphics();
        leaveBtn.fillStyle(this.colors.error, 0.5);
        leaveBtn.fillRoundedRect(width / 2 - 80, 350, 160, 40, 20);
        this.contentContainer.add(leaveBtn);
        
        const leaveText = this.add.text(width / 2, 370, 'LEAVE PARTY', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(leaveText);
        
        const leaveZone = this.add.zone(width / 2, 370, 160, 40)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.leaveParty();
            });
        this.contentContainer.add(leaveZone);
    }
    
    /**
     * Create party member item
     */
    createPartyMemberItem(member, x, y, width) {
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panelLight, 0.5);
        bg.fillRoundedRect(x, y, width, 45, 8);
        this.contentContainer.add(bg);
        
        // Crown for leader
        if (member.isLeader) {
            const crown = this.add.text(x + 15, y + 22, '👑', {
                fontSize: '16px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(crown);
        }
        
        // Name
        const name = this.add.text(x + (member.isLeader ? 45 : 15), y + 22, member.username, {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: member.id === 'self' ? '#' + this.colors.accent.toString(16) : '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(name);
        
        // Ready status
        const readyIcon = member.ready ? '✓' : '○';
        const readyColor = member.ready ? '#00ff00' : '#888888';
        const ready = this.add.text(x + width - 15, y + 22, readyIcon, {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: readyColor
        }).setOrigin(1, 0.5);
        this.contentContainer.add(ready);
    }
    
    /**
     * Show activity feed
     */
    showActivity() {
        const width = this.cameras.main.width;
        const feed = this.socialManager.getFeed(15);
        
        // Header
        const header = this.add.text(40, 20, 'Activity Feed', {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        if (feed.length === 0) {
            const emptyText = this.add.text(width / 2, 150, 'No recent activity', {
                fontSize: '16px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(emptyText);
            return;
        }
        
        // Activity items
        let yOffset = 60;
        feed.forEach((activity, index) => {
            const height = this.createActivityItem(activity, 40, yOffset, width - 80);
            yOffset += height + 10;
        });
    }
    
    /**
     * Create activity item
     */
    createActivityItem(activity, x, y, width) {
        const typeIcons = {
            achievement: '🏆',
            highscore: '⭐',
            levelup: '📈',
            race: '🏁',
            challenge: '🎯',
            unlock: '🔓'
        };
        
        const itemContainer = this.add.container(x, y);
        
        // Icon
        const icon = this.add.text(15, 20, typeIcons[activity.type] || '📝', {
            fontSize: '20px'
        }).setOrigin(0, 0.5);
        itemContainer.add(icon);
        
        // User
        const user = this.add.text(50, 12, activity.user, {
            fontSize: '13px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.accent.toString(16)
        }).setOrigin(0, 0.5);
        itemContainer.add(user);
        
        // Content
        const content = this.add.text(50, 30, activity.content, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#ffffff',
            wordWrap: { width: width - 120 }
        }).setOrigin(0, 0.5);
        itemContainer.add(content);
        
        // Time
        const time = this.add.text(width - 10, 20, this.socialManager.formatRelativeTime(activity.time), {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(1, 0.5);
        itemContainer.add(time);
        
        // Like button
        const likeText = this.add.text(width - 10, 38, `❤️ ${activity.likes}`, {
            fontSize: '11px',
            fontFamily: 'Arial',
            color: activity.liked ? '#ff4444' : '#888888'
        }).setOrigin(1, 0.5)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.socialManager.likeActivity(activity.id);
                likeText.setText(`❤️ ${activity.likes}`);
                likeText.setColor(activity.liked ? '#ff4444' : '#888888');
            });
        itemContainer.add(likeText);
        
        this.contentContainer.add(itemContainer);
        
        return 50;
    }
    
    /**
     * Show search tab
     */
    showSearch() {
        const width = this.cameras.main.width;
        
        // Header
        const header = this.add.text(40, 20, 'Find Players', {
            fontSize: '18px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Search input (visual only)
        const inputBg = this.add.graphics();
        inputBg.fillStyle(this.colors.panelLight, 0.8);
        inputBg.fillRoundedRect(40, 55, width - 80, 45, 22);
        this.contentContainer.add(inputBg);
        
        const searchIcon = this.add.text(60, 77, '🔍', {
            fontSize: '20px'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(searchIcon);
        
        const placeholder = this.add.text(95, 77, 'Search by username...', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#666666'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(placeholder);
        
        // Recent players section
        this.showRecentPlayers(width);
        
        // Suggested players section
        this.showSuggestedPlayers(width);
    }
    
    /**
     * Show recent players
     */
    showRecentPlayers(width) {
        const startY = 120;
        const recentPlayers = this.socialManager.getRecentPlayers(5);
        
        const label = this.add.text(40, startY, 'Recent Players', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(label);
        
        if (recentPlayers.length === 0) {
            const emptyText = this.add.text(40, startY + 30, 'Play some games to see recent players!', {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#666666'
            });
            this.contentContainer.add(emptyText);
            return;
        }
        
        recentPlayers.forEach((player, index) => {
            const y = startY + 30 + index * 45;
            this.createSearchResultItem(player, 40, y, width - 80);
        });
    }
    
    /**
     * Show suggested players
     */
    showSuggestedPlayers(width) {
        const startY = 340;
        
        const label = this.add.text(40, startY, 'Suggested Players', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(label);
        
        // Mock suggested players
        const suggested = [
            { id: 's1', username: 'TopRacer', level: 89 },
            { id: 's2', username: 'ChampionX', level: 72 }
        ];
        
        suggested.forEach((player, index) => {
            const y = startY + 30 + index * 45;
            this.createSearchResultItem(player, 40, y, width - 80);
        });
    }
    
    /**
     * Create search result item
     */
    createSearchResultItem(player, x, y, width) {
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panelLight, 0.3);
        bg.fillRoundedRect(x, y, width, 40, 8);
        this.contentContainer.add(bg);
        
        // Username
        const username = this.add.text(x + 15, y + 20, player.username, {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(username);
        
        // Level
        const level = this.add.text(x + 150, y + 20, `Lv.${player.level}`, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#9966ff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(level);
        
        // Add button
        const addBtn = this.add.graphics();
        addBtn.fillStyle(this.colors.accent, 1);
        addBtn.fillRoundedRect(x + width - 70, y + 8, 60, 24, 12);
        this.contentContainer.add(addBtn);
        
        const addText = this.add.text(x + width - 40, y + 20, 'ADD', {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(addText);
        
        const addZone = this.add.zone(x + width - 40, y + 20, 60, 24)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.sendFriendRequest(player.username);
            });
        this.contentContainer.add(addZone);
    }
    
    /**
     * Create back button
     */
    createBackButton() {
        const button = this.add.graphics();
        button.fillStyle(this.colors.panelLight, 0.8);
        button.fillRoundedRect(20, this.cameras.main.height - 70, 100, 40, 20);
        this.container.add(button);
        
        const text = this.add.text(70, this.cameras.main.height - 50, '← BACK', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.container.add(text);
        
        const zone = this.add.zone(70, this.cameras.main.height - 50, 100, 40)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                button.clear();
                button.fillStyle(this.colors.accent, 0.8);
                button.fillRoundedRect(20, this.cameras.main.height - 70, 100, 40, 20);
                text.setColor('#000000');
            })
            .on('pointerout', () => {
                button.clear();
                button.fillStyle(this.colors.panelLight, 0.8);
                button.fillRoundedRect(20, this.cameras.main.height - 70, 100, 40, 20);
                text.setColor('#ffffff');
            })
            .on('pointerdown', () => {
                this.goBack();
            });
        this.container.add(zone);
    }
    
    // === Actions ===
    
    selectFriend(friend) {
        this.selectedFriend = friend;
        this.playClickSound();
    }
    
    inviteFriend(friend) {
        const result = this.socialManager.sendInvite(friend.id);
        this.playClickSound();
        // Show notification
    }
    
    acceptRequest(request) {
        this.socialManager.acceptFriendRequest(request.id);
        this.playClickSound();
        this.showContent('requests');
    }
    
    declineRequest(request) {
        this.socialManager.declineFriendRequest(request.id);
        this.playClickSound();
        this.showContent('requests');
    }
    
    createParty() {
        this.socialManager.createParty();
        this.playClickSound();
        this.showContent('party');
    }
    
    leaveParty() {
        this.socialManager.leaveParty();
        this.playClickSound();
        this.showContent('party');
    }
    
    sendFriendRequest(username) {
        const result = this.socialManager.sendFriendRequest(username);
        this.playClickSound();
        // Show notification
    }
    
    goBack() {
        this.playClickSound();
        this.cameras.main.fadeOut(300);
        this.time.delayedCall(300, () => {
            this.scene.start(this.returnScene);
        });
    }
    
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => {
            this.goBack();
        });
    }
    
    playClickSound() {
        if (this.sound && this.sound.context) {
            const ctx = this.sound.context;
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            
            osc.connect(gain);
            gain.connect(ctx.destination);
            
            osc.frequency.setValueAtTime(800, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(1200, ctx.currentTime + 0.05);
            
            gain.gain.setValueAtTime(0.1, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.1);
            
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + 0.1);
        }
    }
    
    playTabSound() {
        if (this.sound && this.sound.context) {
            const ctx = this.sound.context;
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            
            osc.connect(gain);
            gain.connect(ctx.destination);
            
            osc.type = 'sine';
            osc.frequency.setValueAtTime(600, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(900, ctx.currentTime + 0.03);
            
            gain.gain.setValueAtTime(0.08, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.08);
            
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + 0.08);
        }
    }
    
    update(time, delta) {
        this.animationTimer += delta;
        
        // Update particles
        if (this.particleGraphics) {
            this.particleGraphics.clear();
            
            const height = this.cameras.main.height;
            
            this.particles.forEach(particle => {
                particle.y -= particle.speed * delta * 0.03;
                
                if (particle.y < 0) {
                    particle.y = height;
                    particle.x = Math.random() * this.cameras.main.width;
                }
                
                this.particleGraphics.fillStyle(particle.color, particle.alpha);
                this.particleGraphics.fillCircle(particle.x, particle.y, particle.size);
            });
        }
        
        // Update online count
        if (this.onlineText) {
            const onlineCount = this.socialManager.getOnlineCount();
            const totalCount = this.socialManager.getFriendCount();
            this.onlineText.setText(`${onlineCount}/${totalCount} Online`);
        }
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.SocialScene = SocialScene;
}
