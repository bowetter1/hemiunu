/**
 * StatsScene.js
 * Comprehensive player statistics display scene
 * Shows detailed stats, graphs, and historical data
 */

class StatsScene extends Phaser.Scene {
    constructor() {
        super({ key: 'StatsScene' });
        
        // UI state
        this.currentTab = 'overview';
        this.tabs = ['overview', 'races', 'vehicles', 'achievements', 'records'];
        this.scrollOffset = 0;
        this.maxScroll = 0;
        
        // Data containers
        this.stats = null;
        this.graphData = [];
        this.selectedPeriod = 'all';
        this.periods = ['today', 'week', 'month', 'all'];
    }
    
    /**
     * Initialize scene with data
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
    }
    
    /**
     * Create scene elements
     */
    create() {
        const { width, height } = this.cameras.main;
        
        // Load stats
        this.loadStats();
        
        // Background
        this.createBackground(width, height);
        
        // Header
        this.createHeader(width);
        
        // Tab navigation
        this.createTabs(width);
        
        // Period selector
        this.createPeriodSelector(width);
        
        // Content area
        this.contentContainer = this.add.container(0, 180);
        this.renderCurrentTab();
        
        // Back button
        this.createBackButton(width, height);
        
        // Input handling
        this.setupInput();
        
        // Animation
        this.animateIn();
    }
    
    /**
     * Load player statistics from storage
     */
    loadStats() {
        const defaultStats = {
            totalRaces: 0,
            totalDistance: 0,
            totalScore: 0,
            totalPlayTime: 0,
            totalDeaths: 0,
            totalPowerUps: 0,
            totalCoins: 0,
            totalDriftTime: 0,
            totalNearMisses: 0,
            totalPerfectLaps: 0,
            highestCombo: 0,
            longestDrift: 0,
            fastestLap: {},
            bestScores: {},
            vehicleStats: {},
            levelStats: {},
            dailyStats: {},
            weeklyStats: {},
            achievements: [],
            records: [],
            sessionHistory: [],
            firstPlayDate: null,
            lastPlayDate: null
        };
        
        try {
            const saved = localStorage.getItem('gravshift_stats');
            if (saved) {
                this.stats = { ...defaultStats, ...JSON.parse(saved) };
            } else {
                this.stats = defaultStats;
                // Generate mock data for demo
                this.generateMockStats();
            }
        } catch (e) {
            console.error('Failed to load stats:', e);
            this.stats = defaultStats;
            this.generateMockStats();
        }
    }
    
    /**
     * Generate mock statistics for demonstration
     */
    generateMockStats() {
        this.stats.totalRaces = 247;
        this.stats.totalDistance = 1847592;
        this.stats.totalScore = 15847293;
        this.stats.totalPlayTime = 87432;
        this.stats.totalDeaths = 892;
        this.stats.totalPowerUps = 4521;
        this.stats.totalCoins = 284750;
        this.stats.totalDriftTime = 12847;
        this.stats.totalNearMisses = 1847;
        this.stats.totalPerfectLaps = 34;
        this.stats.highestCombo = 847;
        this.stats.longestDrift = 14.7;
        this.stats.firstPlayDate = Date.now() - 30 * 24 * 60 * 60 * 1000;
        this.stats.lastPlayDate = Date.now();
        
        // Level stats
        for (let i = 1; i <= 10; i++) {
            this.stats.levelStats[`level_${i}`] = {
                plays: Math.floor(Math.random() * 50) + 10,
                wins: Math.floor(Math.random() * 30),
                bestScore: Math.floor(Math.random() * 500000) + 100000,
                bestTime: Math.floor(Math.random() * 60) + 30,
                totalDistance: Math.floor(Math.random() * 100000)
            };
        }
        
        // Vehicle stats
        const vehicles = ['racer', 'tank', 'speeder', 'drifter', 'heavy', 'quantum'];
        vehicles.forEach(v => {
            this.stats.vehicleStats[v] = {
                races: Math.floor(Math.random() * 100),
                distance: Math.floor(Math.random() * 500000),
                score: Math.floor(Math.random() * 5000000),
                wins: Math.floor(Math.random() * 50)
            };
        });
        
        // Session history (last 30 days)
        for (let i = 0; i < 30; i++) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            const dateKey = date.toISOString().split('T')[0];
            
            this.stats.dailyStats[dateKey] = {
                races: Math.floor(Math.random() * 15) + 1,
                score: Math.floor(Math.random() * 1000000),
                playTime: Math.floor(Math.random() * 7200),
                distance: Math.floor(Math.random() * 50000)
            };
        }
        
        // Records
        this.stats.records = [
            { type: 'score', value: 847293, date: Date.now() - 5 * 24 * 60 * 60 * 1000, level: 'level_5' },
            { type: 'combo', value: 847, date: Date.now() - 3 * 24 * 60 * 60 * 1000, level: 'level_3' },
            { type: 'drift', value: 14.7, date: Date.now() - 7 * 24 * 60 * 60 * 1000, level: 'level_8' },
            { type: 'speed', value: 892, date: Date.now() - 1 * 24 * 60 * 60 * 1000, level: 'level_10' },
            { type: 'distance', value: 28472, date: Date.now() - 2 * 24 * 60 * 60 * 1000, level: 'level_6' }
        ];
    }
    
    /**
     * Create animated background
     */
    createBackground(width, height) {
        // Gradient background
        const graphics = this.add.graphics();
        
        // Dark gradient
        for (let y = 0; y < height; y++) {
            const t = y / height;
            const r = Math.floor(10 + t * 15);
            const g = Math.floor(15 + t * 20);
            const b = Math.floor(30 + t * 25);
            graphics.fillStyle(Phaser.Display.Color.GetColor(r, g, b), 1);
            graphics.fillRect(0, y, width, 1);
        }
        
        // Grid pattern
        graphics.lineStyle(1, 0x1a3050, 0.3);
        const gridSize = 40;
        
        for (let x = 0; x < width; x += gridSize) {
            graphics.lineBetween(x, 0, x, height);
        }
        for (let y = 0; y < height; y += gridSize) {
            graphics.lineBetween(0, y, width, y);
        }
        
        // Animated particles
        this.createBackgroundParticles(width, height);
    }
    
    /**
     * Create floating background particles
     */
    createBackgroundParticles(width, height) {
        this.bgParticles = [];
        
        for (let i = 0; i < 30; i++) {
            const particle = {
                x: Math.random() * width,
                y: Math.random() * height,
                size: Math.random() * 3 + 1,
                speed: Math.random() * 0.5 + 0.2,
                alpha: Math.random() * 0.3 + 0.1
            };
            this.bgParticles.push(particle);
        }
        
        this.particleGraphics = this.add.graphics();
    }
    
    /**
     * Create header with title
     */
    createHeader(width) {
        // Title background
        const headerBg = this.add.graphics();
        headerBg.fillStyle(0x0a1525, 0.9);
        headerBg.fillRect(0, 0, width, 70);
        headerBg.lineStyle(2, 0x00ffff, 0.5);
        headerBg.lineBetween(0, 70, width, 70);
        
        // Title
        this.add.text(width / 2, 35, 'PLAYER STATISTICS', {
            fontFamily: 'Arial Black',
            fontSize: '32px',
            color: '#00ffff',
            stroke: '#004455',
            strokeThickness: 3
        }).setOrigin(0.5);
        
        // Stats icon
        const iconG = this.add.graphics();
        iconG.fillStyle(0x00ffff, 0.8);
        iconG.fillRect(30, 25, 25, 4);
        iconG.fillRect(30, 33, 35, 4);
        iconG.fillRect(30, 41, 20, 4);
    }
    
    /**
     * Create tab navigation
     */
    createTabs(width) {
        const tabWidth = width / this.tabs.length;
        const tabY = 90;
        
        this.tabButtons = [];
        this.tabTexts = [];
        
        this.tabs.forEach((tab, index) => {
            const x = index * tabWidth;
            
            // Tab background
            const bg = this.add.graphics();
            this.updateTabStyle(bg, x, tabY, tabWidth, 40, tab === this.currentTab);
            
            // Tab text
            const text = this.add.text(x + tabWidth / 2, tabY + 20, tab.toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: tab === this.currentTab ? '#00ffff' : '#667788'
            }).setOrigin(0.5);
            
            // Interactive zone
            const zone = this.add.zone(x + tabWidth / 2, tabY + 20, tabWidth, 40)
                .setInteractive({ useHandCursor: true });
            
            zone.on('pointerdown', () => this.selectTab(tab));
            zone.on('pointerover', () => {
                if (tab !== this.currentTab) {
                    text.setColor('#88aacc');
                }
            });
            zone.on('pointerout', () => {
                if (tab !== this.currentTab) {
                    text.setColor('#667788');
                }
            });
            
            this.tabButtons.push({ bg, zone, tab });
            this.tabTexts.push(text);
        });
    }
    
    /**
     * Update tab visual style
     */
    updateTabStyle(graphics, x, y, width, height, active) {
        graphics.clear();
        
        if (active) {
            graphics.fillStyle(0x0a2035, 1);
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
        
        // Update tab visuals
        const width = this.cameras.main.width;
        const tabWidth = width / this.tabs.length;
        
        this.tabButtons.forEach((btn, index) => {
            const active = btn.tab === tab;
            this.updateTabStyle(btn.bg, index * tabWidth, 90, tabWidth, 40, active);
            this.tabTexts[index].setColor(active ? '#00ffff' : '#667788');
        });
        
        // Render new content
        this.renderCurrentTab();
        
        // Sound
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Create period selector
     */
    createPeriodSelector(width) {
        const y = 145;
        this.periodButtons = [];
        
        this.add.text(20, y, 'PERIOD:', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        
        let xPos = 80;
        this.periods.forEach(period => {
            const active = period === this.selectedPeriod;
            const text = this.add.text(xPos, y, period.toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: active ? '#00ffff' : '#445566',
                backgroundColor: active ? '#0a2535' : 'transparent',
                padding: { x: 8, y: 4 }
            }).setInteractive({ useHandCursor: true });
            
            text.on('pointerdown', () => this.selectPeriod(period));
            text.on('pointerover', () => {
                if (period !== this.selectedPeriod) text.setColor('#88aacc');
            });
            text.on('pointerout', () => {
                if (period !== this.selectedPeriod) text.setColor('#445566');
            });
            
            this.periodButtons.push({ text, period });
            xPos += text.width + 20;
        });
    }
    
    /**
     * Select time period
     */
    selectPeriod(period) {
        if (period === this.selectedPeriod) return;
        
        this.selectedPeriod = period;
        
        this.periodButtons.forEach(btn => {
            const active = btn.period === period;
            btn.text.setColor(active ? '#00ffff' : '#445566');
            btn.text.setBackgroundColor(active ? '#0a2535' : 'transparent');
        });
        
        this.renderCurrentTab();
    }
    
    /**
     * Render current tab content
     */
    renderCurrentTab() {
        // Clear previous content
        this.contentContainer.removeAll(true);
        
        switch (this.currentTab) {
            case 'overview':
                this.renderOverviewTab();
                break;
            case 'races':
                this.renderRacesTab();
                break;
            case 'vehicles':
                this.renderVehiclesTab();
                break;
            case 'achievements':
                this.renderAchievementsTab();
                break;
            case 'records':
                this.renderRecordsTab();
                break;
        }
    }
    
    /**
     * Render overview statistics tab
     */
    renderOverviewTab() {
        const { width, height } = this.cameras.main;
        const startY = 0;
        let y = startY;
        
        // Main stats grid
        const statsGrid = [
            [
                { label: 'TOTAL RACES', value: this.formatNumber(this.stats.totalRaces), icon: '🏁' },
                { label: 'TOTAL SCORE', value: this.formatNumber(this.stats.totalScore), icon: '⭐' }
            ],
            [
                { label: 'DISTANCE', value: this.formatDistance(this.stats.totalDistance), icon: '📏' },
                { label: 'PLAY TIME', value: this.formatTime(this.stats.totalPlayTime), icon: '⏱️' }
            ],
            [
                { label: 'COINS EARNED', value: this.formatNumber(this.stats.totalCoins), icon: '💰' },
                { label: 'POWER-UPS', value: this.formatNumber(this.stats.totalPowerUps), icon: '⚡' }
            ],
            [
                { label: 'DEATHS', value: this.formatNumber(this.stats.totalDeaths), icon: '💀' },
                { label: 'NEAR MISSES', value: this.formatNumber(this.stats.totalNearMisses), icon: '😰' }
            ]
        ];
        
        const cellWidth = (width - 60) / 2;
        const cellHeight = 70;
        
        statsGrid.forEach((row, rowIndex) => {
            row.forEach((stat, colIndex) => {
                const x = 20 + colIndex * (cellWidth + 20);
                const cellY = y + rowIndex * (cellHeight + 10);
                
                this.createStatCard(x, cellY, cellWidth, cellHeight, stat);
            });
        });
        
        y += statsGrid.length * (cellHeight + 10) + 20;
        
        // Activity graph
        this.createActivityGraph(20, y, width - 40, 150);
        y += 170;
        
        // Recent activity
        this.createRecentActivity(20, y, width - 40);
        
        this.maxScroll = Math.max(0, y + 200 - (height - 200));
    }
    
    /**
     * Create a stat card
     */
    createStatCard(x, y, width, height, stat) {
        const container = this.add.container(x, y);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a1525, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 8);
        bg.lineStyle(1, 0x00ffff, 0.3);
        bg.strokeRoundedRect(0, 0, width, height, 8);
        
        // Icon (text-based for simplicity)
        const icon = this.add.text(15, height / 2, stat.icon || '📊', {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        
        // Label
        const label = this.add.text(55, 15, stat.label, {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        });
        
        // Value
        const value = this.add.text(55, 35, stat.value, {
            fontFamily: 'Arial Black',
            fontSize: '22px',
            color: '#00ffff'
        });
        
        container.add([bg, icon, label, value]);
        this.contentContainer.add(container);
    }
    
    /**
     * Create activity graph
     */
    createActivityGraph(x, y, width, height) {
        const container = this.add.container(x, y);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a1525, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 8);
        bg.lineStyle(1, 0x334455, 0.5);
        bg.strokeRoundedRect(0, 0, width, height, 8);
        
        // Title
        const title = this.add.text(15, 10, 'ACTIVITY (Last 14 Days)', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        
        container.add([bg, title]);
        
        // Get data for graph
        const days = 14;
        const data = [];
        for (let i = days - 1; i >= 0; i--) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            const dateKey = date.toISOString().split('T')[0];
            const dayStats = this.stats.dailyStats[dateKey] || { races: 0 };
            data.push(dayStats.races);
        }
        
        // Draw bars
        const graphX = 40;
        const graphY = 40;
        const graphWidth = width - 80;
        const graphHeight = height - 70;
        const barWidth = graphWidth / days - 4;
        const maxValue = Math.max(...data, 1);
        
        const graphG = this.add.graphics();
        
        // Grid lines
        graphG.lineStyle(1, 0x223344, 0.3);
        for (let i = 0; i <= 4; i++) {
            const lineY = graphY + graphHeight - (i / 4) * graphHeight;
            graphG.lineBetween(graphX, lineY, graphX + graphWidth, lineY);
        }
        
        // Bars
        data.forEach((value, index) => {
            const barHeight = (value / maxValue) * graphHeight;
            const barX = graphX + index * (barWidth + 4);
            const barY = graphY + graphHeight - barHeight;
            
            // Bar gradient effect
            const intensity = value / maxValue;
            const color = Phaser.Display.Color.Interpolate.ColorWithColor(
                { r: 0, g: 100, b: 150 },
                { r: 0, g: 255, b: 255 },
                100,
                intensity * 100
            );
            
            graphG.fillStyle(Phaser.Display.Color.GetColor(color.r, color.g, color.b), 0.8);
            graphG.fillRoundedRect(barX, barY, barWidth, barHeight, 3);
        });
        
        container.add(graphG);
        
        // X-axis labels
        for (let i = 0; i < days; i += 2) {
            const date = new Date();
            date.setDate(date.getDate() - (days - 1 - i));
            const label = `${date.getDate()}`;
            const labelX = graphX + i * (barWidth + 4) + barWidth / 2;
            
            const text = this.add.text(labelX, graphY + graphHeight + 5, label, {
                fontFamily: 'Arial',
                fontSize: '10px',
                color: '#445566'
            }).setOrigin(0.5, 0);
            
            container.add(text);
        }
        
        this.contentContainer.add(container);
    }
    
    /**
     * Create recent activity section
     */
    createRecentActivity(x, y, width) {
        const container = this.add.container(x, y);
        
        // Title
        const title = this.add.text(0, 0, 'RECENT RECORDS', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        });
        container.add(title);
        
        // Recent records
        const recentRecords = this.stats.records.slice(0, 5);
        
        recentRecords.forEach((record, index) => {
            const itemY = 30 + index * 40;
            const itemBg = this.add.graphics();
            itemBg.fillStyle(0x0a1525, 0.7);
            itemBg.fillRoundedRect(0, itemY, width, 35, 5);
            
            const typeText = this.add.text(15, itemY + 17, record.type.toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#ffaa00'
            }).setOrigin(0, 0.5);
            
            const valueText = this.add.text(120, itemY + 17, this.formatRecordValue(record), {
                fontFamily: 'Arial Black',
                fontSize: '14px',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            
            const dateText = this.add.text(width - 15, itemY + 17, this.formatDate(record.date), {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            }).setOrigin(1, 0.5);
            
            container.add([itemBg, typeText, valueText, dateText]);
        });
        
        this.contentContainer.add(container);
    }
    
    /**
     * Render races statistics tab
     */
    renderRacesTab() {
        const { width } = this.cameras.main;
        let y = 0;
        
        // Summary stats
        const summaryContainer = this.add.container(20, y);
        
        const summaryBg = this.add.graphics();
        summaryBg.fillStyle(0x0a1525, 0.9);
        summaryBg.fillRoundedRect(0, 0, width - 40, 80, 8);
        summaryContainer.add(summaryBg);
        
        const winRate = this.stats.totalRaces > 0 
            ? Math.round((this.stats.totalPerfectLaps / this.stats.totalRaces) * 100)
            : 0;
        
        const summaryStats = [
            { label: 'Win Rate', value: `${winRate}%` },
            { label: 'Avg Score', value: this.formatNumber(Math.floor(this.stats.totalScore / Math.max(1, this.stats.totalRaces))) },
            { label: 'Avg Distance', value: this.formatDistance(Math.floor(this.stats.totalDistance / Math.max(1, this.stats.totalRaces))) }
        ];
        
        summaryStats.forEach((stat, index) => {
            const statX = 30 + index * (width - 100) / 3;
            
            const label = this.add.text(statX, 20, stat.label, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            });
            
            const value = this.add.text(statX, 42, stat.value, {
                fontFamily: 'Arial Black',
                fontSize: '18px',
                color: '#00ffff'
            });
            
            summaryContainer.add([label, value]);
        });
        
        this.contentContainer.add(summaryContainer);
        y += 100;
        
        // Level breakdown
        const levelTitle = this.add.text(20, y, 'LEVEL BREAKDOWN', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        });
        this.contentContainer.add(levelTitle);
        y += 30;
        
        const levelKeys = Object.keys(this.stats.levelStats).sort();
        
        levelKeys.forEach((levelKey, index) => {
            const levelData = this.stats.levelStats[levelKey];
            const levelNum = levelKey.replace('level_', '');
            
            const itemContainer = this.add.container(20, y + index * 50);
            
            const itemBg = this.add.graphics();
            itemBg.fillStyle(0x0a1525, 0.8);
            itemBg.fillRoundedRect(0, 0, width - 40, 45, 5);
            itemContainer.add(itemBg);
            
            // Level name
            const levelName = this.add.text(15, 12, `LEVEL ${levelNum}`, {
                fontFamily: 'Arial Black',
                fontSize: '14px',
                color: '#ffffff'
            });
            itemContainer.add(levelName);
            
            // Stats row
            const statsRow = [
                { label: 'Plays', value: levelData.plays },
                { label: 'Wins', value: levelData.wins },
                { label: 'Best', value: this.formatNumber(levelData.bestScore) }
            ];
            
            statsRow.forEach((stat, sIndex) => {
                const sX = 150 + sIndex * 90;
                
                const sLabel = this.add.text(sX, 8, stat.label, {
                    fontFamily: 'Arial',
                    fontSize: '10px',
                    color: '#667788'
                });
                
                const sValue = this.add.text(sX, 22, String(stat.value), {
                    fontFamily: 'Arial',
                    fontSize: '13px',
                    color: '#aabbcc'
                });
                
                itemContainer.add([sLabel, sValue]);
            });
            
            // Progress bar
            const winRate = levelData.plays > 0 ? levelData.wins / levelData.plays : 0;
            const barWidth = 80;
            const barBg = this.add.graphics();
            barBg.fillStyle(0x1a2535, 1);
            barBg.fillRoundedRect(width - 140, 17, barWidth, 12, 6);
            barBg.fillStyle(0x00ff88, 0.8);
            barBg.fillRoundedRect(width - 140, 17, barWidth * winRate, 12, 6);
            itemContainer.add(barBg);
            
            this.contentContainer.add(itemContainer);
        });
        
        this.maxScroll = Math.max(0, y + levelKeys.length * 50 + 50 - 400);
    }
    
    /**
     * Render vehicles statistics tab
     */
    renderVehiclesTab() {
        const { width } = this.cameras.main;
        let y = 0;
        
        // Vehicle list
        const vehicleKeys = Object.keys(this.stats.vehicleStats);
        
        vehicleKeys.forEach((vehicleKey, index) => {
            const vehicleData = this.stats.vehicleStats[vehicleKey];
            
            const itemContainer = this.add.container(20, y + index * 100);
            
            // Background
            const itemBg = this.add.graphics();
            itemBg.fillStyle(0x0a1525, 0.9);
            itemBg.fillRoundedRect(0, 0, width - 40, 90, 8);
            itemBg.lineStyle(1, 0x00ffff, 0.2);
            itemBg.strokeRoundedRect(0, 0, width - 40, 90, 8);
            itemContainer.add(itemBg);
            
            // Vehicle icon placeholder
            const iconBg = this.add.graphics();
            iconBg.fillStyle(0x1a2535, 1);
            iconBg.fillRoundedRect(10, 10, 70, 70, 5);
            itemContainer.add(iconBg);
            
            // Vehicle name
            const name = this.add.text(95, 15, vehicleKey.toUpperCase(), {
                fontFamily: 'Arial Black',
                fontSize: '16px',
                color: '#ffffff'
            });
            itemContainer.add(name);
            
            // Stats
            const vehicleStats = [
                { label: 'Races', value: vehicleData.races, icon: '🏁' },
                { label: 'Distance', value: this.formatDistance(vehicleData.distance), icon: '📏' },
                { label: 'Total Score', value: this.formatNumber(vehicleData.score), icon: '⭐' },
                { label: 'Wins', value: vehicleData.wins, icon: '🏆' }
            ];
            
            vehicleStats.forEach((stat, sIndex) => {
                const sX = 95 + sIndex * 85;
                
                const sLabel = this.add.text(sX, 42, stat.label, {
                    fontFamily: 'Arial',
                    fontSize: '10px',
                    color: '#667788'
                });
                
                const sValue = this.add.text(sX, 58, String(stat.value), {
                    fontFamily: 'Arial',
                    fontSize: '14px',
                    color: '#00ffff'
                });
                
                itemContainer.add([sLabel, sValue]);
            });
            
            this.contentContainer.add(itemContainer);
        });
        
        this.maxScroll = Math.max(0, vehicleKeys.length * 100 - 300);
    }
    
    /**
     * Render achievements progress tab
     */
    renderAchievementsTab() {
        const { width } = this.cameras.main;
        let y = 0;
        
        // Overall progress
        const totalAchievements = 25;
        const unlockedAchievements = this.stats.achievements.length || 12; // Mock
        const progress = unlockedAchievements / totalAchievements;
        
        const progressContainer = this.add.container(20, y);
        
        const progressBg = this.add.graphics();
        progressBg.fillStyle(0x0a1525, 0.9);
        progressBg.fillRoundedRect(0, 0, width - 40, 100, 8);
        progressContainer.add(progressBg);
        
        const progressTitle = this.add.text(20, 15, 'ACHIEVEMENT PROGRESS', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        });
        progressContainer.add(progressTitle);
        
        const progressText = this.add.text(20, 40, `${unlockedAchievements} / ${totalAchievements} Unlocked`, {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#ffffff'
        });
        progressContainer.add(progressText);
        
        const percentText = this.add.text(width - 60, 45, `${Math.round(progress * 100)}%`, {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: '#00ff88'
        }).setOrigin(1, 0);
        progressContainer.add(percentText);
        
        // Progress bar
        const barBg = this.add.graphics();
        barBg.fillStyle(0x1a2535, 1);
        barBg.fillRoundedRect(20, 75, width - 80, 12, 6);
        barBg.fillStyle(0x00ff88, 0.9);
        barBg.fillRoundedRect(20, 75, (width - 80) * progress, 12, 6);
        progressContainer.add(barBg);
        
        this.contentContainer.add(progressContainer);
        y += 120;
        
        // Category breakdown
        const categories = [
            { name: 'RACING', total: 6, unlocked: 4, color: 0x00ffff },
            { name: 'SCORING', total: 5, unlocked: 3, color: 0xffaa00 },
            { name: 'COLLECTION', total: 5, unlocked: 2, color: 0x00ff88 },
            { name: 'MASTERY', total: 5, unlocked: 2, color: 0xff4488 },
            { name: 'SPECIAL', total: 4, unlocked: 1, color: 0xaa44ff }
        ];
        
        categories.forEach((cat, index) => {
            const catContainer = this.add.container(20, y + index * 50);
            
            const catBg = this.add.graphics();
            catBg.fillStyle(0x0a1525, 0.8);
            catBg.fillRoundedRect(0, 0, width - 40, 45, 5);
            catContainer.add(catBg);
            
            // Category indicator
            const indicator = this.add.graphics();
            indicator.fillStyle(cat.color, 1);
            indicator.fillRoundedRect(0, 0, 5, 45, { tl: 5, bl: 5, tr: 0, br: 0 });
            catContainer.add(indicator);
            
            const catName = this.add.text(20, 12, cat.name, {
                fontFamily: 'Arial',
                fontSize: '13px',
                color: '#ffffff'
            });
            catContainer.add(catName);
            
            const catProgress = this.add.text(20, 28, `${cat.unlocked}/${cat.total}`, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            });
            catContainer.add(catProgress);
            
            // Mini progress bar
            const miniBarWidth = 100;
            const miniBar = this.add.graphics();
            miniBar.fillStyle(0x1a2535, 1);
            miniBar.fillRoundedRect(width - 160, 17, miniBarWidth, 10, 5);
            miniBar.fillStyle(cat.color, 0.8);
            miniBar.fillRoundedRect(width - 160, 17, miniBarWidth * (cat.unlocked / cat.total), 10, 5);
            catContainer.add(miniBar);
            
            this.contentContainer.add(catContainer);
        });
        
        this.maxScroll = Math.max(0, y + categories.length * 50 - 300);
    }
    
    /**
     * Render records tab
     */
    renderRecordsTab() {
        const { width } = this.cameras.main;
        let y = 0;
        
        // Personal bests
        const personalBests = [
            { label: 'Highest Score', value: this.formatNumber(this.stats.bestScores.highest || 847293), icon: '⭐' },
            { label: 'Highest Combo', value: `${this.stats.highestCombo}x`, icon: '🔥' },
            { label: 'Longest Drift', value: `${this.stats.longestDrift.toFixed(1)}s`, icon: '🌀' },
            { label: 'Max Speed', value: '892 km/h', icon: '💨' },
            { label: 'Longest Run', value: this.formatDistance(28472), icon: '📏' },
            { label: 'Perfect Laps', value: String(this.stats.totalPerfectLaps), icon: '✨' }
        ];
        
        const title = this.add.text(20, y, 'PERSONAL BESTS', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        });
        this.contentContainer.add(title);
        y += 30;
        
        const pbGrid = this.add.container(20, y);
        
        personalBests.forEach((pb, index) => {
            const col = index % 2;
            const row = Math.floor(index / 2);
            const cellWidth = (width - 60) / 2;
            const cellX = col * (cellWidth + 20);
            const cellY = row * 60;
            
            const cellBg = this.add.graphics();
            cellBg.fillStyle(0x0a1525, 0.9);
            cellBg.fillRoundedRect(cellX, cellY, cellWidth, 55, 5);
            cellBg.lineStyle(1, 0xffaa00, 0.3);
            cellBg.strokeRoundedRect(cellX, cellY, cellWidth, 55, 5);
            pbGrid.add(cellBg);
            
            const icon = this.add.text(cellX + 15, cellY + 27, pb.icon, {
                fontSize: '20px'
            }).setOrigin(0, 0.5);
            pbGrid.add(icon);
            
            const label = this.add.text(cellX + 45, cellY + 12, pb.label, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            });
            pbGrid.add(label);
            
            const value = this.add.text(cellX + 45, cellY + 30, pb.value, {
                fontFamily: 'Arial Black',
                fontSize: '16px',
                color: '#ffaa00'
            });
            pbGrid.add(value);
        });
        
        this.contentContainer.add(pbGrid);
        y += Math.ceil(personalBests.length / 2) * 60 + 30;
        
        // Record history
        const historyTitle = this.add.text(20, y, 'RECORD HISTORY', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        });
        this.contentContainer.add(historyTitle);
        y += 30;
        
        this.stats.records.forEach((record, index) => {
            const itemContainer = this.add.container(20, y + index * 45);
            
            const itemBg = this.add.graphics();
            itemBg.fillStyle(0x0a1525, 0.8);
            itemBg.fillRoundedRect(0, 0, width - 40, 40, 5);
            itemContainer.add(itemBg);
            
            // Record type badge
            const badge = this.add.graphics();
            badge.fillStyle(this.getRecordColor(record.type), 0.8);
            badge.fillRoundedRect(10, 8, 70, 24, 4);
            itemContainer.add(badge);
            
            const typeText = this.add.text(45, 20, record.type.toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '10px',
                color: '#ffffff'
            }).setOrigin(0.5);
            itemContainer.add(typeText);
            
            const valueText = this.add.text(100, 20, this.formatRecordValue(record), {
                fontFamily: 'Arial Black',
                fontSize: '14px',
                color: '#ffffff'
            }).setOrigin(0, 0.5);
            itemContainer.add(valueText);
            
            const levelText = this.add.text(width - 120, 20, record.level.replace('_', ' ').toUpperCase(), {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            }).setOrigin(1, 0.5);
            itemContainer.add(levelText);
            
            const dateText = this.add.text(width - 55, 20, this.formatDate(record.date), {
                fontFamily: 'Arial',
                fontSize: '10px',
                color: '#445566'
            }).setOrigin(1, 0.5);
            itemContainer.add(dateText);
            
            this.contentContainer.add(itemContainer);
        });
        
        this.maxScroll = Math.max(0, y + this.stats.records.length * 45 - 250);
    }
    
    /**
     * Get color for record type
     */
    getRecordColor(type) {
        const colors = {
            score: 0xffaa00,
            combo: 0xff4488,
            drift: 0x00ffff,
            speed: 0x00ff88,
            distance: 0xaa44ff
        };
        return colors[type] || 0x667788;
    }
    
    /**
     * Create back button
     */
    createBackButton(width, height) {
        const btnContainer = this.add.container(width - 80, height - 50);
        
        const btnBg = this.add.graphics();
        btnBg.fillStyle(0x0a1525, 0.9);
        btnBg.fillRoundedRect(0, 0, 60, 35, 5);
        btnBg.lineStyle(2, 0x00ffff, 0.5);
        btnBg.strokeRoundedRect(0, 0, 60, 35, 5);
        
        const btnText = this.add.text(30, 17, 'BACK', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#00ffff'
        }).setOrigin(0.5);
        
        const zone = this.add.zone(30, 17, 60, 35)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.goBack());
        zone.on('pointerover', () => {
            btnBg.clear();
            btnBg.fillStyle(0x1a3050, 0.9);
            btnBg.fillRoundedRect(0, 0, 60, 35, 5);
            btnBg.lineStyle(2, 0x00ffff, 0.8);
            btnBg.strokeRoundedRect(0, 0, 60, 35, 5);
        });
        zone.on('pointerout', () => {
            btnBg.clear();
            btnBg.fillStyle(0x0a1525, 0.9);
            btnBg.fillRoundedRect(0, 0, 60, 35, 5);
            btnBg.lineStyle(2, 0x00ffff, 0.5);
            btnBg.strokeRoundedRect(0, 0, 60, 35, 5);
        });
        
        btnContainer.add([btnBg, btnText, zone]);
    }
    
    /**
     * Setup input handling
     */
    setupInput() {
        // Keyboard
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        
        // Scroll
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            this.scrollOffset = Phaser.Math.Clamp(
                this.scrollOffset + deltaY * 0.5,
                0,
                this.maxScroll
            );
            this.contentContainer.y = 180 - this.scrollOffset;
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
     * Update loop
     */
    update(time, delta) {
        // Animate background particles
        if (this.bgParticles && this.particleGraphics) {
            this.particleGraphics.clear();
            
            this.bgParticles.forEach(particle => {
                particle.y -= particle.speed;
                if (particle.y < -10) {
                    particle.y = this.cameras.main.height + 10;
                    particle.x = Math.random() * this.cameras.main.width;
                }
                
                this.particleGraphics.fillStyle(0x00ffff, particle.alpha);
                this.particleGraphics.fillCircle(particle.x, particle.y, particle.size);
            });
        }
    }
    
    // ========== Utility Methods ==========
    
    /**
     * Format large numbers with separators
     */
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return String(num);
    }
    
    /**
     * Format distance in meters/km
     */
    formatDistance(meters) {
        if (meters >= 1000) {
            return (meters / 1000).toFixed(1) + ' km';
        }
        return meters + ' m';
    }
    
    /**
     * Format time in hours:minutes:seconds
     */
    formatTime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        }
        return `${secs}s`;
    }
    
    /**
     * Format date for display
     */
    formatDate(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffDays = Math.floor((now - date) / (24 * 60 * 60 * 1000));
        
        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
    
    /**
     * Format record value based on type
     */
    formatRecordValue(record) {
        switch (record.type) {
            case 'score':
                return this.formatNumber(record.value);
            case 'combo':
                return `${record.value}x`;
            case 'drift':
                return `${record.value.toFixed(1)}s`;
            case 'speed':
                return `${record.value} km/h`;
            case 'distance':
                return this.formatDistance(record.value);
            default:
                return String(record.value);
        }
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.StatsScene = StatsScene;
}
