/**
 * GRAVSHIFT - Settings Scene
 * Game settings and options
 */

class SettingsScene extends Phaser.Scene {
    constructor() {
        super({ key: 'SettingsScene' });
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Background
        this.add.rectangle(width / 2, height / 2, width, height, 0x0a0a0f);
        
        // Grid background
        this.grid = this.add.tileSprite(0, 0, width, height, 'grid')
            .setOrigin(0, 0)
            .setAlpha(0.2);
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // Create settings panel
        this.settingsPanel = new SettingsPanel(this);
        this.settingsPanel.create();
        this.settingsPanel.onClose = () => this.goBack();
        
        // Keyboard shortcut
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
    }
    
    goBack() {
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
    
    update() {
        // Animate background
        if (this.grid) {
            this.grid.tilePositionY -= 0.2;
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.SettingsScene = SettingsScene;
}
