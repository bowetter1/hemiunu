/**
 * GRAVSHIFT - Victory Scene
 * Displayed when player completes a level
 */

class VictoryScene extends Phaser.Scene {
    constructor() {
        super({ key: 'VictoryScene' });
    }
    
    init(data) {
        this.levelId = data.levelId || 1;
        this.stats = data.stats || {};
        this.stars = data.stars || 0;
        this.newRecord = data.newRecord || false;
        this.nextUnlocked = data.nextUnlocked || false;
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Background with celebration particles
        this.add.rectangle(centerX, height / 2, width, height, 0x0a0a0f);
        this.createCelebrationParticles();
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // "LEVEL COMPLETE" title
        this.title = this.add.text(centerX, 80, 'LEVEL COMPLETE', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '48px',
            color: '#00ff00',
        }).setOrigin(0.5);
        
        // Level name
        const levelConfig = LEVELS[this.levelId];
        if (levelConfig) {
            this.add.text(centerX, 130, levelConfig.name.toUpperCase(), {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '24px',
                color: '#00ffff',
            }).setOrigin(0.5);
        }
        
        // Stars display
        this.createStarsDisplay(centerX, 200);
        
        // Stats panel
        this.createStatsPanel(centerX, 330);
        
        // New record banner
        if (this.newRecord) {
            this.createNewRecordBanner(centerX, 480);
        }
        
        // Buttons
        const buttonY = height - 100;
        
        // Next level button (if unlocked)
        if (this.nextUnlocked && LEVELS[this.levelId + 1]) {
            this.nextButton = new Button(this, centerX - 120, buttonY, 'NEXT LEVEL', {
                width: 180,
                color: 0x00ff00,
                onClick: () => this.nextLevel(),
            });
        }
        
        this.retryButton = new Button(this, this.nextUnlocked ? centerX + 120 : centerX - 100, buttonY, 'RETRY', {
            width: 150,
            color: 0x00ffff,
            onClick: () => this.retry(),
        });
        
        this.menuButton = new Button(this, this.nextUnlocked ? centerX + 280 : centerX + 100, buttonY, 'MENU', {
            width: 150,
            color: 0xff00ff,
            onClick: () => this.goToMenu(),
        });
        
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
            this.audioManager.playSFX('checkpoint'); // Victory sound
        }
        
        // Keyboard shortcuts
        this.input.keyboard.on('keydown-ENTER', () => {
            if (this.nextUnlocked && LEVELS[this.levelId + 1]) {
                this.nextLevel();
            } else {
                this.retry();
            }
        });
        this.input.keyboard.on('keydown-ESC', () => this.goToMenu());
    }
    
    createStarsDisplay(x, y) {
        const starSpacing = 60;
        const startX = x - starSpacing;
        
        for (let i = 0; i < 3; i++) {
            const starX = startX + i * starSpacing;
            const filled = i < this.stars;
            
            // Star background glow
            if (filled) {
                const glow = this.add.graphics();
                glow.fillStyle(0xffff00, 0.3);
                glow.fillCircle(starX, y, 35);
                
                // Animate glow
                this.tweens.add({
                    targets: glow,
                    alpha: 0.1,
                    duration: 1000,
                    yoyo: true,
                    repeat: -1,
                });
            }
            
            // Star
            const star = this.add.text(starX, y, '★', {
                fontSize: '50px',
                color: filled ? '#ffff00' : '#333333',
            }).setOrigin(0.5);
            
            // Animate filled stars appearing
            if (filled) {
                star.setScale(0);
                this.tweens.add({
                    targets: star,
                    scaleX: 1,
                    scaleY: 1,
                    duration: 500,
                    delay: i * 200 + 500,
                    ease: 'Back.easeOut',
                });
            }
        }
    }
    
    createStatsPanel(x, y) {
        const panelWidth = 450;
        const panelHeight = 140;
        
        // Panel background
        const panel = this.add.graphics();
        panel.fillStyle(0x1a1a2e, 0.9);
        panel.fillRoundedRect(x - panelWidth / 2, y - 20, panelWidth, panelHeight, 12);
        panel.lineStyle(2, 0x00ff00, 0.5);
        panel.strokeRoundedRect(x - panelWidth / 2, y - 20, panelWidth, panelHeight, 12);
        
        // Stats in two columns
        const leftStats = [
            { label: 'SCORE', value: MathUtils.formatNumber(this.stats.score || 0) },
            { label: 'TIME', value: MathUtils.formatTime(this.stats.time || 0) },
        ];
        
        const rightStats = [
            { label: 'MAX COMBO', value: `x${this.stats.maxCombo || 0}` },
            { label: 'DISTANCE', value: `${Math.floor(this.stats.distance || 0)}m` },
        ];
        
        leftStats.forEach((stat, index) => {
            const statY = y + index * 40 + 10;
            
            this.add.text(x - 200, statY, stat.label, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '16px',
                color: '#888888',
            });
            
            this.add.text(x - 50, statY, stat.value.toString(), {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '20px',
                color: '#ffffff',
            }).setOrigin(1, 0);
        });
        
        rightStats.forEach((stat, index) => {
            const statY = y + index * 40 + 10;
            
            this.add.text(x + 20, statY, stat.label, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '16px',
                color: '#888888',
            });
            
            this.add.text(x + 200, statY, stat.value.toString(), {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '20px',
                color: '#ffffff',
            }).setOrigin(1, 0);
        });
        
        // Perfect run bonus
        if (this.stats.noHitRun) {
            this.add.text(x, y + panelHeight - 25, '🏆 PERFECT RUN!', {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '18px',
                color: '#ffff00',
            }).setOrigin(0.5);
        }
    }
    
    createNewRecordBanner(x, y) {
        const banner = this.add.graphics();
        banner.fillStyle(0xffff00, 0.2);
        banner.fillRoundedRect(x - 150, y - 20, 300, 40, 8);
        banner.lineStyle(2, 0xffff00, 0.8);
        banner.strokeRoundedRect(x - 150, y - 20, 300, 40, 8);
        
        const text = this.add.text(x, y, '🎉 NEW RECORD! 🎉', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#ffff00',
        }).setOrigin(0.5);
        
        // Pulse animation
        this.tweens.add({
            targets: [banner, text],
            alpha: 0.6,
            duration: 500,
            yoyo: true,
            repeat: -1,
        });
    }
    
    createCelebrationParticles() {
        // Add floating particles
        for (let i = 0; i < 50; i++) {
            const x = Math.random() * this.scale.width;
            const y = this.scale.height + 50;
            const color = [0x00ffff, 0xff00ff, 0xffff00, 0x00ff00][Math.floor(Math.random() * 4)];
            
            const particle = this.add.graphics();
            particle.fillStyle(color, 0.8);
            particle.fillCircle(0, 0, Math.random() * 4 + 2);
            particle.setPosition(x, y);
            
            this.tweens.add({
                targets: particle,
                y: -50,
                x: x + (Math.random() - 0.5) * 200,
                alpha: 0,
                duration: 3000 + Math.random() * 2000,
                delay: Math.random() * 2000,
                repeat: -1,
                onRepeat: () => {
                    particle.y = this.scale.height + 50;
                    particle.x = Math.random() * this.scale.width;
                    particle.alpha = 0.8;
                },
            });
        }
    }
    
    nextLevel() {
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('GameScene', { levelId: this.levelId + 1 });
        });
    }
    
    retry() {
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('GameScene', { levelId: this.levelId });
        });
    }
    
    goToMenu() {
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.VictoryScene = VictoryScene;
}
