/**
 * LeaderboardScene.js
 * Global and local leaderboard display
 * Shows rankings, player comparisons, and competitive stats
 */

class LeaderboardScene extends Phaser.Scene {
    constructor() {
        super({ key: 'LeaderboardScene' });
        
        // State
        this.currentTab = 'global';
        this.tabs = ['global', 'friends', 'local', 'weekly'];
        this.currentLevel = 'all';
        this.levels = ['all', 'level_1', 'level_2', 'level_3', 'level_4', 'level_5'];
        this.scrollOffset = 0;
        this.maxScroll = 0;
        this.selectedEntry = null;
        
        // Data
        this.leaderboardData = null;
        this.playerRank = null;
        this.rivalData = null;
    }
    
    /**
     * Initialize scene
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
        this.initialLevel = data.level || 'all';
        this.currentLevel = this.initialLevel;
    }
    
    /**
     * Create scene elements
     */
    create() {
        const { width, height } = this.cameras.main;
        
        // Load leaderboard data
        this.loadLeaderboardData();
        
        // Background
        this.createBackground(width, height);
        
        // Header
        this.createHeader(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Level filter
        this.createLevelFilter(width);
        
        // Player rank display
        this.createPlayerRankDisplay(width);
        
        // Leaderboard list
        this.listContainer = this.add.container(0, 230);
        this.renderLeaderboard();
        
        // Back button
        this.createBackButton(width, height);
        
        // Input
        this.setupInput();
        
        // Animation
        this.animateIn();
    }
    
    /**
     * Load leaderboard data
     */
    loadLeaderboardData() {
        // In production, this would fetch from server
        // For now, generate mock data
        this.leaderboardData = this.generateMockLeaderboard();
        this.playerRank = this.findPlayerRank();
        this.rivalData = this.findRivals();
    }
    
    /**
     * Generate mock leaderboard data
     */
    generateMockLeaderboard() {
        const names = [
            'SpeedDemon', 'GravityKing', 'NeonRacer', 'DriftMaster', 'TurboNinja',
            'SonicBolt', 'StarChaser', 'VoidRunner', 'QuantumPilot', 'NightRider',
            'FlameShift', 'IceBreaker', 'ThunderBolt', 'ShadowDrift', 'CosmicRay',
            'LaserFox', 'PixelRacer', 'NeonWolf', 'CyberHawk', 'ElectroKid',
            'VelocityX', 'MachFive', 'HyperDrive', 'BlazeTrain', 'StormChaser'
        ];
        
        const countries = ['US', 'JP', 'DE', 'GB', 'FR', 'KR', 'BR', 'AU', 'CA', 'SE'];
        
        const entries = [];
        let baseScore = 2500000;
        
        for (let i = 0; i < 100; i++) {
            const isPlayer = i === 23; // Player at rank 24
            
            entries.push({
                rank: i + 1,
                name: isPlayer ? 'YOU' : names[i % names.length] + (i >= names.length ? i : ''),
                score: Math.floor(baseScore - (i * 15000) + Math.random() * 5000),
                level: `level_${Math.floor(Math.random() * 5) + 1}`,
                country: countries[Math.floor(Math.random() * countries.length)],
                vehicle: ['racer', 'tank', 'speeder', 'drifter'][Math.floor(Math.random() * 4)],
                date: Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000,
                isPlayer: isPlayer,
                isFriend: Math.random() > 0.8,
                isRival: Math.random() > 0.95
            });
        }
        
        return entries;
    }
    
    /**
     * Find player's rank in current leaderboard
     */
    findPlayerRank() {
        const playerEntry = this.leaderboardData.find(e => e.isPlayer);
        if (playerEntry) {
            return {
                rank: playerEntry.rank,
                score: playerEntry.score,
                totalPlayers: this.leaderboardData.length,
                percentile: Math.round((1 - playerEntry.rank / this.leaderboardData.length) * 100)
            };
        }
        return { rank: 0, score: 0, totalPlayers: 0, percentile: 0 };
    }
    
    /**
     * Find rival entries
     */
    findRivals() {
        const playerEntry = this.leaderboardData.find(e => e.isPlayer);
        if (!playerEntry) return { above: null, below: null };
        
        const above = this.leaderboardData.find(e => e.rank === playerEntry.rank - 1);
        const below = this.leaderboardData.find(e => e.rank === playerEntry.rank + 1);
        
        return { above, below };
    }
    
    /**
     * Create background
     */
    createBackground(width, height) {
        const graphics = this.add.graphics();
        
        // Gradient
        for (let y = 0; y < height; y++) {
            const t = y / height;
            const r = Math.floor(5 + t * 15);
            const g = Math.floor(10 + t * 25);
            const b = Math.floor(25 + t * 35);
            graphics.fillStyle(Phaser.Display.Color.GetColor(r, g, b), 1);
            graphics.fillRect(0, y, width, 1);
        }
        
        // Decorative lines
        graphics.lineStyle(1, 0x00ffff, 0.1);
        for (let x = 0; x < width; x += 50) {
            graphics.lineBetween(x, 0, x + 100, height);
        }
        
        // Trophy decoration
        this.createTrophyDecoration(graphics, width);
    }
    
    /**
     * Create decorative trophy
     */
    createTrophyDecoration(graphics, width) {
        // Simple geometric trophy shape
        const cx = width - 50;
        const cy = 120;
        
        graphics.lineStyle(2, 0xffaa00, 0.2);
        graphics.strokeCircle(cx, cy, 40);
        graphics.strokeCircle(cx, cy, 35);
        
        graphics.fillStyle(0xffaa00, 0.05);
        graphics.fillCircle(cx, cy, 30);
    }
    
    /**
     * Create header
     */
    createHeader(width) {
        const headerBg = this.add.graphics();
        headerBg.fillStyle(0x0a1020, 0.95);
        headerBg.fillRect(0, 0, width, 70);
        headerBg.lineStyle(2, 0xffaa00, 0.5);
        headerBg.lineBetween(0, 70, width, 70);
        
        // Trophy icon
        const trophy = this.add.graphics();
        trophy.fillStyle(0xffaa00, 0.9);
        trophy.fillTriangle(30, 45, 50, 25, 70, 45);
        trophy.fillRect(40, 45, 20, 10);
        trophy.fillRect(35, 55, 30, 5);
        
        // Title
        this.add.text(90, 35, 'LEADERBOARDS', {
            fontFamily: 'Arial Black',
            fontSize: '28px',
            color: '#ffaa00',
            stroke: '#553300',
            strokeThickness: 3
        }).setOrigin(0, 0.5);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabWidth = width / this.tabs.length;
        const tabY = 80;
        
        this.tabElements = [];
        
        this.tabs.forEach((tab, index) => {
            const x = index * tabWidth;
            const active = tab === this.currentTab;
            
            const bg = this.add.graphics();
            this.drawTabBackground(bg, x, tabY, tabWidth, 35, active);
            
            const text = this.add.text(x + tabWidth / 2, tabY + 17, tab.toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#ffaa00' : '#667788'
            }).setOrigin(0.5);
            
            const zone = this.add.zone(x + tabWidth / 2, tabY + 17, tabWidth, 35)
                .setInteractive({ useHandCursor: true });
            
            zone.on('pointerdown', () => this.selectTab(tab));
            zone.on('pointerover', () => {
                if (tab !== this.currentTab) text.setColor('#aabbcc');
            });
            zone.on('pointerout', () => {
                if (tab !== this.currentTab) text.setColor('#667788');
            });
            
            this.tabElements.push({ bg, text, tab });
        });
    }
    
    /**
     * Draw tab background
     */
    drawTabBackground(graphics, x, y, width, height, active) {
        graphics.clear();
        
        if (active) {
            graphics.fillStyle(0x1a2535, 1);
            graphics.lineStyle(2, 0xffaa00, 0.8);
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
            this.drawTabBackground(elem.bg, index * tabWidth, 80, tabWidth, 35, active);
            elem.text.setColor(active ? '#ffaa00' : '#667788');
        });
        
        this.renderLeaderboard();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Create level filter
     */
    createLevelFilter(width) {
        const y = 125;
        
        this.add.text(20, y, 'LEVEL:', {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        });
        
        this.levelButtons = [];
        let xPos = 70;
        
        this.levels.forEach(level => {
            const active = level === this.currentLevel;
            const label = level === 'all' ? 'ALL' : level.replace('level_', 'L');
            
            const text = this.add.text(xPos, y, label, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: active ? '#ffaa00' : '#445566',
                backgroundColor: active ? '#1a2535' : 'transparent',
                padding: { x: 6, y: 3 }
            }).setInteractive({ useHandCursor: true });
            
            text.on('pointerdown', () => this.selectLevel(level));
            text.on('pointerover', () => {
                if (level !== this.currentLevel) text.setColor('#aabbcc');
            });
            text.on('pointerout', () => {
                if (level !== this.currentLevel) text.setColor('#445566');
            });
            
            this.levelButtons.push({ text, level });
            xPos += text.width + 15;
        });
    }
    
    /**
     * Select a level filter
     */
    selectLevel(level) {
        if (level === this.currentLevel) return;
        
        this.currentLevel = level;
        
        this.levelButtons.forEach(btn => {
            const active = btn.level === level;
            btn.text.setColor(active ? '#ffaa00' : '#445566');
            btn.text.setBackgroundColor(active ? '#1a2535' : 'transparent');
        });
        
        this.renderLeaderboard();
    }
    
    /**
     * Create player rank display
     */
    createPlayerRankDisplay(width) {
        const y = 155;
        const container = this.add.container(0, y);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(0x1a2535, 0.9);
        bg.fillRect(20, 0, width - 40, 65);
        bg.lineStyle(2, 0x00ffff, 0.5);
        bg.strokeRect(20, 0, width - 40, 65);
        container.add(bg);
        
        // Your rank label
        const yourRank = this.add.text(35, 10, 'YOUR RANK', {
            fontFamily: 'Arial',
            fontSize: '10px',
            color: '#667788'
        });
        container.add(yourRank);
        
        // Rank number
        const rankNum = this.add.text(35, 28, `#${this.playerRank.rank}`, {
            fontFamily: 'Arial Black',
            fontSize: '24px',
            color: '#00ffff'
        });
        container.add(rankNum);
        
        // Percentile
        const percentile = this.add.text(120, 28, `Top ${100 - this.playerRank.percentile}%`, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ff88'
        }).setOrigin(0, 0.5);
        container.add(percentile);
        
        // Score
        const scoreLabel = this.add.text(width - 130, 10, 'SCORE', {
            fontFamily: 'Arial',
            fontSize: '10px',
            color: '#667788'
        });
        container.add(scoreLabel);
        
        const scoreValue = this.add.text(width - 130, 28, this.formatScore(this.playerRank.score), {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#ffffff'
        });
        container.add(scoreValue);
        
        // Rival info
        if (this.rivalData.above) {
            const rivalText = this.add.text(width / 2, 50, 
                `${this.formatScore(this.rivalData.above.score - this.playerRank.score)} pts to beat #${this.rivalData.above.rank}`, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#ffaa00'
            }).setOrigin(0.5);
            container.add(rivalText);
        }
    }
    
    /**
     * Render the leaderboard list
     */
    renderLeaderboard() {
        this.listContainer.removeAll(true);
        
        const { width, height } = this.cameras.main;
        
        // Filter data
        let filteredData = [...this.leaderboardData];
        
        if (this.currentLevel !== 'all') {
            filteredData = filteredData.filter(e => e.level === this.currentLevel);
        }
        
        if (this.currentTab === 'friends') {
            filteredData = filteredData.filter(e => e.isFriend || e.isPlayer);
        } else if (this.currentTab === 'weekly') {
            // Filter to last 7 days
            const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
            filteredData = filteredData.filter(e => e.date >= weekAgo);
        }
        
        // Re-rank after filtering
        filteredData.forEach((entry, index) => {
            entry.displayRank = index + 1;
        });
        
        // Render entries
        const entryHeight = 50;
        
        filteredData.slice(0, 50).forEach((entry, index) => {
            const y = index * entryHeight;
            const entryContainer = this.createLeaderboardEntry(entry, y, width - 40, entryHeight - 5);
            this.listContainer.add(entryContainer);
        });
        
        // Calculate max scroll
        const contentHeight = filteredData.length * entryHeight;
        const viewHeight = height - 280;
        this.maxScroll = Math.max(0, contentHeight - viewHeight);
        
        // Reset scroll
        this.scrollOffset = 0;
        this.listContainer.y = 230;
    }
    
    /**
     * Create a leaderboard entry
     */
    createLeaderboardEntry(entry, y, width, height) {
        const container = this.add.container(20, y);
        
        // Background
        const bg = this.add.graphics();
        
        let bgColor = 0x0a1525;
        let borderColor = 0x334455;
        let borderAlpha = 0.3;
        
        if (entry.isPlayer) {
            bgColor = 0x1a3050;
            borderColor = 0x00ffff;
            borderAlpha = 0.8;
        } else if (entry.displayRank <= 3) {
            bgColor = 0x1a2535;
            borderColor = [0xffd700, 0xc0c0c0, 0xcd7f32][entry.displayRank - 1];
            borderAlpha = 0.6;
        } else if (entry.isRival) {
            borderColor = 0xff4488;
            borderAlpha = 0.5;
        }
        
        bg.fillStyle(bgColor, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 5);
        bg.lineStyle(2, borderColor, borderAlpha);
        bg.strokeRoundedRect(0, 0, width, height, 5);
        container.add(bg);
        
        // Rank
        const rankColor = entry.displayRank <= 3 
            ? ['#ffd700', '#c0c0c0', '#cd7f32'][entry.displayRank - 1]
            : '#667788';
        
        const rankText = this.add.text(15, height / 2, `#${entry.displayRank}`, {
            fontFamily: 'Arial Black',
            fontSize: entry.displayRank <= 3 ? '16px' : '14px',
            color: rankColor
        }).setOrigin(0, 0.5);
        container.add(rankText);
        
        // Medal for top 3
        if (entry.displayRank <= 3) {
            const medal = this.add.graphics();
            const medalColors = [0xffd700, 0xc0c0c0, 0xcd7f32];
            medal.fillStyle(medalColors[entry.displayRank - 1], 0.8);
            medal.fillCircle(55, height / 2, 10);
            medal.fillStyle(0xffffff, 0.3);
            medal.fillCircle(53, height / 2 - 2, 4);
            container.add(medal);
        }
        
        // Name
        const nameX = entry.displayRank <= 3 ? 75 : 55;
        const name = this.add.text(nameX, height / 2 - 8, entry.name, {
            fontFamily: entry.isPlayer ? 'Arial Black' : 'Arial',
            fontSize: '14px',
            color: entry.isPlayer ? '#00ffff' : '#ffffff'
        });
        container.add(name);
        
        // Country and vehicle
        const subInfo = this.add.text(nameX, height / 2 + 8, 
            `${entry.country} • ${entry.vehicle}`, {
            fontFamily: 'Arial',
            fontSize: '10px',
            color: '#556677'
        });
        container.add(subInfo);
        
        // Score
        const score = this.add.text(width - 15, height / 2, this.formatScore(entry.score), {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: entry.isPlayer ? '#00ffff' : '#ffaa00'
        }).setOrigin(1, 0.5);
        container.add(score);
        
        // Make interactive
        const zone = this.add.zone(width / 2, height / 2, width, height)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.selectEntry(entry));
        zone.on('pointerover', () => {
            if (!entry.isPlayer) {
                bg.clear();
                bg.fillStyle(0x1a2535, 0.95);
                bg.fillRoundedRect(0, 0, width, height, 5);
                bg.lineStyle(2, borderColor, 0.8);
                bg.strokeRoundedRect(0, 0, width, height, 5);
            }
        });
        zone.on('pointerout', () => {
            if (!entry.isPlayer) {
                bg.clear();
                bg.fillStyle(bgColor, 0.9);
                bg.fillRoundedRect(0, 0, width, height, 5);
                bg.lineStyle(2, borderColor, borderAlpha);
                bg.strokeRoundedRect(0, 0, width, height, 5);
            }
        });
        
        container.add(zone);
        
        return container;
    }
    
    /**
     * Select a leaderboard entry
     */
    selectEntry(entry) {
        if (entry.isPlayer) return;
        
        this.selectedEntry = entry;
        this.showEntryDetails(entry);
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Show detailed info for an entry
     */
    showEntryDetails(entry) {
        // Create overlay
        const { width, height } = this.cameras.main;
        
        const overlay = this.add.graphics();
        overlay.fillStyle(0x000000, 0.8);
        overlay.fillRect(0, 0, width, height);
        
        const panel = this.add.container(width / 2, height / 2);
        
        // Panel background
        const panelBg = this.add.graphics();
        panelBg.fillStyle(0x0a1525, 0.98);
        panelBg.fillRoundedRect(-150, -120, 300, 240, 10);
        panelBg.lineStyle(2, 0xffaa00, 0.8);
        panelBg.strokeRoundedRect(-150, -120, 300, 240, 10);
        panel.add(panelBg);
        
        // Title
        const title = this.add.text(0, -95, entry.name, {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#ffffff'
        }).setOrigin(0.5);
        panel.add(title);
        
        // Rank badge
        const rankBadge = this.add.graphics();
        rankBadge.fillStyle(0x1a3050, 1);
        rankBadge.fillRoundedRect(-60, -70, 120, 30, 5);
        panel.add(rankBadge);
        
        const rankText = this.add.text(0, -55, `RANK #${entry.displayRank}`, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffaa00'
        }).setOrigin(0.5);
        panel.add(rankText);
        
        // Stats
        const stats = [
            { label: 'Score', value: this.formatScore(entry.score) },
            { label: 'Country', value: entry.country },
            { label: 'Vehicle', value: entry.vehicle.toUpperCase() },
            { label: 'Best Level', value: entry.level.replace('_', ' ').toUpperCase() }
        ];
        
        stats.forEach((stat, index) => {
            const y = -25 + index * 30;
            
            const label = this.add.text(-130, y, stat.label, {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#667788'
            });
            panel.add(label);
            
            const value = this.add.text(130, y, stat.value, {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#ffffff'
            }).setOrigin(1, 0);
            panel.add(value);
        });
        
        // Close button
        const closeBtn = this.add.text(0, 100, 'CLOSE', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff',
            backgroundColor: '#1a3050',
            padding: { x: 20, y: 8 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        closeBtn.on('pointerdown', () => {
            overlay.destroy();
            panel.destroy();
            this.selectedEntry = null;
        });
        
        closeBtn.on('pointerover', () => closeBtn.setColor('#ffffff'));
        closeBtn.on('pointerout', () => closeBtn.setColor('#00ffff'));
        
        panel.add(closeBtn);
        
        // Click outside to close
        overlay.setInteractive(new Phaser.Geom.Rectangle(0, 0, width, height), Phaser.Geom.Rectangle.Contains);
        overlay.on('pointerdown', () => {
            overlay.destroy();
            panel.destroy();
            this.selectedEntry = null;
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
        bg.lineStyle(2, 0xffaa00, 0.5);
        bg.strokeRoundedRect(0, 0, 60, 35, 5);
        
        const text = this.add.text(30, 17, 'BACK', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ffaa00'
        }).setOrigin(0.5);
        
        const zone = this.add.zone(30, 17, 60, 35)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.goBack());
        zone.on('pointerover', () => {
            bg.clear();
            bg.fillStyle(0x2a3545, 0.9);
            bg.fillRoundedRect(0, 0, 60, 35, 5);
            bg.lineStyle(2, 0xffaa00, 0.8);
            bg.strokeRoundedRect(0, 0, 60, 35, 5);
        });
        zone.on('pointerout', () => {
            bg.clear();
            bg.fillStyle(0x1a2535, 0.9);
            bg.fillRoundedRect(0, 0, 60, 35, 5);
            bg.lineStyle(2, 0xffaa00, 0.5);
            bg.strokeRoundedRect(0, 0, 60, 35, 5);
        });
        
        container.add([bg, text, zone]);
    }
    
    /**
     * Setup input handling
     */
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => {
            if (this.selectedEntry) {
                // Close detail panel handled by overlay
            } else {
                this.goBack();
            }
        });
        
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            this.scrollOffset = Phaser.Math.Clamp(
                this.scrollOffset + deltaY * 0.5,
                0,
                this.maxScroll
            );
            this.listContainer.y = 230 - this.scrollOffset;
        });
    }
    
    /**
     * Go back to previous scene
     */
    goBack() {
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
     * Format score for display
     */
    formatScore(score) {
        if (score >= 1000000) {
            return (score / 1000000).toFixed(2) + 'M';
        } else if (score >= 1000) {
            return (score / 1000).toFixed(1) + 'K';
        }
        return String(score);
    }
    
    /**
     * Update loop
     */
    update(time, delta) {
        // Any animations
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.LeaderboardScene = LeaderboardScene;
}
