/**
 * ProfileScene.js
 * Player profile management and customization scene
 * Part of GRAVSHIFT - A gravity-defying racing game
 */

class ProfileScene extends Phaser.Scene {
    constructor() {
        super({ key: 'ProfileScene' });
        
        // Scene state
        this.currentProfile = null;
        this.profiles = [];
        this.selectedTab = 'overview';
        this.isEditing = false;
        this.editField = null;
        
        // UI elements
        this.container = null;
        this.tabButtons = [];
        this.contentContainer = null;
        this.editModal = null;
        
        // Animation state
        this.animationTimer = 0;
        this.levelProgress = 0;
        this.particles = [];
        
        // Colors
        this.colors = {
            background: 0x0a0a1a,
            panel: 0x1a1a3a,
            panelLight: 0x2a2a4a,
            accent: 0x00ffaa,
            accentAlt: 0xff6600,
            gold: 0xffd700,
            silver: 0xc0c0c0,
            bronze: 0xcd7f32,
            text: 0xffffff,
            textDim: 0x888899,
            success: 0x00ff00,
            warning: 0xffaa00,
            error: 0xff4444,
            xp: 0x9966ff
        };
        
        // Rank tiers
        this.ranks = [
            { name: 'Rookie', minLevel: 1, color: 0xaaaaaa, icon: '🔰' },
            { name: 'Amateur', minLevel: 5, color: 0x66ff66, icon: '⭐' },
            { name: 'Semi-Pro', minLevel: 10, color: 0x6666ff, icon: '🌟' },
            { name: 'Professional', minLevel: 20, color: 0xff66ff, icon: '💫' },
            { name: 'Expert', minLevel: 35, color: 0xffaa00, icon: '🏆' },
            { name: 'Master', minLevel: 50, color: 0xff6600, icon: '👑' },
            { name: 'Grandmaster', minLevel: 75, color: 0xff0000, icon: '🔥' },
            { name: 'Legend', minLevel: 100, color: 0xffd700, icon: '⚡' }
        ];
        
        // Avatar frames
        this.avatarFrames = [
            { id: 'default', name: 'Default', color: 0x444466, unlocked: true },
            { id: 'bronze', name: 'Bronze', color: 0xcd7f32, unlocked: false, requirement: 'Reach level 10' },
            { id: 'silver', name: 'Silver', color: 0xc0c0c0, unlocked: false, requirement: 'Reach level 25' },
            { id: 'gold', name: 'Gold', color: 0xffd700, unlocked: false, requirement: 'Reach level 50' },
            { id: 'diamond', name: 'Diamond', color: 0x00ffff, unlocked: false, requirement: 'Reach level 75' },
            { id: 'champion', name: 'Champion', color: 0xff00ff, unlocked: false, requirement: 'Win 100 races' },
            { id: 'legendary', name: 'Legendary', color: 0xff6600, unlocked: false, requirement: 'Complete all achievements' }
        ];
        
        // Title options
        this.titles = [
            { id: 'racer', name: 'Racer', unlocked: true },
            { id: 'speedster', name: 'Speedster', unlocked: false, requirement: 'Reach 500 km/h' },
            { id: 'survivor', name: 'Survivor', unlocked: false, requirement: 'Survive 10 minutes' },
            { id: 'collector', name: 'Collector', unlocked: false, requirement: 'Collect 10,000 crystals' },
            { id: 'drifter', name: 'Drifter', unlocked: false, requirement: 'Drift for 1 km total' },
            { id: 'perfectionist', name: 'Perfectionist', unlocked: false, requirement: 'Get 100 perfect runs' },
            { id: 'champion', name: 'Champion', unlocked: false, requirement: 'Win 50 multiplayer races' },
            { id: 'legend', name: 'Legend', unlocked: false, requirement: 'Reach max level' }
        ];
    }
    
    /**
     * Initialize scene with data
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
        this.profileId = data.profileId || null;
    }
    
    /**
     * Create scene elements
     */
    create() {
        const width = this.cameras.main.width;
        const height = this.cameras.main.height;
        
        // Background
        this.createBackground(width, height);
        
        // Main container
        this.container = this.add.container(0, 0);
        
        // Load profiles
        this.loadProfiles();
        
        // Title
        this.createTitle(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Profile header (avatar, name, level)
        this.createProfileHeader(width);
        
        // Content area
        this.createContentArea(width, height);
        
        // Back button
        this.createBackButton();
        
        // Select initial tab
        this.selectTab('overview');
        
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
        
        // Animated particles
        for (let i = 0; i < 40; i++) {
            this.particles.push({
                x: Math.random() * width,
                y: Math.random() * height,
                size: Math.random() * 2 + 1,
                speed: Math.random() * 0.3 + 0.1,
                alpha: Math.random() * 0.4 + 0.1,
                color: this.colors.xp
            });
        }
        
        this.particleGraphics = this.add.graphics();
        
        // Decorative lines
        const lines = this.add.graphics();
        lines.lineStyle(1, this.colors.accent, 0.05);
        
        for (let i = 0; i < 20; i++) {
            const y = i * (height / 20);
            lines.lineBetween(0, y, width, y);
        }
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
        
        // Profile icon
        const profileIcon = this.add.text(30, 40, '👤', {
            fontSize: '36px'
        }).setOrigin(0, 0.5);
        this.container.add(profileIcon);
        
        // Title text
        const title = this.add.text(80, 30, 'PLAYER PROFILE', {
            fontSize: '32px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.container.add(title);
        
        // Subtitle
        const subtitle = this.add.text(80, 55, 'Customize and track your progress', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.container.add(subtitle);
        
        // Switch profile button
        this.createSwitchProfileButton(width);
    }
    
    /**
     * Create switch profile button
     */
    createSwitchProfileButton(width) {
        const button = this.add.graphics();
        button.fillStyle(this.colors.panelLight, 0.8);
        button.fillRoundedRect(width - 170, 25, 150, 35, 17);
        this.container.add(button);
        
        const text = this.add.text(width - 95, 42, '↔ SWITCH PROFILE', {
            fontSize: '11px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.container.add(text);
        
        const zone = this.add.zone(width - 95, 42, 150, 35)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                button.clear();
                button.fillStyle(this.colors.accent, 0.8);
                button.fillRoundedRect(width - 170, 25, 150, 35, 17);
                text.setColor('#000000');
            })
            .on('pointerout', () => {
                button.clear();
                button.fillStyle(this.colors.panelLight, 0.8);
                button.fillRoundedRect(width - 170, 25, 150, 35, 17);
                text.setColor('#ffffff');
            })
            .on('pointerdown', () => {
                this.showProfileSwitcher();
            });
        this.container.add(zone);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabs = [
            { key: 'overview', label: 'OVERVIEW', icon: '📊' },
            { key: 'customize', label: 'CUSTOMIZE', icon: '🎨' },
            { key: 'achievements', label: 'ACHIEVEMENTS', icon: '🏆' },
            { key: 'history', label: 'HISTORY', icon: '📜' }
        ];
        
        const tabWidth = (width - 40) / tabs.length;
        const startX = 20;
        const y = 90;
        
        this.tabContainer = this.add.container(0, y);
        
        tabs.forEach((tab, index) => {
            const x = startX + index * tabWidth;
            
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, 0, tabWidth - 5, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
            this.tabContainer.add(bg);
            
            const text = this.add.text(x + tabWidth / 2, 20, `${tab.icon} ${tab.label}`, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#888899'
            }).setOrigin(0.5, 0.5);
            this.tabContainer.add(text);
            
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
     * Create profile header
     */
    createProfileHeader(width) {
        this.headerContainer = this.add.container(0, 145);
        
        // Header background
        const headerBg = this.add.graphics();
        headerBg.fillStyle(this.colors.panel, 0.8);
        headerBg.fillRoundedRect(20, 0, width - 40, 120, 15);
        this.headerContainer.add(headerBg);
        
        // Avatar
        this.createAvatar(70, 60);
        
        // Player name
        this.playerNameText = this.add.text(140, 25, this.currentProfile?.name || 'Player', {
            fontSize: '24px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.headerContainer.add(this.playerNameText);
        
        // Edit name button
        const editBtn = this.add.text(
            this.playerNameText.x + this.playerNameText.width + 15, 
            25, '✏️', {
            fontSize: '16px'
        }).setOrigin(0, 0.5)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => this.editPlayerName());
        this.headerContainer.add(editBtn);
        
        // Title/Rank
        this.createTitleDisplay(140, 50);
        
        // Level and XP
        this.createLevelDisplay(140, 85, width);
        
        // Currency display
        this.createCurrencyDisplay(width - 40, 30);
        
        this.container.add(this.headerContainer);
    }
    
    /**
     * Create avatar display
     */
    createAvatar(x, y) {
        const profile = this.currentProfile;
        const frameColor = this.getAvatarFrameColor(profile?.avatarFrame);
        
        // Avatar background
        const avatarBg = this.add.graphics();
        avatarBg.fillStyle(this.colors.panelLight, 1);
        avatarBg.fillCircle(x, y, 45);
        this.headerContainer.add(avatarBg);
        
        // Avatar frame
        const frame = this.add.graphics();
        frame.lineStyle(4, frameColor, 1);
        frame.strokeCircle(x, y, 45);
        this.headerContainer.add(frame);
        
        // Avatar icon (placeholder)
        const avatarIcon = this.add.text(x, y, '🏎️', {
            fontSize: '36px'
        }).setOrigin(0.5, 0.5);
        this.headerContainer.add(avatarIcon);
        
        // Level badge
        const level = profile?.level || 1;
        const levelBadge = this.add.graphics();
        levelBadge.fillStyle(this.colors.xp, 1);
        levelBadge.fillCircle(x + 32, y + 32, 15);
        this.headerContainer.add(levelBadge);
        
        const levelText = this.add.text(x + 32, y + 32, level.toString(), {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.headerContainer.add(levelText);
    }
    
    /**
     * Get avatar frame color
     */
    getAvatarFrameColor(frameId) {
        const frame = this.avatarFrames.find(f => f.id === frameId);
        return frame ? frame.color : this.colors.panelLight;
    }
    
    /**
     * Create title display
     */
    createTitleDisplay(x, y) {
        const profile = this.currentProfile;
        const rank = this.getRank(profile?.level || 1);
        const title = this.titles.find(t => t.id === profile?.title) || this.titles[0];
        
        // Rank icon
        const rankIcon = this.add.text(x, y, rank.icon, {
            fontSize: '16px'
        }).setOrigin(0, 0.5);
        this.headerContainer.add(rankIcon);
        
        // Rank name
        const rankText = this.add.text(x + 25, y, rank.name, {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + rank.color.toString(16)
        }).setOrigin(0, 0.5);
        this.headerContainer.add(rankText);
        
        // Separator
        const sep = this.add.text(x + 100, y, '•', {
            fontSize: '14px',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.headerContainer.add(sep);
        
        // Title
        const titleText = this.add.text(x + 115, y, title.name, {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.headerContainer.add(titleText);
    }
    
    /**
     * Get rank for level
     */
    getRank(level) {
        let rank = this.ranks[0];
        for (const r of this.ranks) {
            if (level >= r.minLevel) {
                rank = r;
            }
        }
        return rank;
    }
    
    /**
     * Create level display with XP bar
     */
    createLevelDisplay(x, y, width) {
        const profile = this.currentProfile;
        const level = profile?.level || 1;
        const xp = profile?.xp || 0;
        const xpForLevel = this.getXPForLevel(level);
        const xpForNextLevel = this.getXPForLevel(level + 1);
        const xpInLevel = xp - xpForLevel;
        const xpNeeded = xpForNextLevel - xpForLevel;
        const progress = xpInLevel / xpNeeded;
        
        const barWidth = width - 200;
        const barHeight = 20;
        
        // Label
        const label = this.add.text(x, y - 12, `LEVEL ${level}`, {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.headerContainer.add(label);
        
        // XP bar background
        const barBg = this.add.graphics();
        barBg.fillStyle(0x000000, 0.5);
        barBg.fillRoundedRect(x, y, barWidth, barHeight, barHeight / 2);
        this.headerContainer.add(barBg);
        
        // XP bar fill
        if (progress > 0) {
            const barFill = this.add.graphics();
            barFill.fillStyle(this.colors.xp, 1);
            barFill.fillRoundedRect(x, y, barWidth * progress, barHeight, barHeight / 2);
            this.headerContainer.add(barFill);
        }
        
        // XP text
        const xpText = this.add.text(x + barWidth / 2, y + barHeight / 2, 
            `${this.formatNumber(xpInLevel)} / ${this.formatNumber(xpNeeded)} XP`, {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.headerContainer.add(xpText);
        
        // Next level info
        const nextLevel = this.add.text(x + barWidth + 10, y + barHeight / 2, 
            `→ LVL ${level + 1}`, {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.headerContainer.add(nextLevel);
    }
    
    /**
     * Get XP required for level
     */
    getXPForLevel(level) {
        return Math.floor(100 * Math.pow(level, 1.5));
    }
    
    /**
     * Create currency display
     */
    createCurrencyDisplay(x, y) {
        const profile = this.currentProfile;
        
        // Coins
        const coinsBg = this.add.graphics();
        coinsBg.fillStyle(this.colors.panelLight, 0.8);
        coinsBg.fillRoundedRect(x - 130, y - 15, 120, 30, 15);
        this.headerContainer.add(coinsBg);
        
        const coinsIcon = this.add.text(x - 120, y, '🪙', {
            fontSize: '16px'
        }).setOrigin(0, 0.5);
        this.headerContainer.add(coinsIcon);
        
        const coinsText = this.add.text(x - 95, y, this.formatNumber(profile?.coins || 0), {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.gold.toString(16)
        }).setOrigin(0, 0.5);
        this.headerContainer.add(coinsText);
        
        // Gems
        const gemsBg = this.add.graphics();
        gemsBg.fillStyle(this.colors.panelLight, 0.8);
        gemsBg.fillRoundedRect(x - 130, y + 25, 120, 30, 15);
        this.headerContainer.add(gemsBg);
        
        const gemsIcon = this.add.text(x - 120, y + 40, '💎', {
            fontSize: '16px'
        }).setOrigin(0, 0.5);
        this.headerContainer.add(gemsIcon);
        
        const gemsText = this.add.text(x - 95, y + 40, this.formatNumber(profile?.gems || 0), {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#00ffff'
        }).setOrigin(0, 0.5);
        this.headerContainer.add(gemsText);
    }
    
    /**
     * Create content area
     */
    createContentArea(width, height) {
        this.contentContainer = this.add.container(0, 280);
        
        // Content background
        const contentBg = this.add.graphics();
        contentBg.fillStyle(this.colors.panel, 0.5);
        contentBg.fillRoundedRect(20, 0, width - 40, height - 340, 15);
        this.contentContainer.add(contentBg);
        
        this.container.add(this.contentContainer);
    }
    
    /**
     * Show content for selected tab
     */
    showContent(key) {
        this.clearContent();
        
        switch (key) {
            case 'overview':
                this.showOverview();
                break;
            case 'customize':
                this.showCustomize();
                break;
            case 'achievements':
                this.showAchievements();
                break;
            case 'history':
                this.showHistory();
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
     * Show overview tab
     */
    showOverview() {
        const width = this.cameras.main.width;
        const profile = this.currentProfile;
        
        // Stats grid
        this.createStatsGrid(width, profile);
        
        // Recent activity
        this.createRecentActivity(width);
        
        // Quick stats
        this.createQuickStats(width, profile);
    }
    
    /**
     * Create stats grid
     */
    createStatsGrid(width, profile) {
        const stats = [
            { label: 'TOTAL RACES', value: profile?.stats?.totalRaces || 0, icon: '🏁' },
            { label: 'WINS', value: profile?.stats?.wins || 0, icon: '🏆' },
            { label: 'WIN RATE', value: this.calculateWinRate(profile) + '%', icon: '📊' },
            { label: 'BEST SCORE', value: this.formatNumber(profile?.stats?.bestScore || 0), icon: '⭐' },
            { label: 'TOTAL DISTANCE', value: this.formatDistance(profile?.stats?.totalDistance || 0), icon: '🛣️' },
            { label: 'PLAY TIME', value: this.formatPlayTime(profile?.stats?.playTime || 0), icon: '⏱️' },
            { label: 'CRYSTALS', value: this.formatNumber(profile?.stats?.totalCrystals || 0), icon: '💎' },
            { label: 'ACHIEVEMENTS', value: `${profile?.stats?.achievements || 0}/50`, icon: '🎖️' }
        ];
        
        const cols = 4;
        const rows = 2;
        const cellWidth = (width - 80) / cols;
        const cellHeight = 70;
        
        stats.forEach((stat, index) => {
            const col = index % cols;
            const row = Math.floor(index / cols);
            const x = 40 + col * cellWidth;
            const y = 20 + row * cellHeight;
            
            // Cell background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, y, cellWidth - 10, cellHeight - 10, 10);
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(x + 15, y + (cellHeight - 10) / 2, stat.icon, {
                fontSize: '24px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(icon);
            
            // Value
            const value = this.add.text(x + cellWidth - 20, y + 20, stat.value.toString(), {
                fontSize: '18px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(1, 0.5);
            this.contentContainer.add(value);
            
            // Label
            const label = this.add.text(x + cellWidth - 20, y + 42, stat.label, {
                fontSize: '9px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(1, 0.5);
            this.contentContainer.add(label);
        });
    }
    
    /**
     * Calculate win rate
     */
    calculateWinRate(profile) {
        const races = profile?.stats?.totalRaces || 0;
        const wins = profile?.stats?.wins || 0;
        if (races === 0) return 0;
        return Math.round((wins / races) * 100);
    }
    
    /**
     * Format distance
     */
    formatDistance(meters) {
        if (meters >= 1000000) {
            return (meters / 1000000).toFixed(1) + 'M m';
        } else if (meters >= 1000) {
            return (meters / 1000).toFixed(1) + 'K m';
        }
        return meters + ' m';
    }
    
    /**
     * Format play time
     */
    formatPlayTime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return `${hours}h ${minutes}m`;
    }
    
    /**
     * Create recent activity section
     */
    createRecentActivity(width) {
        const startY = 160;
        
        // Section header
        const header = this.add.text(40, startY, 'Recent Activity', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Activity items
        const activities = this.generateMockActivity();
        
        activities.slice(0, 5).forEach((activity, index) => {
            const y = startY + 30 + index * 35;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.3);
            bg.fillRoundedRect(40, y, (width - 80) / 2 - 10, 30, 6);
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(55, y + 15, activity.icon, {
                fontSize: '14px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(icon);
            
            // Description
            const desc = this.add.text(80, y + 10, activity.description, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(desc);
            
            // Time
            const time = this.add.text(80, y + 22, activity.time, {
                fontSize: '9px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(time);
        });
    }
    
    /**
     * Generate mock activity
     */
    generateMockActivity() {
        return [
            { icon: '🏆', description: 'Won a race on Neon Highway', time: '5 minutes ago' },
            { icon: '⭐', description: 'New high score: 125,000', time: '12 minutes ago' },
            { icon: '🎖️', description: 'Unlocked "Speed Demon" achievement', time: '1 hour ago' },
            { icon: '🚗', description: 'Purchased Quantum Racer', time: '2 hours ago' },
            { icon: '📈', description: 'Reached Level 15', time: '3 hours ago' }
        ];
    }
    
    /**
     * Create quick stats section
     */
    createQuickStats(width, profile) {
        const startX = width / 2 + 10;
        const startY = 160;
        
        // Section header
        const header = this.add.text(startX, startY, 'Performance Graph', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Simple bar chart
        this.createPerformanceChart(startX, startY + 30, (width - 80) / 2 - 10, 140);
    }
    
    /**
     * Create performance chart
     */
    createPerformanceChart(x, y, chartWidth, chartHeight) {
        // Chart background
        const chartBg = this.add.graphics();
        chartBg.fillStyle(this.colors.panelLight, 0.3);
        chartBg.fillRoundedRect(x, y, chartWidth, chartHeight, 10);
        this.contentContainer.add(chartBg);
        
        // Data points (last 7 days)
        const data = [65, 78, 52, 89, 73, 95, 82];
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const barWidth = (chartWidth - 40) / data.length;
        const maxValue = Math.max(...data);
        
        data.forEach((value, index) => {
            const barX = x + 20 + index * barWidth;
            const barHeight = (value / maxValue) * (chartHeight - 50);
            const barY = y + chartHeight - 30 - barHeight;
            
            // Bar
            const bar = this.add.graphics();
            bar.fillStyle(this.colors.accent, 0.8);
            bar.fillRoundedRect(barX + 5, barY, barWidth - 10, barHeight, 4);
            this.contentContainer.add(bar);
            
            // Value
            const valueText = this.add.text(barX + barWidth / 2, barY - 10, value.toString(), {
                fontSize: '10px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(valueText);
            
            // Label
            const label = this.add.text(barX + barWidth / 2, y + chartHeight - 12, labels[index], {
                fontSize: '9px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(label);
        });
    }
    
    /**
     * Show customize tab
     */
    showCustomize() {
        const width = this.cameras.main.width;
        
        // Avatar frames section
        this.createAvatarFramesSection(width);
        
        // Titles section
        this.createTitlesSection(width);
        
        // Theme section
        this.createThemeSection(width);
    }
    
    /**
     * Create avatar frames section
     */
    createAvatarFramesSection(width) {
        const startY = 20;
        
        // Header
        const header = this.add.text(40, startY, 'Avatar Frames', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Frames grid
        const frameSize = 60;
        const padding = 15;
        const cols = Math.floor((width - 80) / (frameSize + padding));
        
        this.avatarFrames.forEach((frame, index) => {
            const col = index % cols;
            const row = Math.floor(index / cols);
            const x = 40 + col * (frameSize + padding) + frameSize / 2;
            const y = startY + 40 + row * (frameSize + padding + 20) + frameSize / 2;
            
            // Frame preview
            const preview = this.add.graphics();
            preview.fillStyle(this.colors.panelLight, 1);
            preview.fillCircle(x, y, frameSize / 2 - 5);
            
            if (frame.unlocked) {
                preview.lineStyle(4, frame.color, 1);
            } else {
                preview.lineStyle(4, 0x444444, 0.5);
            }
            preview.strokeCircle(x, y, frameSize / 2 - 5);
            this.contentContainer.add(preview);
            
            // Lock overlay
            if (!frame.unlocked) {
                const lock = this.add.text(x, y, '🔒', {
                    fontSize: '20px'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(lock);
            }
            
            // Name
            const name = this.add.text(x, y + frameSize / 2 + 8, frame.name, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: frame.unlocked ? '#ffffff' : '#666666'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(name);
            
            // Make interactive if unlocked
            if (frame.unlocked) {
                const zone = this.add.zone(x, y, frameSize, frameSize)
                    .setInteractive({ useHandCursor: true })
                    .on('pointerdown', () => this.selectAvatarFrame(frame.id));
                this.contentContainer.add(zone);
            }
        });
    }
    
    /**
     * Create titles section
     */
    createTitlesSection(width) {
        const startY = 170;
        
        // Header
        const header = this.add.text(40, startY, 'Player Titles', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Titles list
        const titleWidth = (width - 100) / 2;
        
        this.titles.forEach((title, index) => {
            const col = index % 2;
            const row = Math.floor(index / 2);
            const x = 40 + col * (titleWidth + 20);
            const y = startY + 35 + row * 40;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(title.unlocked ? this.colors.panelLight : 0x222233, 0.5);
            bg.fillRoundedRect(x, y, titleWidth, 35, 8);
            
            if (this.currentProfile?.title === title.id) {
                bg.lineStyle(2, this.colors.accent, 1);
                bg.strokeRoundedRect(x, y, titleWidth, 35, 8);
            }
            this.contentContainer.add(bg);
            
            // Title name
            const nameText = this.add.text(x + 15, y + 17, title.name, {
                fontSize: '14px',
                fontFamily: 'Arial',
                color: title.unlocked ? '#ffffff' : '#666666'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(nameText);
            
            // Status
            if (!title.unlocked) {
                const lock = this.add.text(x + titleWidth - 15, y + 17, '🔒', {
                    fontSize: '14px'
                }).setOrigin(1, 0.5);
                this.contentContainer.add(lock);
            } else if (this.currentProfile?.title === title.id) {
                const check = this.add.text(x + titleWidth - 15, y + 17, '✓', {
                    fontSize: '14px',
                    color: '#00ff00'
                }).setOrigin(1, 0.5);
                this.contentContainer.add(check);
            }
            
            // Interactive
            if (title.unlocked) {
                const zone = this.add.zone(x + titleWidth / 2, y + 17, titleWidth, 35)
                    .setInteractive({ useHandCursor: true })
                    .on('pointerdown', () => this.selectTitle(title.id));
                this.contentContainer.add(zone);
            }
        });
    }
    
    /**
     * Create theme section
     */
    createThemeSection(width) {
        const startY = 340;
        
        // Header
        const header = this.add.text(40, startY, 'UI Theme', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Theme options
        const themes = [
            { id: 'default', name: 'Default', color: 0x00ffaa },
            { id: 'crimson', name: 'Crimson', color: 0xff4444 },
            { id: 'ocean', name: 'Ocean', color: 0x4444ff },
            { id: 'sunset', name: 'Sunset', color: 0xff8800 },
            { id: 'neon', name: 'Neon', color: 0xff00ff }
        ];
        
        const themeWidth = 80;
        
        themes.forEach((theme, index) => {
            const x = 40 + index * (themeWidth + 15);
            const y = startY + 35;
            
            // Color preview
            const preview = this.add.graphics();
            preview.fillStyle(theme.color, 0.3);
            preview.fillRoundedRect(x, y, themeWidth, 50, 10);
            preview.lineStyle(3, theme.color, 1);
            preview.strokeRoundedRect(x, y, themeWidth, 50, 10);
            this.contentContainer.add(preview);
            
            // Name
            const name = this.add.text(x + themeWidth / 2, y + 65, theme.name, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(name);
            
            // Interactive
            const zone = this.add.zone(x + themeWidth / 2, y + 25, themeWidth, 50)
                .setInteractive({ useHandCursor: true })
                .on('pointerdown', () => this.selectTheme(theme.id));
            this.contentContainer.add(zone);
        });
    }
    
    /**
     * Show achievements tab
     */
    showAchievements() {
        const width = this.cameras.main.width;
        
        // Achievement stats
        this.createAchievementStats(width);
        
        // Achievement categories
        this.createAchievementCategories(width);
        
        // Achievement list
        this.createAchievementList(width);
    }
    
    /**
     * Create achievement stats
     */
    createAchievementStats(width) {
        const profile = this.currentProfile;
        const completed = profile?.stats?.achievements || 12;
        const total = 50;
        const progress = completed / total;
        
        // Progress bar
        const barWidth = width - 80;
        const barHeight = 30;
        const barX = 40;
        const barY = 20;
        
        // Background
        const barBg = this.add.graphics();
        barBg.fillStyle(0x000000, 0.5);
        barBg.fillRoundedRect(barX, barY, barWidth, barHeight, barHeight / 2);
        this.contentContainer.add(barBg);
        
        // Fill
        if (progress > 0) {
            const barFill = this.add.graphics();
            barFill.fillStyle(this.colors.gold, 1);
            barFill.fillRoundedRect(barX, barY, barWidth * progress, barHeight, barHeight / 2);
            this.contentContainer.add(barFill);
        }
        
        // Text
        const progressText = this.add.text(barX + barWidth / 2, barY + barHeight / 2, 
            `${completed} / ${total} Achievements (${Math.round(progress * 100)}%)`, {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(progressText);
    }
    
    /**
     * Create achievement categories
     */
    createAchievementCategories(width) {
        const categories = [
            { name: 'Racing', completed: 5, total: 10, icon: '🏁' },
            { name: 'Collection', completed: 3, total: 10, icon: '💎' },
            { name: 'Skill', completed: 2, total: 10, icon: '🎯' },
            { name: 'Social', completed: 1, total: 10, icon: '👥' },
            { name: 'Special', completed: 1, total: 10, icon: '⭐' }
        ];
        
        const catWidth = (width - 80) / categories.length;
        
        categories.forEach((cat, index) => {
            const x = 40 + index * catWidth;
            const y = 65;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, y, catWidth - 10, 60, 10);
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(x + 15, y + 30, cat.icon, {
                fontSize: '20px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(icon);
            
            // Name and progress
            const name = this.add.text(x + 45, y + 20, cat.name, {
                fontSize: '12px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(name);
            
            const progress = this.add.text(x + 45, y + 40, `${cat.completed}/${cat.total}`, {
                fontSize: '11px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(progress);
        });
    }
    
    /**
     * Create achievement list
     */
    createAchievementList(width) {
        const startY = 140;
        
        const achievements = [
            { name: 'First Victory', desc: 'Win your first race', icon: '🏆', unlocked: true, rarity: 'common' },
            { name: 'Speed Demon', desc: 'Reach 500 km/h', icon: '⚡', unlocked: true, rarity: 'rare' },
            { name: 'Collector', desc: 'Collect 1000 crystals', icon: '💎', unlocked: true, rarity: 'common' },
            { name: 'Survivor', desc: 'Survive 5 minutes', icon: '❤️', unlocked: false, rarity: 'uncommon' },
            { name: 'Perfect Run', desc: 'Complete without damage', icon: '✨', unlocked: false, rarity: 'rare' },
            { name: 'Legend', desc: 'Reach max level', icon: '👑', unlocked: false, rarity: 'legendary' }
        ];
        
        const rarityColors = {
            common: 0xaaaaaa,
            uncommon: 0x00ff00,
            rare: 0x0088ff,
            epic: 0xff00ff,
            legendary: 0xffd700
        };
        
        achievements.forEach((ach, index) => {
            const col = index % 2;
            const row = Math.floor(index / 2);
            const achWidth = (width - 90) / 2;
            const x = 40 + col * (achWidth + 10);
            const y = startY + row * 60;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(ach.unlocked ? this.colors.panelLight : 0x222233, 0.5);
            bg.fillRoundedRect(x, y, achWidth, 55, 10);
            
            // Rarity border
            bg.lineStyle(2, rarityColors[ach.rarity], ach.unlocked ? 0.8 : 0.3);
            bg.strokeRoundedRect(x, y, achWidth, 55, 10);
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(x + 30, y + 27, ach.icon, {
                fontSize: '24px'
            }).setOrigin(0.5, 0.5);
            if (!ach.unlocked) icon.setAlpha(0.3);
            this.contentContainer.add(icon);
            
            // Name
            const name = this.add.text(x + 60, y + 17, ach.name, {
                fontSize: '13px',
                fontFamily: 'Arial Black',
                color: ach.unlocked ? '#ffffff' : '#666666'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(name);
            
            // Description
            const desc = this.add.text(x + 60, y + 37, ach.desc, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(desc);
            
            // Lock or check
            if (!ach.unlocked) {
                const lock = this.add.text(x + achWidth - 25, y + 27, '🔒', {
                    fontSize: '16px'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(lock);
            } else {
                const check = this.add.text(x + achWidth - 25, y + 27, '✓', {
                    fontSize: '18px',
                    fontFamily: 'Arial Black',
                    color: '#00ff00'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(check);
            }
        });
    }
    
    /**
     * Show history tab
     */
    showHistory() {
        const width = this.cameras.main.width;
        
        // Race history
        this.createRaceHistory(width);
        
        // Statistics chart
        this.createHistoryChart(width);
    }
    
    /**
     * Create race history
     */
    createRaceHistory(width) {
        const races = this.generateMockRaceHistory();
        const startY = 20;
        
        // Header
        const header = this.add.text(40, startY, 'Recent Races', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Table header
        const headers = ['Result', 'Track', 'Score', 'Time', 'Date'];
        const colWidths = [60, 150, 100, 80, 100];
        let headerX = 40;
        
        headers.forEach((h, i) => {
            const headerText = this.add.text(headerX, startY + 30, h, {
                fontSize: '10px',
                fontFamily: 'Arial Black',
                color: '#' + this.colors.textDim.toString(16)
            });
            this.contentContainer.add(headerText);
            headerX += colWidths[i];
        });
        
        // Race rows
        races.forEach((race, index) => {
            const y = startY + 55 + index * 35;
            let x = 40;
            
            // Row background
            const rowBg = this.add.graphics();
            rowBg.fillStyle(this.colors.panelLight, index % 2 === 0 ? 0.3 : 0.1);
            rowBg.fillRoundedRect(35, y - 5, width - 70, 30, 5);
            this.contentContainer.add(rowBg);
            
            // Result
            const resultIcon = race.position === 1 ? '🥇' : race.position === 2 ? '🥈' : race.position === 3 ? '🥉' : `#${race.position}`;
            const result = this.add.text(x, y + 10, resultIcon, {
                fontSize: '14px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(result);
            x += colWidths[0];
            
            // Track
            const track = this.add.text(x, y + 10, race.track, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(track);
            x += colWidths[1];
            
            // Score
            const score = this.add.text(x, y + 10, this.formatNumber(race.score), {
                fontSize: '12px',
                fontFamily: 'Arial Black',
                color: '#' + this.colors.accent.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(score);
            x += colWidths[2];
            
            // Time
            const time = this.add.text(x, y + 10, race.time, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(time);
            x += colWidths[3];
            
            // Date
            const date = this.add.text(x, y + 10, race.date, {
                fontSize: '11px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(date);
        });
    }
    
    /**
     * Generate mock race history
     */
    generateMockRaceHistory() {
        return [
            { position: 1, track: 'Neon Highway', score: 125000, time: '3:45', date: 'Today' },
            { position: 3, track: 'Crystal Caverns', score: 98000, time: '4:12', date: 'Today' },
            { position: 2, track: 'Cyber City', score: 115000, time: '3:58', date: 'Yesterday' },
            { position: 1, track: 'Space Station', score: 142000, time: '4:30', date: 'Yesterday' },
            { position: 5, track: 'Volcanic Rush', score: 76000, time: '3:22', date: '2 days ago' },
            { position: 1, track: 'Arctic Drift', score: 108000, time: '3:55', date: '2 days ago' }
        ];
    }
    
    /**
     * Create history chart
     */
    createHistoryChart(width) {
        const startY = 280;
        
        // Header
        const header = this.add.text(40, startY, 'Score Trend', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Chart area
        const chartX = 40;
        const chartY = startY + 30;
        const chartWidth = width - 80;
        const chartHeight = 100;
        
        // Background
        const chartBg = this.add.graphics();
        chartBg.fillStyle(this.colors.panelLight, 0.3);
        chartBg.fillRoundedRect(chartX, chartY, chartWidth, chartHeight, 10);
        this.contentContainer.add(chartBg);
        
        // Line chart data
        const data = [65, 72, 68, 85, 78, 92, 88, 95, 91, 98];
        const maxValue = Math.max(...data);
        const pointSpacing = (chartWidth - 40) / (data.length - 1);
        
        // Draw line
        const line = this.add.graphics();
        line.lineStyle(3, this.colors.accent, 1);
        
        data.forEach((value, index) => {
            const x = chartX + 20 + index * pointSpacing;
            const y = chartY + chartHeight - 20 - ((value / maxValue) * (chartHeight - 40));
            
            if (index === 0) {
                line.beginPath();
                line.moveTo(x, y);
            } else {
                line.lineTo(x, y);
            }
        });
        line.strokePath();
        this.contentContainer.add(line);
        
        // Draw points
        data.forEach((value, index) => {
            const x = chartX + 20 + index * pointSpacing;
            const y = chartY + chartHeight - 20 - ((value / maxValue) * (chartHeight - 40));
            
            const point = this.add.graphics();
            point.fillStyle(this.colors.accent, 1);
            point.fillCircle(x, y, 5);
            point.fillStyle(0x000000, 1);
            point.fillCircle(x, y, 2);
            this.contentContainer.add(point);
        });
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
    
    /**
     * Load profiles
     */
    loadProfiles() {
        try {
            const saved = localStorage.getItem('gravshift_profiles');
            if (saved) {
                this.profiles = JSON.parse(saved);
            }
        } catch (e) {
            console.warn('Failed to load profiles:', e);
        }
        
        // Get current profile
        if (this.profiles.length === 0) {
            this.currentProfile = this.createDefaultProfile();
            this.profiles.push(this.currentProfile);
        } else {
            this.currentProfile = this.profiles[0];
        }
    }
    
    /**
     * Create default profile
     */
    createDefaultProfile() {
        return {
            id: 'profile_' + Date.now(),
            name: 'Player',
            level: 15,
            xp: 2500,
            coins: 12500,
            gems: 150,
            avatarFrame: 'default',
            title: 'racer',
            theme: 'default',
            stats: {
                totalRaces: 47,
                wins: 18,
                bestScore: 125000,
                totalDistance: 450000,
                playTime: 7200,
                totalCrystals: 5420,
                achievements: 12
            },
            created: new Date().toISOString()
        };
    }
    
    /**
     * Edit player name
     */
    editPlayerName() {
        // For now, cycle through some names
        const names = ['Player', 'Racer', 'SpeedKing', 'NightRider', 'VelocityX'];
        const currentIndex = names.indexOf(this.currentProfile.name);
        const nextIndex = (currentIndex + 1) % names.length;
        this.currentProfile.name = names[nextIndex];
        this.playerNameText.setText(this.currentProfile.name);
        this.playClickSound();
    }
    
    /**
     * Select avatar frame
     */
    selectAvatarFrame(frameId) {
        this.currentProfile.avatarFrame = frameId;
        this.playClickSound();
        // Refresh header
        this.headerContainer.destroy();
        this.createProfileHeader(this.cameras.main.width);
    }
    
    /**
     * Select title
     */
    selectTitle(titleId) {
        this.currentProfile.title = titleId;
        this.playClickSound();
        this.showContent('customize');
    }
    
    /**
     * Select theme
     */
    selectTheme(themeId) {
        this.currentProfile.theme = themeId;
        this.playClickSound();
    }
    
    /**
     * Show profile switcher
     */
    showProfileSwitcher() {
        this.playClickSound();
        // TODO: Implement profile switcher modal
    }
    
    /**
     * Go back to previous scene
     */
    goBack() {
        this.playClickSound();
        this.saveProfile();
        this.cameras.main.fadeOut(300);
        this.time.delayedCall(300, () => {
            this.scene.start(this.returnScene);
        });
    }
    
    /**
     * Save current profile
     */
    saveProfile() {
        try {
            const index = this.profiles.findIndex(p => p.id === this.currentProfile.id);
            if (index >= 0) {
                this.profiles[index] = this.currentProfile;
            }
            localStorage.setItem('gravshift_profiles', JSON.stringify(this.profiles));
        } catch (e) {
            console.warn('Failed to save profile:', e);
        }
    }
    
    /**
     * Setup input handlers
     */
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => {
            this.goBack();
        });
        
        this.input.keyboard.on('keydown-ONE', () => this.selectTab('overview'));
        this.input.keyboard.on('keydown-TWO', () => this.selectTab('customize'));
        this.input.keyboard.on('keydown-THREE', () => this.selectTab('achievements'));
        this.input.keyboard.on('keydown-FOUR', () => this.selectTab('history'));
    }
    
    /**
     * Format number with commas
     */
    formatNumber(num) {
        return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }
    
    /**
     * Play click sound
     */
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
    
    /**
     * Play tab sound
     */
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
    
    /**
     * Update loop
     */
    update(time, delta) {
        this.animationTimer += delta;
        
        // Update particles
        this.updateParticles(delta);
    }
    
    /**
     * Update background particles
     */
    updateParticles(delta) {
        if (!this.particleGraphics) return;
        
        this.particleGraphics.clear();
        
        const height = this.cameras.main.height;
        
        this.particles.forEach(particle => {
            particle.y -= particle.speed * delta * 0.05;
            
            if (particle.y < 0) {
                particle.y = height;
                particle.x = Math.random() * this.cameras.main.width;
            }
            
            this.particleGraphics.fillStyle(particle.color, particle.alpha);
            this.particleGraphics.fillCircle(particle.x, particle.y, particle.size);
        });
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.ProfileScene = ProfileScene;
}
