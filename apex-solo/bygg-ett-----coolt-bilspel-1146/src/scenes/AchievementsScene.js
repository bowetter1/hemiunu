/**
 * GRAVSHIFT - Achievements Scene
 * Displays all achievements and progress
 */

class AchievementsScene extends Phaser.Scene {
    constructor() {
        super({ key: 'AchievementsScene' });
    }
    
    init() {
        this.selectedCategory = 'beginner';
        this.scrollOffset = 0;
        this.maxScroll = 0;
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Initialize managers
        this.achievementManager = new AchievementManager(this);
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Background
        this.createBackground();
        
        // Title
        this.add.text(width / 2, 40, 'ACHIEVEMENTS', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '36px',
            color: '#00ffff',
        }).setOrigin(0.5);
        
        // Progress overview
        this.createProgressOverview(width / 2, 90);
        
        // Category tabs
        this.createCategoryTabs(width / 2, 150);
        
        // Achievement list area
        this.listContainer = this.add.container(0, 0);
        this.createAchievementList();
        
        // Back button
        this.createBackButton(100, height - 40);
        
        // Setup scrolling
        this.setupScrolling();
        
        // Keyboard
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        
        // Fade in
        this.cameras.main.fadeIn(300);
    }
    
    createBackground() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Gradient background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a0a0f, 1);
        bg.fillRect(0, 0, width, height);
        
        // Grid pattern
        bg.lineStyle(1, 0x00ffff, 0.05);
        for (let x = 0; x < width; x += 50) {
            bg.lineBetween(x, 0, x, height);
        }
        for (let y = 0; y < height; y += 50) {
            bg.lineBetween(0, y, width, y);
        }
    }
    
    createProgressOverview(x, y) {
        const stats = this.achievementManager.getDisplayStats();
        
        // Progress bar background
        const barWidth = 400;
        const barHeight = 20;
        
        const bg = this.add.graphics();
        bg.fillStyle(0x1a1a2e, 1);
        bg.fillRoundedRect(x - barWidth / 2, y, barWidth, barHeight, 4);
        
        // Progress fill
        const fillWidth = (stats.completionPercentage / 100) * barWidth;
        bg.fillStyle(0x00ffff, 0.8);
        bg.fillRoundedRect(x - barWidth / 2, y, fillWidth, barHeight, 4);
        
        // Progress text
        this.add.text(x, y + barHeight / 2, `${stats.achievementsUnlocked} / ${stats.totalAchievements} (${stats.completionPercentage}%)`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '12px',
            color: '#ffffff',
        }).setOrigin(0.5);
        
        // Total rewards
        this.add.text(x + barWidth / 2 + 20, y + barHeight / 2, `${MathUtils.formatNumber(stats.totalRewards)} GP`, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#ffff00',
        }).setOrigin(0, 0.5);
    }
    
    createCategoryTabs(centerX, y) {
        const categories = [
            { key: 'beginner', name: 'Beginner' },
            { key: 'intermediate', name: 'Intermediate' },
            { key: 'advanced', name: 'Advanced' },
            { key: 'endless', name: 'Endless' },
            { key: 'special', name: 'Special' },
        ];
        
        const tabWidth = 140;
        const totalWidth = categories.length * tabWidth;
        const startX = centerX - totalWidth / 2 + tabWidth / 2;
        
        this.categoryTabs = [];
        
        categories.forEach((cat, index) => {
            const x = startX + index * tabWidth;
            const isSelected = cat.key === this.selectedCategory;
            
            const bg = this.add.graphics();
            bg.fillStyle(isSelected ? 0x00ffff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
            bg.fillRoundedRect(x - tabWidth / 2 + 5, y, tabWidth - 10, 30, 4);
            bg.lineStyle(2, 0x00ffff, isSelected ? 1 : 0.3);
            bg.strokeRoundedRect(x - tabWidth / 2 + 5, y, tabWidth - 10, 30, 4);
            
            const text = this.add.text(x, y + 15, cat.name, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '14px',
                color: isSelected ? '#00ffff' : '#888888',
            }).setOrigin(0.5);
            
            const hitArea = this.add.rectangle(x, y + 15, tabWidth - 10, 30)
                .setInteractive({ useHandCursor: true })
                .on('pointerdown', () => this.selectCategory(cat.key));
            
            this.categoryTabs.push({ key: cat.key, bg, text, hitArea });
        });
    }
    
    selectCategory(categoryKey) {
        this.selectedCategory = categoryKey;
        this.scrollOffset = 0;
        
        // Update tab visuals
        this.categoryTabs.forEach(tab => {
            const isSelected = tab.key === categoryKey;
            tab.bg.clear();
            tab.bg.fillStyle(isSelected ? 0x00ffff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
            tab.bg.fillRoundedRect(
                tab.text.x - 65,
                tab.text.y - 15,
                130, 30, 4
            );
            tab.bg.lineStyle(2, 0x00ffff, isSelected ? 1 : 0.3);
            tab.bg.strokeRoundedRect(
                tab.text.x - 65,
                tab.text.y - 15,
                130, 30, 4
            );
            tab.text.setColor(isSelected ? '#00ffff' : '#888888');
        });
        
        // Refresh list
        this.createAchievementList();
        
        this.audioManager.playSFX('select');
    }
    
    createAchievementList() {
        // Clear existing
        this.listContainer.removeAll(true);
        
        const width = this.scale.width;
        const categories = this.achievementManager.getAchievementsByCategory();
        const achievements = categories[this.selectedCategory]?.achievements || [];
        
        const startY = 200;
        const itemHeight = 80;
        const padding = 20;
        
        // List background
        const listBg = this.add.graphics();
        listBg.fillStyle(0x0a0a0f, 0.5);
        listBg.fillRoundedRect(padding, startY, width - padding * 2, this.scale.height - startY - 60, 8);
        this.listContainer.add(listBg);
        
        // Create mask for scrolling
        const maskShape = this.make.graphics();
        maskShape.fillStyle(0xffffff);
        maskShape.fillRect(padding, startY, width - padding * 2, this.scale.height - startY - 60);
        const mask = maskShape.createGeometryMask();
        this.listContainer.setMask(mask);
        
        // Create achievement items
        achievements.forEach((achievement, index) => {
            const y = startY + 10 + index * itemHeight - this.scrollOffset;
            this.createAchievementItem(achievement, padding + 10, y, width - padding * 2 - 20);
        });
        
        // Calculate max scroll
        this.maxScroll = Math.max(0, achievements.length * itemHeight - (this.scale.height - startY - 80));
    }
    
    createAchievementItem(achievement, x, y, width) {
        const height = 70;
        const isUnlocked = achievement.unlocked;
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(isUnlocked ? 0x1a2e1a : 0x1a1a2e, 0.8);
        bg.fillRoundedRect(x, y, width, height, 8);
        bg.lineStyle(2, isUnlocked ? 0x00ff00 : 0x333333, 0.5);
        bg.strokeRoundedRect(x, y, width, height, 8);
        this.listContainer.add(bg);
        
        // Icon placeholder
        const iconBg = this.add.graphics();
        iconBg.fillStyle(isUnlocked ? 0x00ff00 : 0x333333, 0.3);
        iconBg.fillCircle(x + 35, y + height / 2, 25);
        this.listContainer.add(iconBg);
        
        // Checkmark or lock
        const iconText = this.add.text(x + 35, y + height / 2, isUnlocked ? '✓' : '🔒', {
            fontFamily: 'sans-serif',
            fontSize: '20px',
            color: isUnlocked ? '#00ff00' : '#666666',
        }).setOrigin(0.5);
        this.listContainer.add(iconText);
        
        // Name
        const name = this.add.text(x + 80, y + 15, achievement.name, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '18px',
            color: isUnlocked ? '#ffffff' : '#888888',
        });
        this.listContainer.add(name);
        
        // Description
        const desc = this.add.text(x + 80, y + 40, 
            achievement.hidden && !isUnlocked ? '???' : achievement.description, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#666666',
        });
        this.listContainer.add(desc);
        
        // Reward
        const reward = this.add.text(x + width - 10, y + height / 2, `+${achievement.reward} GP`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '16px',
            color: isUnlocked ? '#ffff00' : '#444444',
        }).setOrigin(1, 0.5);
        this.listContainer.add(reward);
        
        // Unlocked date
        if (isUnlocked && achievement.unlockedAt) {
            const date = new Date(achievement.unlockedAt);
            const dateStr = date.toLocaleDateString();
            const dateText = this.add.text(x + width - 10, y + height - 10, dateStr, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '10px',
                color: '#444444',
            }).setOrigin(1, 1);
            this.listContainer.add(dateText);
        }
    }
    
    setupScrolling() {
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY, deltaZ) => {
            this.scrollOffset = MathUtils.clamp(
                this.scrollOffset + deltaY * 0.5,
                0,
                this.maxScroll
            );
            this.createAchievementList();
        });
    }
    
    createBackButton(x, y) {
        const bg = this.add.graphics();
        bg.fillStyle(0x1a1a2e, 0.8);
        bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
        bg.lineStyle(2, 0xff00ff, 0.5);
        bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
        
        const text = this.add.text(x, y, '← BACK', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '18px',
            color: '#ff00ff',
        }).setOrigin(0.5);
        
        const hitArea = this.add.rectangle(x, y, 160, 40)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                bg.clear();
                bg.fillStyle(0xff00ff, 0.2);
                bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
                bg.lineStyle(2, 0xff00ff, 1);
                bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
                text.setColor('#ffffff');
            })
            .on('pointerout', () => {
                bg.clear();
                bg.fillStyle(0x1a1a2e, 0.8);
                bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
                bg.lineStyle(2, 0xff00ff, 0.5);
                bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
                text.setColor('#ff00ff');
            })
            .on('pointerdown', () => this.goBack());
    }
    
    goBack() {
        this.audioManager.playSFX('select');
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.AchievementsScene = AchievementsScene;
}
