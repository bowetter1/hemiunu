/**
 * GRAVSHIFT - Credits Scene
 * Game credits and acknowledgments
 */

class CreditsScene extends Phaser.Scene {
    constructor() {
        super({ key: 'CreditsScene' });
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Background
        this.add.rectangle(centerX, height / 2, width, height, 0x0a0a0f);
        
        // Starfield
        this.starfield = this.add.tileSprite(0, 0, width, height, 'starfield')
            .setOrigin(0, 0);
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // Credits content
        const credits = [
            { type: 'title', text: 'GRAVSHIFT' },
            { type: 'subtitle', text: 'Gravity Is Just A Suggestion' },
            { type: 'spacer' },
            { type: 'header', text: 'GAME DESIGN & DEVELOPMENT' },
            { type: 'name', text: 'AAA Indie Studio' },
            { type: 'spacer' },
            { type: 'header', text: 'ENGINE' },
            { type: 'name', text: 'Phaser 3' },
            { type: 'spacer' },
            { type: 'header', text: 'AUDIO' },
            { type: 'name', text: 'Procedural Web Audio' },
            { type: 'spacer' },
            { type: 'header', text: 'FONTS' },
            { type: 'name', text: 'Orbitron by Matt McInerney' },
            { type: 'name', text: 'Rajdhani by Indian Type Foundry' },
            { type: 'spacer' },
            { type: 'header', text: 'SPECIAL THANKS' },
            { type: 'name', text: 'Phaser Community' },
            { type: 'name', text: 'Classic Racing Games' },
            { type: 'name', text: 'Synthwave Music' },
            { type: 'spacer' },
            { type: 'spacer' },
            { type: 'footer', text: '© 2024 GRAVSHIFT' },
            { type: 'footer', text: 'All Rights Reserved' },
        ];
        
        // Create scrolling credits
        this.creditsContainer = this.add.container(centerX, height);
        
        let y = 0;
        credits.forEach(item => {
            if (item.type === 'spacer') {
                y += 40;
                return;
            }
            
            let config;
            switch (item.type) {
                case 'title':
                    config = {
                        fontFamily: 'Orbitron, sans-serif',
                        fontSize: '64px',
                        color: '#00ffff',
                    };
                    break;
                case 'subtitle':
                    config = {
                        fontFamily: 'Rajdhani, sans-serif',
                        fontSize: '24px',
                        color: '#666666',
                    };
                    y += 10;
                    break;
                case 'header':
                    config = {
                        fontFamily: 'Orbitron, sans-serif',
                        fontSize: '20px',
                        color: '#ff00ff',
                    };
                    y += 20;
                    break;
                case 'name':
                    config = {
                        fontFamily: 'Rajdhani, sans-serif',
                        fontSize: '24px',
                        color: '#ffffff',
                    };
                    break;
                case 'footer':
                    config = {
                        fontFamily: 'Rajdhani, sans-serif',
                        fontSize: '16px',
                        color: '#444444',
                    };
                    break;
            }
            
            const text = this.add.text(0, y, item.text, config).setOrigin(0.5, 0);
            this.creditsContainer.add(text);
            y += text.height + 10;
        });
        
        // Store total height
        this.creditsHeight = y;
        
        // Scroll animation
        this.tweens.add({
            targets: this.creditsContainer,
            y: -this.creditsHeight - 100,
            duration: 30000,
            ease: 'Linear',
            onComplete: () => this.goBack(),
        });
        
        // Back button
        this.backButton = new Button(this, width - 80, height - 40, 'SKIP', {
            width: 100,
            height: 35,
            fontSize: '14px',
            color: 0xff00ff,
            onClick: () => this.goBack(),
        });
        
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
            this.audioManager.playMusic('menu');
        }
        
        // Keyboard shortcut
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        this.input.keyboard.on('keydown-SPACE', () => this.goBack());
        this.input.keyboard.on('keydown-ENTER', () => this.goBack());
    }
    
    goBack() {
        this.audioManager.stopMusic();
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
    
    update() {
        // Animate background
        if (this.starfield) {
            this.starfield.tilePositionY -= 0.5;
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.CreditsScene = CreditsScene;
}
