/**
 * DailyChallengeScene.js
 * Scene for displaying and playing daily challenges
 * Part of GRAVSHIFT - A gravity-defying racing game
 */

class DailyChallengeScene extends Phaser.Scene {
    constructor() {
        super({ key: 'DailyChallengeScene' });
        
        // Scene state
        this.currentChallenge = null;
        this.challengeHistory = [];
        this.streakData = null;
        this.selectedTab = 'today';
        this.isLoading = false;
        
        // UI elements
        this.container = null;
        this.tabButtons = [];
        this.challengeCard = null;
        this.historyList = null;
        this.rewardsPanel = null;
        this.streakDisplay = null;
        
        // Animation state
        this.animationTimer = 0;
        this.cardPulse = 0;
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
            streak: 0xff00ff
        };
        
        // Challenge types with icons
        this.challengeTypes = {
            distance: { icon: '🛣️', color: 0x00aaff },
            score: { icon: '⭐', color: 0xffd700 },
            time: { icon: '⏱️', color: 0x00ffaa },
            collection: { icon: '💎', color: 0xff00ff },
            survival: { icon: '❤️', color: 0xff4444 },
            skill: { icon: '🎯', color: 0xffaa00 }
        };
        
        // Difficulty colors
        this.difficultyColors = {
            easy: 0x00ff00,
            medium: 0xffaa00,
            hard: 0xff4444,
            extreme: 0xff00ff
        };
    }
    
    /**
     * Initialize scene with data
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
        this.preSelectedTab = data.tab || 'today';
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
        
        // Title
        this.createTitle(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Streak display
        this.createStreakDisplay(width);
        
        // Content area
        this.createContentArea(width, height);
        
        // Back button
        this.createBackButton();
        
        // Load data
        this.loadChallengeData();
        
        // Select initial tab
        this.selectTab(this.preSelectedTab);
        
        // Input handlers
        this.setupInput();
        
        // Play ambient sound
        this.playAmbientSound();
        
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
        for (let i = 0; i < 50; i++) {
            this.particles.push({
                x: Math.random() * width,
                y: Math.random() * height,
                size: Math.random() * 3 + 1,
                speed: Math.random() * 0.5 + 0.2,
                alpha: Math.random() * 0.5 + 0.2,
                color: Math.random() > 0.5 ? this.colors.accent : this.colors.streak
            });
        }
        
        // Particle graphics
        this.particleGraphics = this.add.graphics();
        
        // Calendar grid pattern
        const grid = this.add.graphics();
        grid.lineStyle(1, 0x333355, 0.1);
        
        const gridSize = 40;
        for (let x = 0; x < width; x += gridSize) {
            grid.lineBetween(x, 0, x, height);
        }
        for (let y = 0; y < height; y += gridSize) {
            grid.lineBetween(0, y, width, y);
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
        
        // Calendar icon
        const calendarIcon = this.add.text(30, 40, '📅', {
            fontSize: '36px'
        }).setOrigin(0, 0.5);
        this.container.add(calendarIcon);
        
        // Title text
        const title = this.add.text(80, 30, 'DAILY CHALLENGE', {
            fontSize: '32px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.container.add(title);
        
        // Subtitle with date
        const today = new Date();
        const dateStr = today.toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
        
        const subtitle = this.add.text(80, 55, dateStr, {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.container.add(subtitle);
        
        // Refresh timer
        this.createRefreshTimer(width);
    }
    
    /**
     * Create refresh countdown timer
     */
    createRefreshTimer(width) {
        // Timer container
        const timerContainer = this.add.container(width - 30, 40);
        
        // Background
        const timerBg = this.add.graphics();
        timerBg.fillStyle(this.colors.panelLight, 0.8);
        timerBg.fillRoundedRect(-120, -25, 120, 50, 10);
        timerContainer.add(timerBg);
        
        // Label
        const timerLabel = this.add.text(-110, -15, 'RESETS IN', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        timerContainer.add(timerLabel);
        
        // Time display
        this.refreshTimeText = this.add.text(-60, 8, '00:00:00', {
            fontSize: '20px',
            fontFamily: 'Courier New',
            color: '#' + this.colors.accent.toString(16)
        }).setOrigin(0.5, 0.5);
        timerContainer.add(this.refreshTimeText);
        
        this.container.add(timerContainer);
        
        // Update timer
        this.updateRefreshTimer();
        this.time.addEvent({
            delay: 1000,
            callback: this.updateRefreshTimer,
            callbackScope: this,
            loop: true
        });
    }
    
    /**
     * Update refresh countdown
     */
    updateRefreshTimer() {
        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);
        
        const diff = tomorrow - now;
        const hours = Math.floor(diff / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((diff % (1000 * 60)) / 1000);
        
        if (this.refreshTimeText) {
            this.refreshTimeText.setText(
                `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
            );
        }
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabs = [
            { key: 'today', label: "TODAY'S CHALLENGE", icon: '🎯' },
            { key: 'history', label: 'HISTORY', icon: '📜' },
            { key: 'rewards', label: 'REWARDS', icon: '🎁' },
            { key: 'leaderboard', label: 'LEADERBOARD', icon: '🏆' }
        ];
        
        const tabWidth = (width - 40) / tabs.length;
        const startX = 20;
        const y = 100;
        
        this.tabContainer = this.add.container(0, y);
        
        tabs.forEach((tab, index) => {
            const x = startX + index * tabWidth;
            
            // Tab background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, 0, tabWidth - 5, 40, { tl: 10, tr: 10, bl: 0, br: 0 });
            this.tabContainer.add(bg);
            
            // Tab text
            const text = this.add.text(x + tabWidth / 2, 20, `${tab.icon} ${tab.label}`, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#888899'
            }).setOrigin(0.5, 0.5);
            this.tabContainer.add(text);
            
            // Interactive zone
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
        
        // Update tab visuals
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
        
        // Show content
        this.showContent(key);
        
        // Play sound
        this.playTabSound();
    }
    
    /**
     * Create streak display
     */
    createStreakDisplay(width) {
        this.streakContainer = this.add.container(width / 2, 165);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.panel, 0.8);
        bg.fillRoundedRect(-200, -25, 400, 50, 25);
        bg.lineStyle(2, this.colors.streak, 0.5);
        bg.strokeRoundedRect(-200, -25, 400, 50, 25);
        this.streakContainer.add(bg);
        
        // Flame icon
        const flameIcon = this.add.text(-180, 0, '🔥', {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        this.streakContainer.add(flameIcon);
        
        // Streak count
        this.streakCountText = this.add.text(-140, -5, '0', {
            fontSize: '24px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.streak.toString(16)
        }).setOrigin(0, 0.5);
        this.streakContainer.add(this.streakCountText);
        
        // Streak label
        this.streakLabelText = this.add.text(-140, 15, 'DAY STREAK', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.streakContainer.add(this.streakLabelText);
        
        // Bonus multiplier
        const bonusBg = this.add.graphics();
        bonusBg.fillStyle(this.colors.gold, 0.2);
        bonusBg.fillRoundedRect(50, -15, 130, 30, 15);
        this.streakContainer.add(bonusBg);
        
        this.bonusText = this.add.text(115, 0, '1.0x BONUS', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.gold.toString(16)
        }).setOrigin(0.5, 0.5);
        this.streakContainer.add(this.bonusText);
        
        this.container.add(this.streakContainer);
    }
    
    /**
     * Create main content area
     */
    createContentArea(width, height) {
        this.contentContainer = this.add.container(0, 200);
        
        // Content background
        const contentBg = this.add.graphics();
        contentBg.fillStyle(this.colors.panel, 0.5);
        contentBg.fillRoundedRect(20, 0, width - 40, height - 260, 15);
        this.contentContainer.add(contentBg);
        
        this.container.add(this.contentContainer);
    }
    
    /**
     * Show content for selected tab
     */
    showContent(key) {
        // Clear existing content
        this.clearContent();
        
        switch (key) {
            case 'today':
                this.showTodayChallenge();
                break;
            case 'history':
                this.showHistory();
                break;
            case 'rewards':
                this.showRewards();
                break;
            case 'leaderboard':
                this.showLeaderboard();
                break;
        }
    }
    
    /**
     * Clear content area
     */
    clearContent() {
        // Remove all children except background
        const children = [...this.contentContainer.list];
        children.forEach((child, index) => {
            if (index > 0) {
                child.destroy();
            }
        });
    }
    
    /**
     * Show today's challenge
     */
    showTodayChallenge() {
        const width = this.cameras.main.width;
        const challenge = this.currentChallenge;
        
        if (!challenge) {
            this.showNoChallenge();
            return;
        }
        
        // Challenge card
        const cardX = width / 2;
        const cardY = 150;
        
        // Card background with gradient
        const card = this.add.graphics();
        card.fillGradientStyle(
            this.colors.panelLight, this.colors.panelLight,
            this.colors.panel, this.colors.panel
        );
        card.fillRoundedRect(cardX - 250, cardY - 120, 500, 240, 20);
        
        // Difficulty border
        const diffColor = this.difficultyColors[challenge.difficulty] || this.colors.accent;
        card.lineStyle(3, diffColor, 1);
        card.strokeRoundedRect(cardX - 250, cardY - 120, 500, 240, 20);
        this.contentContainer.add(card);
        
        // Challenge type icon
        const typeInfo = this.challengeTypes[challenge.type] || { icon: '🎮', color: 0xffffff };
        const typeIcon = this.add.text(cardX, cardY - 80, typeInfo.icon, {
            fontSize: '48px'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(typeIcon);
        
        // Challenge name
        const name = this.add.text(cardX, cardY - 30, challenge.name, {
            fontSize: '24px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(name);
        
        // Challenge description
        const desc = this.add.text(cardX, cardY + 5, challenge.description, {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16),
            align: 'center',
            wordWrap: { width: 400 }
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(desc);
        
        // Difficulty badge
        const diffBadge = this.add.graphics();
        diffBadge.fillStyle(diffColor, 0.3);
        diffBadge.fillRoundedRect(cardX - 50, cardY + 40, 100, 25, 12);
        this.contentContainer.add(diffBadge);
        
        const diffText = this.add.text(cardX, cardY + 52, challenge.difficulty.toUpperCase(), {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#' + diffColor.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(diffText);
        
        // Progress bar
        this.createProgressBar(cardX, cardY + 90, challenge);
        
        // Rewards section
        this.createRewardsSection(cardX, cardY + 170, challenge);
        
        // Play button
        if (!challenge.completed) {
            this.createPlayButton(cardX, cardY + 250);
        } else {
            this.createCompletedBadge(cardX, cardY + 250);
        }
        
        // Requirements
        this.createRequirements(cardX, cardY + 320, challenge);
    }
    
    /**
     * Create progress bar
     */
    createProgressBar(x, y, challenge) {
        const barWidth = 400;
        const barHeight = 20;
        
        // Background
        const barBg = this.add.graphics();
        barBg.fillStyle(0x000000, 0.5);
        barBg.fillRoundedRect(x - barWidth / 2, y - barHeight / 2, barWidth, barHeight, barHeight / 2);
        this.contentContainer.add(barBg);
        
        // Progress
        const progress = Math.min(challenge.progress / challenge.target, 1);
        if (progress > 0) {
            const progressBar = this.add.graphics();
            progressBar.fillStyle(challenge.completed ? this.colors.success : this.colors.accent, 1);
            progressBar.fillRoundedRect(
                x - barWidth / 2, y - barHeight / 2,
                barWidth * progress, barHeight,
                barHeight / 2
            );
            this.contentContainer.add(progressBar);
        }
        
        // Progress text
        const progressText = this.add.text(x, y, `${challenge.progress} / ${challenge.target}`, {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(progressText);
    }
    
    /**
     * Create rewards section
     */
    createRewardsSection(x, y, challenge) {
        // Rewards label
        const label = this.add.text(x, y - 25, 'REWARDS', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(label);
        
        // Rewards
        const rewards = challenge.rewards || [];
        const rewardWidth = 80;
        const totalWidth = rewards.length * rewardWidth;
        const startX = x - totalWidth / 2 + rewardWidth / 2;
        
        rewards.forEach((reward, index) => {
            const rx = startX + index * rewardWidth;
            
            // Reward background
            const rewardBg = this.add.graphics();
            rewardBg.fillStyle(this.colors.panelLight, 0.8);
            rewardBg.fillRoundedRect(rx - 35, y - 10, 70, 40, 8);
            this.contentContainer.add(rewardBg);
            
            // Reward icon
            const icon = this.getRewardIcon(reward.type);
            const rewardIcon = this.add.text(rx - 20, y + 10, icon, {
                fontSize: '16px'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(rewardIcon);
            
            // Reward amount
            const amount = this.add.text(rx + 10, y + 10, this.formatNumber(reward.amount), {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(amount);
        });
    }
    
    /**
     * Get reward icon
     */
    getRewardIcon(type) {
        const icons = {
            coins: '🪙',
            gems: '💎',
            xp: '⭐',
            skin: '🎨',
            vehicle: '🚗',
            boost: '⚡',
            mystery: '🎁'
        };
        return icons[type] || '🎁';
    }
    
    /**
     * Create play button
     */
    createPlayButton(x, y) {
        // Button background
        const button = this.add.graphics();
        button.fillStyle(this.colors.accent, 1);
        button.fillRoundedRect(x - 100, y - 25, 200, 50, 25);
        this.contentContainer.add(button);
        
        // Button text
        const buttonText = this.add.text(x, y, '▶ PLAY CHALLENGE', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(buttonText);
        
        // Interactive zone
        const zone = this.add.zone(x, y, 200, 50)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                button.clear();
                button.fillStyle(0x00ffcc, 1);
                button.fillRoundedRect(x - 100, y - 25, 200, 50, 25);
            })
            .on('pointerout', () => {
                button.clear();
                button.fillStyle(this.colors.accent, 1);
                button.fillRoundedRect(x - 100, y - 25, 200, 50, 25);
            })
            .on('pointerdown', () => {
                this.startChallenge();
            });
        this.contentContainer.add(zone);
    }
    
    /**
     * Create completed badge
     */
    createCompletedBadge(x, y) {
        // Badge background
        const badge = this.add.graphics();
        badge.fillStyle(this.colors.success, 0.2);
        badge.fillRoundedRect(x - 100, y - 25, 200, 50, 25);
        badge.lineStyle(2, this.colors.success, 1);
        badge.strokeRoundedRect(x - 100, y - 25, 200, 50, 25);
        this.contentContainer.add(badge);
        
        // Badge text
        const badgeText = this.add.text(x, y, '✓ COMPLETED', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.success.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(badgeText);
    }
    
    /**
     * Create requirements section
     */
    createRequirements(x, y, challenge) {
        const requirements = challenge.requirements || [];
        if (requirements.length === 0) return;
        
        // Label
        const label = this.add.text(x, y, 'REQUIREMENTS', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(label);
        
        // Requirements list
        requirements.forEach((req, index) => {
            const reqY = y + 25 + index * 20;
            
            const reqText = this.add.text(x, reqY, `• ${req}`, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(reqText);
        });
    }
    
    /**
     * Show no challenge message
     */
    showNoChallenge() {
        const width = this.cameras.main.width;
        
        const message = this.add.text(width / 2, 150, '⏳ Loading challenge...', {
            fontSize: '20px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(message);
    }
    
    /**
     * Show challenge history
     */
    showHistory() {
        const width = this.cameras.main.width;
        
        // History header
        const header = this.add.text(40, 20, 'Challenge History', {
            fontSize: '20px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // History stats
        this.createHistoryStats(width);
        
        // History list
        this.createHistoryList(width);
        
        // Calendar view
        this.createCalendarView(width);
    }
    
    /**
     * Create history statistics
     */
    createHistoryStats(width) {
        const stats = [
            { label: 'COMPLETED', value: this.challengeHistory.filter(c => c.completed).length, icon: '✓' },
            { label: 'TOTAL', value: this.challengeHistory.length, icon: '📋' },
            { label: 'SUCCESS RATE', value: this.calculateSuccessRate() + '%', icon: '📈' },
            { label: 'BEST STREAK', value: this.streakData?.best || 0, icon: '🔥' }
        ];
        
        const statWidth = (width - 80) / stats.length;
        
        stats.forEach((stat, index) => {
            const x = 40 + index * statWidth;
            
            // Stat background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, 0.5);
            bg.fillRoundedRect(x, 60, statWidth - 10, 60, 10);
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(x + 15, 90, stat.icon, {
                fontSize: '20px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(icon);
            
            // Value
            const value = this.add.text(x + statWidth - 20, 80, stat.value.toString(), {
                fontSize: '24px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(1, 0.5);
            this.contentContainer.add(value);
            
            // Label
            const label = this.add.text(x + statWidth - 20, 102, stat.label, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(1, 0.5);
            this.contentContainer.add(label);
        });
    }
    
    /**
     * Calculate success rate
     */
    calculateSuccessRate() {
        if (this.challengeHistory.length === 0) return 0;
        const completed = this.challengeHistory.filter(c => c.completed).length;
        return Math.round((completed / this.challengeHistory.length) * 100);
    }
    
    /**
     * Create history list
     */
    createHistoryList(width) {
        const startY = 140;
        const itemHeight = 50;
        
        // List header
        const listHeader = this.add.text(40, startY, 'Recent Challenges', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(listHeader);
        
        // List items
        const displayHistory = this.challengeHistory.slice(0, 7);
        
        displayHistory.forEach((challenge, index) => {
            const y = startY + 30 + index * itemHeight;
            
            // Item background
            const itemBg = this.add.graphics();
            itemBg.fillStyle(this.colors.panelLight, 0.3);
            itemBg.fillRoundedRect(40, y, width / 2 - 60, itemHeight - 5, 8);
            this.contentContainer.add(itemBg);
            
            // Status icon
            const statusIcon = this.add.text(55, y + (itemHeight - 5) / 2, 
                challenge.completed ? '✓' : '✗', {
                fontSize: '16px',
                color: challenge.completed ? '#00ff00' : '#ff4444'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(statusIcon);
            
            // Challenge name
            const name = this.add.text(85, y + 12, challenge.name, {
                fontSize: '14px',
                fontFamily: 'Arial',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(name);
            
            // Date
            const date = this.add.text(85, y + 30, challenge.date, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(date);
            
            // Reward earned
            if (challenge.completed && challenge.rewardEarned) {
                const reward = this.add.text(width / 2 - 80, y + (itemHeight - 5) / 2, 
                    `+${challenge.rewardEarned} 🪙`, {
                    fontSize: '12px',
                    fontFamily: 'Arial Black',
                    color: '#' + this.colors.gold.toString(16)
                }).setOrigin(1, 0.5);
                this.contentContainer.add(reward);
            }
        });
    }
    
    /**
     * Create calendar view
     */
    createCalendarView(width) {
        const calX = width / 2 + 20;
        const calY = 140;
        const cellSize = 30;
        const cols = 7;
        const rows = 5;
        
        // Calendar header
        const calHeader = this.add.text(calX, calY, 'This Month', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(calHeader);
        
        // Day labels
        const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
        days.forEach((day, index) => {
            const dayLabel = this.add.text(calX + 15 + index * cellSize, calY + 30, day, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(dayLabel);
        });
        
        // Calendar grid
        const today = new Date();
        const firstDay = new Date(today.getFullYear(), today.getMonth(), 1).getDay();
        const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
        
        let dayNum = 1;
        
        for (let row = 0; row < rows; row++) {
            for (let col = 0; col < cols; col++) {
                const cellX = calX + 15 + col * cellSize;
                const cellY = calY + 50 + row * cellSize;
                
                if ((row === 0 && col < firstDay) || dayNum > daysInMonth) {
                    continue;
                }
                
                // Cell background
                const cell = this.add.graphics();
                const isToday = dayNum === today.getDate();
                const hasChallenge = this.challengeHistory.some(c => {
                    const d = new Date(c.date);
                    return d.getDate() === dayNum && d.getMonth() === today.getMonth();
                });
                const completed = this.challengeHistory.some(c => {
                    const d = new Date(c.date);
                    return d.getDate() === dayNum && d.getMonth() === today.getMonth() && c.completed;
                });
                
                if (isToday) {
                    cell.fillStyle(this.colors.accent, 0.3);
                    cell.lineStyle(2, this.colors.accent, 1);
                } else if (completed) {
                    cell.fillStyle(this.colors.success, 0.2);
                } else if (hasChallenge) {
                    cell.fillStyle(this.colors.error, 0.2);
                } else {
                    cell.fillStyle(this.colors.panelLight, 0.3);
                }
                
                cell.fillRoundedRect(cellX - cellSize / 2 + 2, cellY - cellSize / 2 + 2, cellSize - 4, cellSize - 4, 5);
                if (isToday) {
                    cell.strokeRoundedRect(cellX - cellSize / 2 + 2, cellY - cellSize / 2 + 2, cellSize - 4, cellSize - 4, 5);
                }
                this.contentContainer.add(cell);
                
                // Day number
                const dayText = this.add.text(cellX, cellY, dayNum.toString(), {
                    fontSize: '12px',
                    fontFamily: isToday ? 'Arial Black' : 'Arial',
                    color: isToday ? '#ffffff' : '#aaaaaa'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(dayText);
                
                dayNum++;
            }
        }
        
        // Legend
        this.createCalendarLegend(calX, calY + 210);
    }
    
    /**
     * Create calendar legend
     */
    createCalendarLegend(x, y) {
        const items = [
            { color: this.colors.success, label: 'Completed' },
            { color: this.colors.error, label: 'Missed' },
            { color: this.colors.accent, label: 'Today' }
        ];
        
        items.forEach((item, index) => {
            const itemX = x + index * 80;
            
            const dot = this.add.graphics();
            dot.fillStyle(item.color, 0.5);
            dot.fillCircle(itemX, y, 5);
            this.contentContainer.add(dot);
            
            const label = this.add.text(itemX + 12, y, item.label, {
                fontSize: '10px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(label);
        });
    }
    
    /**
     * Show rewards tab
     */
    showRewards() {
        const width = this.cameras.main.width;
        
        // Rewards header
        const header = this.add.text(40, 20, 'Streak Rewards', {
            fontSize: '20px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Current streak info
        this.createCurrentStreakInfo(width);
        
        // Reward milestones
        this.createRewardMilestones(width);
        
        // Special rewards
        this.createSpecialRewards(width);
    }
    
    /**
     * Create current streak info
     */
    createCurrentStreakInfo(width) {
        // Background
        const bg = this.add.graphics();
        bg.fillGradientStyle(
            this.colors.streak, 0x8800ff,
            0x4400aa, 0x220055
        );
        bg.fillRoundedRect(40, 60, width - 80, 100, 15);
        this.contentContainer.add(bg);
        
        // Flame animation
        const flame = this.add.text(80, 110, '🔥', {
            fontSize: '48px'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(flame);
        
        // Animate flame
        this.tweens.add({
            targets: flame,
            scaleX: 1.2,
            scaleY: 1.2,
            duration: 500,
            yoyo: true,
            repeat: -1,
            ease: 'Sine.easeInOut'
        });
        
        // Streak count
        const currentStreak = this.streakData?.current || 0;
        const streakCount = this.add.text(150, 95, currentStreak.toString(), {
            fontSize: '48px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(streakCount);
        
        // Label
        const streakLabel = this.add.text(150, 130, 'DAY STREAK', {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(streakLabel);
        
        // Bonus multiplier
        const bonusMultiplier = Math.min(1 + (currentStreak * 0.1), 2.5);
        const bonusText = this.add.text(width - 100, 110, `${bonusMultiplier.toFixed(1)}x\nBONUS`, {
            fontSize: '24px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.gold.toString(16),
            align: 'center'
        }).setOrigin(0.5, 0.5);
        this.contentContainer.add(bonusText);
    }
    
    /**
     * Create reward milestones
     */
    createRewardMilestones(width) {
        const milestones = [
            { days: 3, reward: '500 Coins', icon: '🪙', claimed: true },
            { days: 7, reward: 'Rare Skin', icon: '🎨', claimed: false },
            { days: 14, reward: '2000 Coins', icon: '🪙', claimed: false },
            { days: 30, reward: 'Epic Vehicle', icon: '🚗', claimed: false },
            { days: 60, reward: 'Legendary Skin', icon: '👑', claimed: false }
        ];
        
        const startY = 180;
        const currentStreak = this.streakData?.current || 0;
        
        // Label
        const label = this.add.text(40, startY, 'Milestones', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(label);
        
        // Milestone items
        milestones.forEach((milestone, index) => {
            const y = startY + 35 + index * 45;
            const isReached = currentStreak >= milestone.days;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(isReached ? this.colors.accent : this.colors.panelLight, isReached ? 0.2 : 0.3);
            bg.fillRoundedRect(40, y, width - 80, 40, 8);
            
            if (isReached && !milestone.claimed) {
                bg.lineStyle(2, this.colors.accent, 1);
                bg.strokeRoundedRect(40, y, width - 80, 40, 8);
            }
            this.contentContainer.add(bg);
            
            // Icon
            const icon = this.add.text(60, y + 20, milestone.icon, {
                fontSize: '20px'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(icon);
            
            // Days
            const days = this.add.text(95, y + 12, `${milestone.days} Days`, {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: isReached ? '#ffffff' : '#888899'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(days);
            
            // Reward
            const reward = this.add.text(95, y + 28, milestone.reward, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(reward);
            
            // Status
            if (milestone.claimed) {
                const claimed = this.add.text(width - 60, y + 20, '✓ CLAIMED', {
                    fontSize: '12px',
                    fontFamily: 'Arial Black',
                    color: '#' + this.colors.success.toString(16)
                }).setOrigin(1, 0.5);
                this.contentContainer.add(claimed);
            } else if (isReached) {
                // Claim button
                const claimBtn = this.add.graphics();
                claimBtn.fillStyle(this.colors.accent, 1);
                claimBtn.fillRoundedRect(width - 140, y + 8, 80, 24, 12);
                this.contentContainer.add(claimBtn);
                
                const claimText = this.add.text(width - 100, y + 20, 'CLAIM', {
                    fontSize: '12px',
                    fontFamily: 'Arial Black',
                    color: '#000000'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(claimText);
            } else {
                // Progress
                const progress = this.add.text(width - 60, y + 20, 
                    `${currentStreak}/${milestone.days}`, {
                    fontSize: '12px',
                    fontFamily: 'Arial',
                    color: '#' + this.colors.textDim.toString(16)
                }).setOrigin(1, 0.5);
                this.contentContainer.add(progress);
            }
        });
    }
    
    /**
     * Create special rewards section
     */
    createSpecialRewards(width) {
        const startY = 420;
        
        // Label
        const label = this.add.text(40, startY, 'Special Bonuses', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.textDim.toString(16)
        });
        this.contentContainer.add(label);
        
        // Weekend bonus
        const weekendBg = this.add.graphics();
        weekendBg.fillStyle(this.colors.gold, 0.2);
        weekendBg.fillRoundedRect(40, startY + 25, (width - 90) / 2, 60, 10);
        this.contentContainer.add(weekendBg);
        
        const weekendIcon = this.add.text(60, startY + 55, '🌟', {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(weekendIcon);
        
        const weekendTitle = this.add.text(95, startY + 45, 'Weekend Bonus', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.gold.toString(16)
        }).setOrigin(0, 0.5);
        this.contentContainer.add(weekendTitle);
        
        const weekendDesc = this.add.text(95, startY + 65, '2x rewards on weekends!', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(weekendDesc);
        
        // Perfect month bonus
        const perfectBg = this.add.graphics();
        perfectBg.fillStyle(this.colors.streak, 0.2);
        perfectBg.fillRoundedRect(width / 2 + 5, startY + 25, (width - 90) / 2, 60, 10);
        this.contentContainer.add(perfectBg);
        
        const perfectIcon = this.add.text(width / 2 + 25, startY + 55, '👑', {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(perfectIcon);
        
        const perfectTitle = this.add.text(width / 2 + 60, startY + 45, 'Perfect Month', {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.streak.toString(16)
        }).setOrigin(0, 0.5);
        this.contentContainer.add(perfectTitle);
        
        const perfectDesc = this.add.text(width / 2 + 60, startY + 65, 'Complete every day for epic loot!', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#ffffff'
        }).setOrigin(0, 0.5);
        this.contentContainer.add(perfectDesc);
    }
    
    /**
     * Show leaderboard tab
     */
    showLeaderboard() {
        const width = this.cameras.main.width;
        
        // Leaderboard header
        const header = this.add.text(40, 20, 'Challenge Leaderboard', {
            fontSize: '20px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.contentContainer.add(header);
        
        // Period selector
        this.createPeriodSelector(width);
        
        // Top 3 podium
        this.createPodium(width);
        
        // Leaderboard list
        this.createLeaderboardList(width);
        
        // Player rank
        this.createPlayerRank(width);
    }
    
    /**
     * Create period selector
     */
    createPeriodSelector(width) {
        const periods = ['Today', 'This Week', 'This Month', 'All Time'];
        const buttonWidth = 80;
        const startX = width / 2 - (periods.length * buttonWidth) / 2;
        
        periods.forEach((period, index) => {
            const x = startX + index * buttonWidth;
            const isSelected = index === 0;
            
            const bg = this.add.graphics();
            bg.fillStyle(isSelected ? this.colors.accent : this.colors.panelLight, isSelected ? 1 : 0.5);
            bg.fillRoundedRect(x, 50, buttonWidth - 5, 30, 15);
            this.contentContainer.add(bg);
            
            const text = this.add.text(x + (buttonWidth - 5) / 2, 65, period, {
                fontSize: '10px',
                fontFamily: 'Arial Black',
                color: isSelected ? '#000000' : '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(text);
        });
    }
    
    /**
     * Create podium display
     */
    createPodium(width) {
        const topPlayers = this.generateMockLeaderboard().slice(0, 3);
        const podiumY = 150;
        
        // Positions: 2nd, 1st, 3rd
        const positions = [
            { place: 2, x: width / 2 - 120, height: 80, color: this.colors.silver },
            { place: 1, x: width / 2, height: 100, color: this.colors.gold },
            { place: 3, x: width / 2 + 120, height: 60, color: this.colors.bronze }
        ];
        
        positions.forEach((pos, index) => {
            const player = topPlayers[pos.place - 1];
            if (!player) return;
            
            // Podium
            const podium = this.add.graphics();
            podium.fillStyle(pos.color, 0.5);
            podium.fillRoundedRect(pos.x - 45, podiumY + 100 - pos.height, 90, pos.height, { tl: 10, tr: 10, bl: 0, br: 0 });
            this.contentContainer.add(podium);
            
            // Place number
            const placeText = this.add.text(pos.x, podiumY + 100 - pos.height + 20, pos.place.toString(), {
                fontSize: '24px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(placeText);
            
            // Avatar
            const avatar = this.add.graphics();
            avatar.fillStyle(pos.color, 1);
            avatar.fillCircle(pos.x, podiumY + 100 - pos.height - 30, 25);
            avatar.lineStyle(3, 0xffffff, 0.5);
            avatar.strokeCircle(pos.x, podiumY + 100 - pos.height - 30, 25);
            this.contentContainer.add(avatar);
            
            // Crown for 1st place
            if (pos.place === 1) {
                const crown = this.add.text(pos.x, podiumY + 100 - pos.height - 60, '👑', {
                    fontSize: '20px'
                }).setOrigin(0.5, 0.5);
                this.contentContainer.add(crown);
            }
            
            // Player name
            const name = this.add.text(pos.x, podiumY + 110, player.name, {
                fontSize: '12px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(name);
            
            // Score
            const score = this.add.text(pos.x, podiumY + 128, this.formatNumber(player.score), {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: '#' + pos.color.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(score);
        });
    }
    
    /**
     * Create leaderboard list
     */
    createLeaderboardList(width) {
        const players = this.generateMockLeaderboard().slice(3, 10);
        const startY = 280;
        
        players.forEach((player, index) => {
            const y = startY + index * 40;
            const rank = index + 4;
            
            // Background
            const bg = this.add.graphics();
            bg.fillStyle(this.colors.panelLight, player.isPlayer ? 0.8 : 0.3);
            bg.fillRoundedRect(40, y, width - 80, 35, 8);
            
            if (player.isPlayer) {
                bg.lineStyle(2, this.colors.accent, 1);
                bg.strokeRoundedRect(40, y, width - 80, 35, 8);
            }
            this.contentContainer.add(bg);
            
            // Rank
            const rankText = this.add.text(60, y + 17, `#${rank}`, {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: '#' + this.colors.textDim.toString(16)
            }).setOrigin(0, 0.5);
            this.contentContainer.add(rankText);
            
            // Name
            const name = this.add.text(110, y + 17, player.name, {
                fontSize: '14px',
                fontFamily: 'Arial',
                color: player.isPlayer ? '#' + this.colors.accent.toString(16) : '#ffffff'
            }).setOrigin(0, 0.5);
            this.contentContainer.add(name);
            
            // Streak
            const streak = this.add.text(width - 150, y + 17, `🔥 ${player.streak}`, {
                fontSize: '12px',
                fontFamily: 'Arial',
                color: '#' + this.colors.streak.toString(16)
            }).setOrigin(0.5, 0.5);
            this.contentContainer.add(streak);
            
            // Score
            const score = this.add.text(width - 60, y + 17, this.formatNumber(player.score), {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: '#ffffff'
            }).setOrigin(1, 0.5);
            this.contentContainer.add(score);
        });
    }
    
    /**
     * Create player rank display
     */
    createPlayerRank(width) {
        const y = 560;
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(this.colors.accent, 0.1);
        bg.fillRoundedRect(40, y, width - 80, 50, 10);
        bg.lineStyle(2, this.colors.accent, 0.5);
        bg.strokeRoundedRect(40, y, width - 80, 50, 10);
        this.contentContainer.add(bg);
        
        // Your rank label
        const label = this.add.text(60, y + 25, 'YOUR RANK', {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#' + this.colors.textDim.toString(16)
        }).setOrigin(0, 0.5);
        this.contentContainer.add(label);
        
        // Rank number
        const rank = this.add.text(150, y + 25, '#42', {
            fontSize: '24px',
            fontFamily: 'Arial Black',
            color: '#' + this.colors.accent.toString(16)
        }).setOrigin(0, 0.5);
        this.contentContainer.add(rank);
        
        // Score
        const score = this.add.text(width - 60, y + 25, '12,450', {
            fontSize: '20px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        }).setOrigin(1, 0.5);
        this.contentContainer.add(score);
    }
    
    /**
     * Generate mock leaderboard data
     */
    generateMockLeaderboard() {
        const names = [
            'NightRider', 'SpeedDemon', 'GravMaster', 'VelocityX',
            'DriftKing', 'ShadowRacer', 'NeonBlaze', 'CyberPilot',
            'QuantumDrift', 'StellarAce'
        ];
        
        return names.map((name, index) => ({
            name,
            score: Math.floor(50000 / (index + 1)),
            streak: Math.max(30 - index * 3, 1),
            isPlayer: index === 5
        }));
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
     * Load challenge data
     */
    loadChallengeData() {
        // Generate today's challenge
        this.currentChallenge = this.generateDailyChallenge();
        
        // Load history
        this.challengeHistory = this.loadHistory();
        
        // Load streak data
        this.streakData = this.loadStreakData();
        
        // Update streak display
        this.updateStreakDisplay();
    }
    
    /**
     * Generate daily challenge based on date
     */
    generateDailyChallenge() {
        const today = new Date();
        const seed = today.getFullYear() * 10000 + (today.getMonth() + 1) * 100 + today.getDate();
        
        const challenges = [
            {
                type: 'distance',
                name: 'Road Warrior',
                description: 'Travel a total distance of 10,000 meters',
                target: 10000,
                difficulty: 'medium',
                requirements: ['Any vehicle', 'Any track'],
                rewards: [
                    { type: 'coins', amount: 500 },
                    { type: 'xp', amount: 200 }
                ]
            },
            {
                type: 'score',
                name: 'Point Hunter',
                description: 'Earn 50,000 points in a single run',
                target: 50000,
                difficulty: 'hard',
                requirements: ['Score multipliers enabled'],
                rewards: [
                    { type: 'coins', amount: 1000 },
                    { type: 'gems', amount: 50 }
                ]
            },
            {
                type: 'collection',
                name: 'Crystal Collector',
                description: 'Collect 100 crystals',
                target: 100,
                difficulty: 'easy',
                requirements: [],
                rewards: [
                    { type: 'coins', amount: 300 },
                    { type: 'xp', amount: 100 }
                ]
            },
            {
                type: 'survival',
                name: 'Survivor',
                description: 'Survive for 5 minutes without dying',
                target: 300,
                difficulty: 'medium',
                requirements: ['No shield power-ups'],
                rewards: [
                    { type: 'coins', amount: 750 },
                    { type: 'boost', amount: 3 }
                ]
            },
            {
                type: 'skill',
                name: 'Gravity Master',
                description: 'Perform 20 perfect gravity shifts',
                target: 20,
                difficulty: 'hard',
                requirements: ['Perfect timing required'],
                rewards: [
                    { type: 'coins', amount: 1500 },
                    { type: 'xp', amount: 500 }
                ]
            }
        ];
        
        // Select challenge based on seed
        const index = seed % challenges.length;
        const challenge = { ...challenges[index] };
        
        // Load progress from storage
        const saved = this.loadTodayProgress();
        challenge.progress = saved.progress || 0;
        challenge.completed = saved.completed || false;
        
        return challenge;
    }
    
    /**
     * Load today's progress from storage
     */
    loadTodayProgress() {
        try {
            const today = new Date().toDateString();
            const saved = localStorage.getItem('gravshift_daily_progress');
            if (saved) {
                const data = JSON.parse(saved);
                if (data.date === today) {
                    return data;
                }
            }
        } catch (e) {
            console.warn('Failed to load daily progress:', e);
        }
        return { progress: 0, completed: false };
    }
    
    /**
     * Load challenge history
     */
    loadHistory() {
        try {
            const saved = localStorage.getItem('gravshift_challenge_history');
            if (saved) {
                return JSON.parse(saved);
            }
        } catch (e) {
            console.warn('Failed to load challenge history:', e);
        }
        
        // Generate mock history
        return this.generateMockHistory();
    }
    
    /**
     * Generate mock history
     */
    generateMockHistory() {
        const history = [];
        const today = new Date();
        
        for (let i = 1; i <= 14; i++) {
            const date = new Date(today);
            date.setDate(date.getDate() - i);
            
            history.push({
                name: ['Road Warrior', 'Point Hunter', 'Crystal Collector', 'Survivor', 'Gravity Master'][i % 5],
                date: date.toLocaleDateString(),
                completed: Math.random() > 0.3,
                rewardEarned: Math.floor(Math.random() * 1000) + 200
            });
        }
        
        return history;
    }
    
    /**
     * Load streak data
     */
    loadStreakData() {
        try {
            const saved = localStorage.getItem('gravshift_streak_data');
            if (saved) {
                return JSON.parse(saved);
            }
        } catch (e) {
            console.warn('Failed to load streak data:', e);
        }
        
        return {
            current: 5,
            best: 12,
            lastCompleted: new Date().toDateString()
        };
    }
    
    /**
     * Update streak display
     */
    updateStreakDisplay() {
        if (this.streakCountText && this.streakData) {
            this.streakCountText.setText(this.streakData.current.toString());
            
            const multiplier = Math.min(1 + (this.streakData.current * 0.1), 2.5);
            this.bonusText.setText(`${multiplier.toFixed(1)}x BONUS`);
        }
    }
    
    /**
     * Start challenge
     */
    startChallenge() {
        this.playClickSound();
        
        // Store challenge info
        this.registry.set('dailyChallenge', this.currentChallenge);
        
        // Transition to game
        this.cameras.main.fadeOut(300);
        this.time.delayedCall(300, () => {
            this.scene.start('GameScene', { 
                mode: 'challenge',
                challenge: this.currentChallenge 
            });
        });
    }
    
    /**
     * Go back to previous scene
     */
    goBack() {
        this.playClickSound();
        this.cameras.main.fadeOut(300);
        this.time.delayedCall(300, () => {
            this.scene.start(this.returnScene);
        });
    }
    
    /**
     * Setup input handlers
     */
    setupInput() {
        // ESC to go back
        this.input.keyboard.on('keydown-ESC', () => {
            this.goBack();
        });
        
        // Tab navigation with number keys
        this.input.keyboard.on('keydown-ONE', () => this.selectTab('today'));
        this.input.keyboard.on('keydown-TWO', () => this.selectTab('history'));
        this.input.keyboard.on('keydown-THREE', () => this.selectTab('rewards'));
        this.input.keyboard.on('keydown-FOUR', () => this.selectTab('leaderboard'));
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
     * Play tab switch sound
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
     * Play ambient sound
     */
    playAmbientSound() {
        // Optional ambient pad
    }
    
    /**
     * Update loop
     */
    update(time, delta) {
        this.animationTimer += delta;
        this.cardPulse = Math.sin(this.animationTimer * 0.003) * 0.5 + 0.5;
        
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
            // Move particle
            particle.y -= particle.speed * delta * 0.05;
            
            // Wrap around
            if (particle.y < 0) {
                particle.y = height;
                particle.x = Math.random() * this.cameras.main.width;
            }
            
            // Draw particle
            this.particleGraphics.fillStyle(particle.color, particle.alpha);
            this.particleGraphics.fillCircle(particle.x, particle.y, particle.size);
        });
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.DailyChallengeScene = DailyChallengeScene;
}
