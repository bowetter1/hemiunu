/**
 * GRAVSHIFT - Level Select UI Component
 * Level selection grid with stars and unlock status
 */

class LevelSelect {
    constructor(scene) {
        this.scene = scene;
        this.levelManager = new LevelManager(scene);
        this.selectedLevel = 1;
        this.selectedZone = 0;
        
        this.container = scene.add.container(0, 0);
        this.container.setDepth(100);
        
        this.levelButtons = [];
        this.zoneButtons = [];
    }
    
    create() {
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        const centerX = width / 2;

        // Title
        this.title = this.scene.add.text(centerX, 50, 'SELECT LEVEL', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '36px',
            color: '#00ffff',
        }).setOrigin(0.5);
        this.container.add(this.title);

        // Get zone data
        const zones = this.levelManager.getAllZones();

        // Find first unlocked zone to start with
        const firstUnlockedZone = zones.findIndex(zone => zone.unlocked);
        this.selectedZone = Math.max(0, firstUnlockedZone);

        // Create zone tabs
        this.createZoneTabs(zones, centerX, 110);

        // Create level grid for selected zone
        this.createLevelGrid(zones[this.selectedZone], centerX, 180);
        
        // Back button
        this.backButton = new Button(this.scene, centerX, height - 60, 'BACK', {
            width: 150,
            color: 0xff00ff,
            onClick: () => this.onBack(),
        });
    }
    
    createZoneTabs(zones, centerX, y) {
        const tabWidth = 120;
        const totalWidth = zones.length * (tabWidth + 10);
        const startX = centerX - totalWidth / 2 + tabWidth / 2;
        
        zones.forEach((zone, index) => {
            const x = startX + index * (tabWidth + 10);
            
            const tab = this.scene.add.container(x, y);
            
            // Background
            const bg = this.scene.add.graphics();
            const isSelected = index === this.selectedZone;
            const isUnlocked = zone.unlocked;
            
            bg.fillStyle(isUnlocked ? (isSelected ? zone.color : 0x1a1a2e) : 0x222222, isSelected ? 0.3 : 0.8);
            bg.fillRoundedRect(-tabWidth / 2, -20, tabWidth, 40, 8);
            bg.lineStyle(2, isUnlocked ? zone.color : 0x444444, isSelected ? 1 : 0.5);
            bg.strokeRoundedRect(-tabWidth / 2, -20, tabWidth, 40, 8);
            tab.add(bg);
            
            // Zone name
            const text = this.scene.add.text(0, -5, zone.name.toUpperCase(), {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '12px',
                color: isUnlocked ? (isSelected ? ColorUtils.hexToCss(zone.color) : '#ffffff') : '#666666',
            }).setOrigin(0.5);
            tab.add(text);
            
            // Star count
            const stars = this.scene.add.text(0, 10, `★ ${zone.totalStars}/${zone.maxStars}`, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '10px',
                color: isUnlocked ? '#ffff00' : '#444444',
            }).setOrigin(0.5);
            tab.add(stars);
            
            // Lock icon and requirements if locked
            if (!isUnlocked) {
                const lock = this.scene.add.text(tabWidth / 2 - 15, -15, '🔒', {
                    fontSize: '14px',
                });
                tab.add(lock);

                // Show unlock requirements
                const req = zone.unlockRequirement;
                if (req) {
                    const reqText = this.scene.add.text(0, 12, `${req.stars}★ i ${req.zone}`, {
                        fontFamily: 'Rajdhani, sans-serif',
                        fontSize: '8px',
                        color: '#666666',
                    }).setOrigin(0.5);
                    tab.add(reqText);
                }
            }
            
            // Interactive
            if (isUnlocked) {
                const hitArea = this.scene.add.rectangle(0, 0, tabWidth, 40)
                    .setInteractive({ useHandCursor: true })
                    .on('pointerdown', () => this.selectZone(index));
                hitArea.setAlpha(0.01);
                tab.add(hitArea);
            }
            
            this.container.add(tab);
            this.zoneButtons.push({ tab, bg, text, stars, zone, index });
        });
    }
    
    createLevelGrid(zone, centerX, startY) {
        // Clear existing level buttons
        this.levelButtons.forEach(btn => {
            btn.container.destroy();
        });
        this.levelButtons = [];

        if (!zone || !zone.levels) return;

        const buttonSize = 100;
        const spacing = 20;
        const cols = 3;

        zone.levels.forEach((level, index) => {
            const col = index % cols;
            const row = Math.floor(index / cols);

            const x = centerX + (col - 1) * (buttonSize + spacing);
            const y = startY + row * (buttonSize + spacing + 20);

            // Handle both level objects and level IDs
            const levelData = typeof level === 'object' ? level : {
                id: level,
                unlocked: this.levelManager.isLevelUnlocked(level),
                stars: this.levelManager.levelStars[level] || 0,
                bestTime: this.levelManager.bestTimes[level] || null,
                ...this.levelManager.getLevelConfig(level)
            };

            const btn = this.createLevelButton(levelData, x, y, buttonSize);
            this.levelButtons.push(btn);
        });
    }
    
    createLevelButton(level, x, y, size) {
        const container = this.scene.add.container(x, y);
        const isUnlocked = level.unlocked;
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(isUnlocked ? 0x1a1a2e : 0x111111, 0.9);
        bg.fillRoundedRect(-size / 2, -size / 2, size, size, 12);
        bg.lineStyle(2, isUnlocked ? 0x00ffff : 0x333333, 0.8);
        bg.strokeRoundedRect(-size / 2, -size / 2, size, size, 12);
        container.add(bg);
        
        // Level number
        const number = this.scene.add.text(0, -20, level.id.toString(), {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '32px',
            color: isUnlocked ? '#ffffff' : '#444444',
        }).setOrigin(0.5);
        container.add(number);
        
        // Level name
        const name = this.scene.add.text(0, 10, level.name || `Level ${level.id}`, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '11px',
            color: isUnlocked ? '#888888' : '#444444',
        }).setOrigin(0.5);
        container.add(name);
        
        // Stars
        const starsContainer = this.scene.add.container(0, 35);
        for (let i = 0; i < 3; i++) {
            const starX = (i - 1) * 18;
            const isFilled = i < (level.stars || 0);
            const star = this.scene.add.text(starX, 0, '★', {
                fontSize: '16px',
                color: isUnlocked ? (isFilled ? '#ffff00' : '#444444') : '#222222',
            }).setOrigin(0.5);
            starsContainer.add(star);
        }
        container.add(starsContainer);
        
        // Lock overlay
        if (!isUnlocked) {
            const lockOverlay = this.scene.add.graphics();
            lockOverlay.fillStyle(0x000000, 0.5);
            lockOverlay.fillRoundedRect(-size / 2, -size / 2, size, size, 12);
            container.add(lockOverlay);
            
            const lockIcon = this.scene.add.text(0, 0, '🔒', {
                fontSize: '24px',
            }).setOrigin(0.5);
            container.add(lockIcon);
        }
        
        // Interactive
        if (isUnlocked) {
            const hitArea = this.scene.add.rectangle(0, 0, size, size)
                .setInteractive({ useHandCursor: true })
                .on('pointerover', () => this.highlightLevel(container, bg, size))
                .on('pointerout', () => this.unhighlightLevel(bg, size))
                .on('pointerdown', () => this.selectLevel(level.id));
            hitArea.setAlpha(0.01);
            container.add(hitArea);
        }
        
        this.container.add(container);
        
        return { container, bg, number, name, level };
    }
    
    highlightLevel(container, bg, size) {
        bg.clear();
        bg.fillStyle(0x00ffff, 0.2);
        bg.fillRoundedRect(-size / 2, -size / 2, size, size, 12);
        bg.lineStyle(3, 0x00ffff, 1);
        bg.strokeRoundedRect(-size / 2, -size / 2, size, size, 12);
        
        this.scene.tweens.add({
            targets: container,
            scaleX: 1.05,
            scaleY: 1.05,
            duration: 100,
        });
    }
    
    unhighlightLevel(bg, size) {
        bg.clear();
        bg.fillStyle(0x1a1a2e, 0.9);
        bg.fillRoundedRect(-size / 2, -size / 2, size, size, 12);
        bg.lineStyle(2, 0x00ffff, 0.8);
        bg.strokeRoundedRect(-size / 2, -size / 2, size, size, 12);
    }
    
    selectZone(index) {
        // Only allow selection of unlocked zones
        const zones = this.levelManager.getAllZones();
        if (!zones[index] || !zones[index].unlocked) {
            return; // Don't allow selecting locked zones
        }

        this.selectedZone = index;

        // Refresh zone tabs
        this.zoneButtons.forEach(btn => btn.tab.destroy());
        this.zoneButtons = [];
        this.createZoneTabs(zones, this.scene.scale.width / 2, 110);

        // Refresh level grid
        this.createLevelGrid(zones[index], this.scene.scale.width / 2, 180);
    }
    
    selectLevel(levelId) {
        // Only allow selection of unlocked levels
        if (!this.levelManager.isLevelUnlocked(levelId)) {
            return; // Don't allow selecting locked levels
        }

        this.selectedLevel = levelId;

        // Emit event or callback
        if (this.onLevelSelected) {
            this.onLevelSelected(levelId);
        }
    }
    
    onBack() {
        if (this.onBackPressed) {
            this.onBackPressed();
        }
    }
    
    setVisible(visible) {
        this.container.setVisible(visible);
        if (this.backButton) {
            this.backButton.setVisible(visible);
        }
    }
    
    destroy() {
        this.container.destroy();
        if (this.backButton) {
            this.backButton.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.LevelSelect = LevelSelect;
}
