/**
 * GRAVSHIFT - Pause Scene
 * Overlay scene for pause menu
 */

class PauseScene extends Phaser.Scene {
    constructor() {
        super({ key: 'PauseScene' });
    }
    
    init(data) {
        this.parentScene = data.parentScene;
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        const centerY = height / 2;
        
        // Dark overlay
        this.overlay = this.add.rectangle(centerX, centerY, width, height, 0x000000, 0.7);
        
        // Pause panel
        this.panel = this.add.graphics();
        this.panel.fillStyle(0x0a0a0f, 0.95);
        this.panel.fillRoundedRect(centerX - 200, centerY - 200, 400, 400, 16);
        this.panel.lineStyle(2, 0x00ffff, 0.8);
        this.panel.strokeRoundedRect(centerX - 200, centerY - 200, 400, 400, 16);
        
        // Title
        this.title = this.add.text(centerX, centerY - 150, 'PAUSED', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '48px',
            color: '#00ffff',
        }).setOrigin(0.5);
        
        // Menu options
        this.selectedOption = 0;
        this.menuOptions = [
            { text: 'RESUME', action: () => this.resumeGame() },
            { text: 'RESTART', action: () => this.restartLevel() },
            { text: 'SETTINGS', action: () => this.openSettings() },
            { text: 'QUIT TO MENU', action: () => this.quitToMenu() },
        ];
        
        this.buttons = [];
        this.menuOptions.forEach((option, index) => {
            const y = centerY - 50 + index * 60;
            const button = new Button(this, centerX, y, option.text, {
                width: 250,
                color: 0x00ffff,
                onClick: option.action,
            });
            this.buttons.push(button);
        });
        
        // Controls hint
        this.hint = this.add.text(centerX, centerY + 170, 'ESC to Resume', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#666666',
        }).setOrigin(0.5);
        
        // Setup input
        this.setupInput();
        
        // Audio manager for SFX
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
    }
    
    setupInput() {
        // Keyboard
        this.input.keyboard.on('keydown-ESC', () => this.resumeGame());
        this.input.keyboard.on('keydown-P', () => this.resumeGame());
        
        this.input.keyboard.on('keydown-UP', () => {
            this.selectedOption = (this.selectedOption - 1 + this.menuOptions.length) % this.menuOptions.length;
            this.updateSelection();
        });
        
        this.input.keyboard.on('keydown-DOWN', () => {
            this.selectedOption = (this.selectedOption + 1) % this.menuOptions.length;
            this.updateSelection();
        });
        
        this.input.keyboard.on('keydown-ENTER', () => {
            this.menuOptions[this.selectedOption].action();
        });
    }
    
    updateSelection() {
        // Visual feedback for keyboard selection would go here
    }
    
    resumeGame() {
        this.scene.stop();
        if (this.parentScene) {
            this.parentScene.resumeGame();
        }
    }
    
    restartLevel() {
        this.scene.stop();
        this.scene.stop('GameScene');
        this.scene.start('GameScene', { levelId: this.parentScene?.levelId || 1 });
    }
    
    openSettings() {
        // For now, just show a message
        // In full implementation, would open settings panel
    }
    
    quitToMenu() {
        this.scene.stop();
        this.scene.stop('GameScene');
        this.scene.start('MenuScene');
    }
}

// Export
if (typeof window !== 'undefined') {
    window.PauseScene = PauseScene;
}
