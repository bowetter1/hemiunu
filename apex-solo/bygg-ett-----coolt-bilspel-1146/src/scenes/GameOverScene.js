/**
 * GRAVSHIFT - Game Over Scene
 * Displayed when player fails
 */

class GameOverScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameOverScene' });
    }
    
    init(data) {
        this.levelId = data.levelId || 1;
        this.stats = data.stats || {};
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Background
        this.add.rectangle(centerX, height / 2, width, height, 0x0a0a0f);
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // "GAME OVER" title with glitch effect
        this.title = this.add.text(centerX, 100, 'GAME OVER', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '64px',
            color: '#ff0040',
        }).setOrigin(0.5);
        
        // Reason (if any)
        if (this.stats.reason) {
            this.add.text(centerX, 160, this.stats.reason, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '24px',
                color: '#888888',
            }).setOrigin(0.5);
        }
        
        // Stats panel
        this.createStatsPanel(centerX, 280);
        
        // Buttons
        const buttonY = height - 150;
        
        this.retryButton = new Button(this, centerX - 120, buttonY, 'RETRY', {
            width: 180,
            color: 0x00ffff,
            onClick: () => this.retry(),
        });
        
        this.menuButton = new Button(this, centerX + 120, buttonY, 'MENU', {
            width: 180,
            color: 0xff00ff,
            onClick: () => this.goToMenu(),
        });
        
        // Glitch effect on title
        this.createGlitchEffect();
        
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Setup keyboard shortcuts
        this.input.keyboard.on('keydown-R', () => this.retry());
        this.input.keyboard.on('keydown-ESC', () => this.goToMenu());
    }
    
    createStatsPanel(x, y) {
        // Panel background
        const panelWidth = 400;
        const panelHeight = 280;
        
        const panel = this.add.graphics();
        panel.fillStyle(0x1a1a2e, 0.9);
        panel.fillRoundedRect(x - panelWidth / 2, y - 20, panelWidth, panelHeight, 12);
        panel.lineStyle(2, 0xff0040, 0.5);
        panel.strokeRoundedRect(x - panelWidth / 2, y - 20, panelWidth, panelHeight, 12);
        
        // Stats
        const stats = [
            { label: 'SCORE', value: MathUtils.formatNumber(this.stats.score || 0) },
            { label: 'DISTANCE', value: `${Math.floor(this.stats.distance || 0)}m` },
            { label: 'MAX COMBO', value: `x${this.stats.maxCombo || 0}` },
            { label: 'TIME', value: MathUtils.formatTime(this.stats.time || 0) },
            { label: 'NEAR MISSES', value: this.stats.nearMisses || 0 },
        ];
        
        stats.forEach((stat, index) => {
            const statY = y + index * 45 + 20;
            
            // Label
            this.add.text(x - 150, statY, stat.label, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '18px',
                color: '#888888',
            });
            
            // Value
            this.add.text(x + 150, statY, stat.value.toString(), {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '22px',
                color: '#ffffff',
            }).setOrigin(1, 0);
        });
        
        // Highscore check
        const levelManager = new LevelManager(this);
        const highscore = levelManager.getHighscore(this.levelId);
        
        if (highscore > 0) {
            this.add.text(x, y + panelHeight - 40, `BEST: ${MathUtils.formatNumber(highscore)}`, {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '16px',
                color: '#ffff00',
            }).setOrigin(0.5);
        }
    }
    
    createGlitchEffect() {
        // Periodic glitch on title
        this.time.addEvent({
            delay: 2000 + Math.random() * 3000,
            loop: true,
            callback: () => {
                // Quick horizontal offset
                this.tweens.add({
                    targets: this.title,
                    x: this.title.x + MathUtils.randomRange(-10, 10),
                    duration: 50,
                    yoyo: true,
                    repeat: 2,
                });
                
                // Color flash
                this.title.setColor('#00ffff');
                this.time.delayedCall(100, () => {
                    this.title.setColor('#ff0040');
                });
            },
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
    window.GameOverScene = GameOverScene;
}
