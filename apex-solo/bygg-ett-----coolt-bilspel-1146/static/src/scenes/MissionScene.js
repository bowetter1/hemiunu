/**
 * MissionScene.js
 * Mission/Quest display and management scene
 * Shows available missions, progress, and rewards
 */

class MissionScene extends Phaser.Scene {
    constructor() {
        super({ key: 'MissionScene' });
        
        // UI state
        this.currentTab = 'story';
        this.tabs = ['story', 'side', 'daily', 'weekly'];
        this.scrollOffset = 0;
        this.maxScroll = 0;
        this.selectedMission = null;
        
        // Data
        this.missions = null;
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
        
        // Load missions
        this.loadMissions();
        
        // Background
        this.createBackground(width, height);
        
        // Header
        this.createHeader(width);
        
        // Tabs
        this.createTabs(width);
        
        // Content area
        this.contentContainer = this.add.container(0, 150);
        this.renderMissionList();
        
        // Mission detail panel (hidden initially)
        this.createDetailPanel(width, height);
        
        // Back button
        this.createBackButton(width, height);
        
        // Rewards button if pending
        this.createRewardsButton(width, height);
        
        // Input
        this.setupInput();
        
        // Animation
        this.animateIn();
    }
    
    /**
     * Load mission data
     */
    loadMissions() {
        if (window.MissionSystem) {
            this.missions = {
                story: MissionSystem.getAvailableMissionsByType('story'),
                side: MissionSystem.getAvailableMissionsByType('side'),
                daily: MissionSystem.getAvailableMissionsByType('daily'),
                weekly: MissionSystem.getAvailableMissionsByType('weekly'),
                active: MissionSystem.getActiveMissions(),
                completed: MissionSystem.completedMissions
            };
        } else {
            // Mock data
            this.missions = this.generateMockMissions();
        }
    }
    
    /**
     * Generate mock mission data
     */
    generateMockMissions() {
        return {
            story: [
                {
                    id: 'story_1',
                    name: 'First Steps',
                    description: 'Complete your first race',
                    type: 'story',
                    chapter: 1,
                    objectives: [{ type: 'complete_race', count: 1, progress: 0 }],
                    rewards: { coins: 500, xp: 100 }
                },
                {
                    id: 'story_2',
                    name: 'Gravity Master',
                    description: 'Survive 30 seconds without hitting obstacles',
                    type: 'story',
                    chapter: 1,
                    objectives: [{ type: 'survive_clean', seconds: 30, progress: 15 }],
                    rewards: { coins: 750, xp: 150, unlocks: ['level_2'] }
                }
            ],
            side: [
                {
                    id: 'side_distance',
                    name: 'Long Run',
                    description: 'Travel 10,000 meters total',
                    type: 'side',
                    category: 'distance',
                    objectives: [{ type: 'total_distance', distance: 10000, progress: 4500 }],
                    rewards: { coins: 500, xp: 100 }
                }
            ],
            daily: [
                {
                    id: 'daily_play',
                    name: 'Daily Racer',
                    description: 'Complete 3 races today',
                    type: 'daily',
                    objectives: [{ type: 'daily_races', count: 3, progress: 1 }],
                    rewards: { coins: 200, xp: 50 }
                }
            ],
            weekly: [
                {
                    id: 'weekly_distance',
                    name: 'Weekly Traveler',
                    description: 'Travel 50,000 meters this week',
                    type: 'weekly',
                    objectives: [{ type: 'weekly_distance', distance: 50000, progress: 12000 }],
                    rewards: { coins: 1500, xp: 300 }
                }
            ],
            active: [],
            completed: []
        };
    }
    
    /**
     * Create background
     */
    createBackground(width, height) {
        const graphics = this.add.graphics();
        
        // Gradient
        for (let y = 0; y < height; y++) {
            const t = y / height;
            const r = Math.floor(8 + t * 12);
            const g = Math.floor(12 + t * 18);
            const b = Math.floor(28 + t * 22);
            graphics.fillStyle(Phaser.Display.Color.GetColor(r, g, b), 1);
            graphics.fillRect(0, y, width, 1);
        }
        
        // Decorative elements
        graphics.lineStyle(1, 0x00ffff, 0.1);
        for (let i = 0; i < 20; i++) {
            const x = Math.random() * width;
            const y = Math.random() * height;
            graphics.strokeCircle(x, y, Math.random() * 50 + 20);
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
        
        // Mission icon
        const icon = this.add.graphics();
        icon.fillStyle(0x00ffff, 0.8);
        icon.fillCircle(40, 35, 15);
        icon.fillStyle(0x0a1020, 1);
        icon.fillCircle(40, 35, 8);
        icon.fillStyle(0x00ffff, 0.8);
        icon.fillCircle(40, 35, 4);
        
        // Title
        this.add.text(70, 35, 'MISSIONS', {
            fontFamily: 'Arial Black',
            fontSize: '28px',
            color: '#00ffff',
            stroke: '#004455',
            strokeThickness: 3
        }).setOrigin(0, 0.5);
        
        // Active count
        const activeCount = this.missions.active.length;
        this.add.text(width - 20, 35, `${activeCount} Active`, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffaa00'
        }).setOrigin(1, 0.5);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabWidth = width / this.tabs.length;
        const tabY = 85;
        
        this.tabElements = [];
        
        this.tabs.forEach((tab, index) => {
            const x = index * tabWidth;
            const active = tab === this.currentTab;
            
            const bg = this.add.graphics();
            this.drawTabBg(bg, x, tabY, tabWidth, 40, active);
            
            // Count missions in tab
            const count = this.missions[tab]?.length || 0;
            const label = `${tab.toUpperCase()} (${count})`;
            
            const text = this.add.text(x + tabWidth / 2, tabY + 20, label, {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#00ffff' : '#667788'
            }).setOrigin(0.5);
            
            const zone = this.add.zone(x + tabWidth / 2, tabY + 20, tabWidth, 40)
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
            
            const count = this.missions[elem.tab]?.length || 0;
            elem.text.setText(`${elem.tab.toUpperCase()} (${count})`);
            elem.text.setColor(active ? '#00ffff' : '#667788');
        });
        
        this.renderMissionList();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Render mission list
     */
    renderMissionList() {
        this.contentContainer.removeAll(true);
        
        const { width, height } = this.cameras.main;
        const missions = this.missions[this.currentTab] || [];
        
        if (missions.length === 0) {
            const emptyText = this.add.text(width / 2, 100, 'No missions available', {
                fontFamily: 'Arial',
                fontSize: '16px',
                color: '#667788'
            }).setOrigin(0.5);
            this.contentContainer.add(emptyText);
            return;
        }
        
        const itemHeight = 100;
        
        missions.forEach((mission, index) => {
            const y = index * (itemHeight + 10);
            const item = this.createMissionItem(mission, y, width - 40, itemHeight);
            this.contentContainer.add(item);
        });
        
        this.maxScroll = Math.max(0, missions.length * (itemHeight + 10) - (height - 250));
    }
    
    /**
     * Create a mission item
     */
    createMissionItem(mission, y, width, height) {
        const container = this.add.container(20, y);
        
        // Check if mission is active
        const isActive = this.missions.active.some(m => m.id === mission.id);
        const isCompleted = this.missions.completed.includes(mission.id);
        
        // Background
        const bg = this.add.graphics();
        
        let bgColor = 0x0a1525;
        let borderColor = 0x334455;
        
        if (isCompleted) {
            bgColor = 0x0a2520;
            borderColor = 0x00ff88;
        } else if (isActive) {
            bgColor = 0x0a2535;
            borderColor = 0x00ffff;
        }
        
        bg.fillStyle(bgColor, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 8);
        bg.lineStyle(2, borderColor, 0.6);
        bg.strokeRoundedRect(0, 0, width, height, 8);
        container.add(bg);
        
        // Status indicator
        const statusIndicator = this.add.graphics();
        if (isCompleted) {
            statusIndicator.fillStyle(0x00ff88, 1);
        } else if (isActive) {
            statusIndicator.fillStyle(0x00ffff, 1);
        } else {
            statusIndicator.fillStyle(0x667788, 1);
        }
        statusIndicator.fillRoundedRect(0, 0, 5, height, { tl: 8, bl: 8, tr: 0, br: 0 });
        container.add(statusIndicator);
        
        // Mission type badge
        const typeBadge = this.add.graphics();
        const typeColor = this.getMissionTypeColor(mission.type);
        typeBadge.fillStyle(typeColor, 0.8);
        typeBadge.fillRoundedRect(15, 10, 60, 20, 4);
        container.add(typeBadge);
        
        const typeText = this.add.text(45, 20, mission.type.toUpperCase(), {
            fontFamily: 'Arial',
            fontSize: '10px',
            color: '#ffffff'
        }).setOrigin(0.5);
        container.add(typeText);
        
        // Mission name
        const name = this.add.text(90, 15, mission.name, {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: isCompleted ? '#00ff88' : '#ffffff'
        });
        container.add(name);
        
        // Mission description
        const desc = this.add.text(15, 40, mission.description, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#aabbcc',
            wordWrap: { width: width - 30 }
        });
        container.add(desc);
        
        // Progress bar
        const objective = mission.objectives[0];
        let progress = 0;
        let target = 1;
        
        if (objective.count) {
            progress = objective.progress || 0;
            target = objective.count;
        } else if (objective.distance) {
            progress = objective.progress || 0;
            target = objective.distance;
        } else if (objective.seconds) {
            progress = objective.progress || 0;
            target = objective.seconds;
        } else if (objective.score) {
            progress = objective.progress || 0;
            target = objective.score;
        }
        
        const progressPercent = Math.min(1, progress / target);
        
        const barBg = this.add.graphics();
        barBg.fillStyle(0x1a2535, 1);
        barBg.fillRoundedRect(15, 70, width - 150, 12, 6);
        barBg.fillStyle(isCompleted ? 0x00ff88 : 0x00ffff, 0.8);
        barBg.fillRoundedRect(15, 70, (width - 150) * progressPercent, 12, 6);
        container.add(barBg);
        
        const progressText = this.add.text(width - 130, 76, 
            `${this.formatProgress(progress)} / ${this.formatProgress(target)}`, {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        }).setOrigin(0, 0.5);
        container.add(progressText);
        
        // Rewards preview
        const rewardText = this.add.text(width - 15, 20, 
            `+${mission.rewards.coins} coins`, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ffaa00'
        }).setOrigin(1, 0.5);
        container.add(rewardText);
        
        // Completed checkmark
        if (isCompleted) {
            const check = this.add.text(width - 15, 55, '✓', {
                fontSize: '24px',
                color: '#00ff88'
            }).setOrigin(1, 0.5);
            container.add(check);
        }
        
        // Interactive
        const zone = this.add.zone(width / 2, height / 2, width, height)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.showMissionDetail(mission));
        zone.on('pointerover', () => {
            bg.clear();
            bg.fillStyle(0x1a2535, 0.95);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, borderColor, 0.9);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        zone.on('pointerout', () => {
            bg.clear();
            bg.fillStyle(bgColor, 0.9);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, borderColor, 0.6);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        
        container.add(zone);
        
        return container;
    }
    
    /**
     * Get color for mission type
     */
    getMissionTypeColor(type) {
        const colors = {
            story: 0x8844ff,
            side: 0x00aaff,
            daily: 0xffaa00,
            weekly: 0xff4488
        };
        return colors[type] || 0x667788;
    }
    
    /**
     * Format progress value
     */
    formatProgress(value) {
        if (value >= 1000000) {
            return (value / 1000000).toFixed(1) + 'M';
        } else if (value >= 1000) {
            return (value / 1000).toFixed(1) + 'K';
        }
        return String(Math.floor(value));
    }
    
    /**
     * Create mission detail panel
     */
    createDetailPanel(width, height) {
        this.detailPanel = this.add.container(width / 2, height / 2);
        this.detailPanel.setVisible(false);
        this.detailPanel.setDepth(100);
        
        // Overlay
        this.detailOverlay = this.add.graphics();
        this.detailOverlay.fillStyle(0x000000, 0.8);
        this.detailOverlay.fillRect(-width / 2, -height / 2, width, height);
        this.detailOverlay.setInteractive(
            new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height),
            Phaser.Geom.Rectangle.Contains
        );
        this.detailOverlay.on('pointerdown', () => this.hideDetail());
        this.detailPanel.add(this.detailOverlay);
    }
    
    /**
     * Show mission detail
     */
    showMissionDetail(mission) {
        this.selectedMission = mission;
        
        // Clear previous content (except overlay)
        while (this.detailPanel.length > 1) {
            this.detailPanel.removeAt(1, true);
        }
        
        const { width, height } = this.cameras.main;
        const panelWidth = Math.min(400, width - 40);
        const panelHeight = 350;
        
        // Panel background
        const panelBg = this.add.graphics();
        panelBg.fillStyle(0x0a1525, 0.98);
        panelBg.fillRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, 12);
        panelBg.lineStyle(2, 0x00ffff, 0.8);
        panelBg.strokeRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, 12);
        this.detailPanel.add(panelBg);
        
        // Type badge
        const typeColor = this.getMissionTypeColor(mission.type);
        const badge = this.add.graphics();
        badge.fillStyle(typeColor, 0.9);
        badge.fillRoundedRect(-40, -panelHeight / 2 + 20, 80, 24, 4);
        this.detailPanel.add(badge);
        
        const typeText = this.add.text(0, -panelHeight / 2 + 32, mission.type.toUpperCase(), {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ffffff'
        }).setOrigin(0.5);
        this.detailPanel.add(typeText);
        
        // Mission name
        const name = this.add.text(0, -panelHeight / 2 + 65, mission.name, {
            fontFamily: 'Arial Black',
            fontSize: '22px',
            color: '#ffffff'
        }).setOrigin(0.5);
        this.detailPanel.add(name);
        
        // Description
        const desc = this.add.text(0, -panelHeight / 2 + 100, mission.description, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#aabbcc',
            wordWrap: { width: panelWidth - 40 },
            align: 'center'
        }).setOrigin(0.5, 0);
        this.detailPanel.add(desc);
        
        // Objectives section
        const objTitle = this.add.text(-panelWidth / 2 + 20, -panelHeight / 2 + 150, 'OBJECTIVES', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.detailPanel.add(objTitle);
        
        mission.objectives.forEach((obj, index) => {
            const objY = -panelHeight / 2 + 175 + index * 30;
            
            const objText = this.add.text(-panelWidth / 2 + 20, objY, 
                this.formatObjective(obj), {
                fontFamily: 'Arial',
                fontSize: '13px',
                color: '#ffffff'
            });
            this.detailPanel.add(objText);
        });
        
        // Rewards section
        const rewardY = -panelHeight / 2 + 220;
        const rewardTitle = this.add.text(-panelWidth / 2 + 20, rewardY, 'REWARDS', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        this.detailPanel.add(rewardTitle);
        
        let rewardX = -panelWidth / 2 + 20;
        
        if (mission.rewards.coins) {
            const coinReward = this.add.text(rewardX, rewardY + 25, `+${mission.rewards.coins} Coins`, {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#ffaa00'
            });
            this.detailPanel.add(coinReward);
            rewardX += coinReward.width + 20;
        }
        
        if (mission.rewards.xp) {
            const xpReward = this.add.text(rewardX, rewardY + 25, `+${mission.rewards.xp} XP`, {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#00ff88'
            });
            this.detailPanel.add(xpReward);
        }
        
        if (mission.rewards.unlocks && mission.rewards.unlocks.length > 0) {
            const unlockText = this.add.text(0, rewardY + 50, 
                `Unlocks: ${mission.rewards.unlocks.join(', ')}`, {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#00ffff'
            }).setOrigin(0.5);
            this.detailPanel.add(unlockText);
        }
        
        // Action button
        const isActive = this.missions.active.some(m => m.id === mission.id);
        const isCompleted = this.missions.completed.includes(mission.id);
        
        let btnText = 'START MISSION';
        let btnColor = 0x00ffff;
        
        if (isCompleted) {
            btnText = 'COMPLETED';
            btnColor = 0x00ff88;
        } else if (isActive) {
            btnText = 'IN PROGRESS';
            btnColor = 0xffaa00;
        }
        
        const btn = this.add.text(0, panelHeight / 2 - 50, btnText, {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#ffffff',
            backgroundColor: Phaser.Display.Color.IntegerToColor(btnColor).rgba.slice(0, -4),
            padding: { x: 30, y: 12 }
        }).setOrigin(0.5);
        
        if (!isCompleted && !isActive) {
            btn.setInteractive({ useHandCursor: true });
            btn.on('pointerdown', () => this.startMission(mission));
            btn.on('pointerover', () => btn.setAlpha(0.8));
            btn.on('pointerout', () => btn.setAlpha(1));
        }
        
        this.detailPanel.add(btn);
        
        // Close button
        const closeBtn = this.add.text(panelWidth / 2 - 20, -panelHeight / 2 + 20, 'X', {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#667788'
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        closeBtn.on('pointerdown', () => this.hideDetail());
        closeBtn.on('pointerover', () => closeBtn.setColor('#ffffff'));
        closeBtn.on('pointerout', () => closeBtn.setColor('#667788'));
        
        this.detailPanel.add(closeBtn);
        
        // Show panel
        this.detailPanel.setVisible(true);
        this.detailPanel.setAlpha(0);
        this.detailPanel.setScale(0.9);
        
        this.tweens.add({
            targets: this.detailPanel,
            alpha: 1,
            scale: 1,
            duration: 200,
            ease: 'Back.easeOut'
        });
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Format objective for display
     */
    formatObjective(obj) {
        const progress = obj.progress || 0;
        
        switch (obj.type) {
            case 'complete_race':
            case 'daily_races':
                return `Complete ${obj.count} race${obj.count > 1 ? 's' : ''} (${progress}/${obj.count})`;
            case 'survive_clean':
            case 'survive_time_clean':
                return `Survive ${obj.seconds}s without damage (${progress}s)`;
            case 'reach_speed':
                return `Reach ${obj.speed} km/h (${progress} km/h)`;
            case 'reach_combo':
                return `Build a ${obj.combo}x combo (${progress}x)`;
            case 'total_distance':
            case 'weekly_distance':
                return `Travel ${this.formatProgress(obj.distance)}m (${this.formatProgress(progress)}m)`;
            case 'single_score':
            case 'daily_score':
                return `Score ${this.formatProgress(obj.score)} points (${this.formatProgress(progress)})`;
            case 'total_coins':
                return `Collect ${this.formatProgress(obj.coins)} coins (${this.formatProgress(progress)})`;
            case 'total_powerups':
            case 'daily_powerups':
                return `Collect ${obj.count} power-ups (${progress})`;
            default:
                return obj.type;
        }
    }
    
    /**
     * Hide detail panel
     */
    hideDetail() {
        this.tweens.add({
            targets: this.detailPanel,
            alpha: 0,
            scale: 0.9,
            duration: 150,
            onComplete: () => {
                this.detailPanel.setVisible(false);
                this.selectedMission = null;
            }
        });
    }
    
    /**
     * Start a mission
     */
    startMission(mission) {
        if (window.MissionSystem) {
            MissionSystem.activateMission(mission.id);
        }
        
        // Update local data
        this.missions.active.push(mission);
        
        this.hideDetail();
        this.renderMissionList();
        
        if (window.SoundManager) {
            SoundManager.play('ui_confirm');
        }
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
     * Create rewards button if pending
     */
    createRewardsButton(width, height) {
        const hasPending = window.MissionSystem && MissionSystem.pendingRewards.length > 0;
        if (!hasPending) return;
        
        const container = this.add.container(20, height - 50);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x2a3520, 0.9);
        bg.fillRoundedRect(0, 0, 100, 35, 5);
        bg.lineStyle(2, 0x00ff88, 0.8);
        bg.strokeRoundedRect(0, 0, 100, 35, 5);
        
        const text = this.add.text(50, 17, 'CLAIM ALL', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#00ff88'
        }).setOrigin(0.5);
        
        const zone = this.add.zone(50, 17, 100, 35)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.claimRewards());
        
        container.add([bg, text, zone]);
        
        // Pulse animation
        this.tweens.add({
            targets: container,
            scale: 1.05,
            duration: 500,
            yoyo: true,
            repeat: -1
        });
    }
    
    /**
     * Claim all pending rewards
     */
    claimRewards() {
        if (window.MissionSystem) {
            const rewards = MissionSystem.claimRewards();
            this.showRewardsPopup(rewards);
        }
    }
    
    /**
     * Show rewards popup
     */
    showRewardsPopup(rewards) {
        const { width, height } = this.cameras.main;
        
        const popup = this.add.container(width / 2, height / 2);
        popup.setDepth(200);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x0a1525, 0.98);
        bg.fillRoundedRect(-150, -100, 300, 200, 12);
        bg.lineStyle(3, 0x00ff88, 0.9);
        bg.strokeRoundedRect(-150, -100, 300, 200, 12);
        popup.add(bg);
        
        const title = this.add.text(0, -70, 'REWARDS CLAIMED!', {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: '#00ff88'
        }).setOrigin(0.5);
        popup.add(title);
        
        let y = -30;
        
        if (rewards.coins > 0) {
            const coinText = this.add.text(0, y, `+${rewards.coins} Coins`, {
                fontFamily: 'Arial',
                fontSize: '20px',
                color: '#ffaa00'
            }).setOrigin(0.5);
            popup.add(coinText);
            y += 35;
        }
        
        if (rewards.xp > 0) {
            const xpText = this.add.text(0, y, `+${rewards.xp} XP`, {
                fontFamily: 'Arial',
                fontSize: '16px',
                color: '#00ffff'
            }).setOrigin(0.5);
            popup.add(xpText);
            y += 30;
        }
        
        if (rewards.unlocks.length > 0) {
            const unlockText = this.add.text(0, y, `Unlocked: ${rewards.unlocks.join(', ')}`, {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#ff44aa'
            }).setOrigin(0.5);
            popup.add(unlockText);
        }
        
        const okBtn = this.add.text(0, 70, 'AWESOME!', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ff88',
            backgroundColor: '#1a3520',
            padding: { x: 30, y: 10 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        okBtn.on('pointerdown', () => {
            popup.destroy();
            this.scene.restart();
        });
        
        popup.add(okBtn);
        
        // Animation
        popup.setAlpha(0);
        popup.setScale(0.5);
        this.tweens.add({
            targets: popup,
            alpha: 1,
            scale: 1,
            duration: 300,
            ease: 'Back.easeOut'
        });
        
        if (window.SoundManager) {
            SoundManager.play('reward');
        }
    }
    
    /**
     * Setup input
     */
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => {
            if (this.detailPanel.visible) {
                this.hideDetail();
            } else {
                this.goBack();
            }
        });
        
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            if (!this.detailPanel.visible) {
                this.scrollOffset = Phaser.Math.Clamp(
                    this.scrollOffset + deltaY * 0.5,
                    0,
                    this.maxScroll
                );
                this.contentContainer.y = 150 - this.scrollOffset;
            }
        });
    }
    
    /**
     * Go back
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
}

// Register scene
if (typeof window !== 'undefined') {
    window.MissionScene = MissionScene;
}
