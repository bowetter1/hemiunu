/**
 * GRAVSHIFT - Level Select Scene
 * Choose which level to play
 */

class LevelSelectScene extends Phaser.Scene {
    constructor() {
        super({ key: 'LevelSelectScene' });
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Background
        this.add.rectangle(width / 2, height / 2, width, height, 0x0a0a0f);
        
        // Starfield
        this.starfield = this.add.tileSprite(0, 0, width, height, 'starfield')
            .setOrigin(0, 0);
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // Create level select UI
        this.levelSelect = new LevelSelect(this);
        this.levelSelect.create();
        
        // Set callbacks
        this.levelSelect.onLevelSelected = (levelId) => this.startLevel(levelId);
        this.levelSelect.onBackPressed = () => this.goBack();
        
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Keyboard shortcut
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
    }
    
    startLevel(levelId) {
        console.log('Starting level:', levelId);
        this.audioManager.playSFX('select');
        this.registry.set('currentLevel', levelId);

        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            console.log('Transitioning to GameScene with levelId:', levelId);
            this.scene.start('GameScene', { levelId });
        });
    }
    
    goBack() {
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
    
    update() {
        // Animate background
        if (this.starfield) {
            this.starfield.tilePositionY -= 0.3;
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.LevelSelectScene = LevelSelectScene;
}
