/**
 * GRAVSHIFT - Menu Scene
 * Main menu with title, options, and level select
 */

class MenuScene extends Phaser.Scene {
    constructor() {
        super({ key: 'MenuScene' });
    }
    
    init() {
        this.selectedOption = 0;
        this.menuOptions = ['PLAY', 'LEVEL SELECT', 'VEHICLES', 'SETTINGS', 'CREDITS'];
        this.buttons = [];
        this.transitioning = false;
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Initialize audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
            this.audioManager.playMusic('menu');
        }
        
        // Initialize level manager for highscores
        this.levelManager = new LevelManager(this);
        
        // Create background
        this.createBackground();
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // Title
        this.title = this.add.text(centerX, 120, 'GRAVSHIFT', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '72px',
            fontWeight: 'bold',
            color: '#00ffff',
        }).setOrigin(0.5);
        
        // Title glow animation
        this.tweens.add({
            targets: this.title,
            alpha: 0.8,
            duration: 1500,
            yoyo: true,
            repeat: -1,
            ease: 'Sine.easeInOut',
        });
        
        // Subtitle
        this.subtitle = this.add.text(centerX, 180, 'GRAVITY IS JUST A SUGGESTION', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '18px',
            color: '#666666',
            letterSpacing: 6,
        }).setOrigin(0.5);
        
        // Create menu buttons
        this.createMenuButtons();
        
        // Highscore display
        this.createHighscoreDisplay();
        
        // Controls hint
        this.createControlsHint();
        
        // Setup input
        this.setupInput();
        
        // Particle effect
        this.createParticles();
        
        // Listen for audio initialization
        this.input.once('pointerdown', () => this.initAudio());
        this.input.keyboard.once('keydown', () => this.initAudio());
    }
    
    initAudio() {
        if (!this.audioManager.initialized) {
            this.audioManager.init();
            this.audioManager.playMusic('menu');
        }
    }
    
    createBackground() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Starfield background
        this.starfield = this.add.tileSprite(0, 0, width, height, 'starfield')
            .setOrigin(0, 0)
            .setScrollFactor(0);
        
        // Grid overlay
        this.grid = this.add.tileSprite(0, 0, width, height, 'grid')
            .setOrigin(0, 0)
            .setScrollFactor(0)
            .setAlpha(0.3);
        
        // Gradient overlay
        const gradient = this.add.graphics();
        gradient.fillGradientStyle(0x0a0a0f, 0x0a0a0f, 0x1a1a2e, 0x1a1a2e, 0.8);
        gradient.fillRect(0, 0, width, height);
    }
    
    createMenuButtons() {
        const centerX = this.scale.width / 2;
        const startY = 280;
        const spacing = 60;
        
        this.menuOptions.forEach((option, index) => {
            const y = startY + index * spacing;
            
            // Button background
            const bg = this.add.graphics();
            bg.fillStyle(0x1a1a2e, 0.8);
            bg.fillRoundedRect(centerX - 150, y - 22, 300, 44, 8);
            bg.lineStyle(2, 0x00ffff, 0.3);
            bg.strokeRoundedRect(centerX - 150, y - 22, 300, 44, 8);
            
            // Button text
            const text = this.add.text(centerX, y, option, {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '24px',
                color: '#ffffff',
            }).setOrigin(0.5);
            
            // Store button data
            const button = { bg, text, index, y };
            this.buttons.push(button);
            
            // Interactive
            const hitArea = this.add.rectangle(centerX, y, 300, 44)
                .setInteractive({ useHandCursor: true })
                .on('pointerover', () => this.selectOption(index))
                .on('pointerdown', () => this.confirmSelection());
            
            button.hitArea = hitArea;
        });
        
        // Initial selection
        this.updateButtonStates();
    }
    
    selectOption(index) {
        if (this.transitioning) return;
        
        this.selectedOption = index;
        this.updateButtonStates();
        this.audioManager.playSFX('hover');
    }
    
    updateButtonStates() {
        this.buttons.forEach((button, index) => {
            const isSelected = index === this.selectedOption;
            
            // Update background
            button.bg.clear();
            
            if (isSelected) {
                button.bg.fillStyle(0x00ffff, 0.2);
                button.bg.fillRoundedRect(
                    this.scale.width / 2 - 150,
                    button.y - 22,
                    300, 44, 8
                );
                button.bg.lineStyle(2, 0x00ffff, 1);
            } else {
                button.bg.fillStyle(0x1a1a2e, 0.8);
                button.bg.lineStyle(2, 0x00ffff, 0.3);
            }
            
            button.bg.strokeRoundedRect(
                this.scale.width / 2 - 150,
                button.y - 22,
                300, 44, 8
            );
            
            // Update text color
            button.text.setColor(isSelected ? '#00ffff' : '#ffffff');
            
            // Scale animation for selected
            if (isSelected) {
                this.tweens.add({
                    targets: button.text,
                    scaleX: 1.1,
                    scaleY: 1.1,
                    duration: 100,
                });
            } else {
                this.tweens.add({
                    targets: button.text,
                    scaleX: 1,
                    scaleY: 1,
                    duration: 100,
                });
            }
        });
    }
    
    confirmSelection() {
        if (this.transitioning) return;
        
        this.audioManager.playSFX('select');
        this.transitioning = true;
        
        // Flash effect on selected button
        const button = this.buttons[this.selectedOption];
        this.tweens.add({
            targets: button.text,
            alpha: 0.5,
            duration: 50,
            yoyo: true,
            repeat: 2,
            onComplete: () => this.executeMenuOption(),
        });
    }
    
    executeMenuOption() {
        const option = this.menuOptions[this.selectedOption];
        
        switch (option) {
            case 'PLAY':
                this.startGame();
                break;
            case 'LEVEL SELECT':
                this.goToLevelSelect();
                break;
            case 'VEHICLES':
                this.goToVehicleSelect();
                break;
            case 'SETTINGS':
                this.goToSettings();
                break;
            case 'CREDITS':
                this.goToCredits();
                break;
        }
    }
    
    startGame() {
        // Start from level 1 or continue
        this.registry.set('currentLevel', 1);
        this.transitionTo('GameScene');
    }
    
    goToLevelSelect() {
        this.transitionTo('LevelSelectScene');
    }
    
    goToVehicleSelect() {
        // For now, show vehicle selection modal
        this.showVehicleModal();
    }
    
    goToSettings() {
        this.transitionTo('SettingsScene');
    }
    
    goToCredits() {
        this.transitionTo('CreditsScene');
    }
    
    transitionTo(scene) {
        this.cameras.main.fadeOut(300, 0, 0, 0);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.audioManager.stopMusic();
            this.scene.start(scene);
        });
    }
    
    showVehicleModal() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        const centerY = height / 2;
        
        // Overlay
        const overlay = this.add.rectangle(centerX, centerY, width, height, 0x000000, 0.7)
            .setInteractive()
            .setDepth(100);
        
        // Panel
        const panel = this.add.graphics().setDepth(101);
        panel.fillStyle(0x0a0a0f, 0.95);
        panel.fillRoundedRect(centerX - 250, centerY - 200, 500, 400, 16);
        panel.lineStyle(2, 0x00ffff, 0.8);
        panel.strokeRoundedRect(centerX - 250, centerY - 200, 500, 400, 16);
        
        // Title
        const title = this.add.text(centerX, centerY - 160, 'SELECT VEHICLE', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '28px',
            color: '#00ffff',
        }).setOrigin(0.5).setDepth(102);
        
        // Vehicle options
        const vehicles = Object.entries(VEHICLES);
        const vehicleButtons = [];
        const currentVehicle = this.registry.get('selectedVehicle');
        
        vehicles.forEach(([key, vehicle], index) => {
            const y = centerY - 80 + index * 70;
            
            const bg = this.add.graphics().setDepth(101);
            const isSelected = key === currentVehicle;
            
            bg.fillStyle(isSelected ? 0x00ffff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
            bg.fillRoundedRect(centerX - 200, y - 25, 400, 50, 8);
            bg.lineStyle(2, vehicle.color, isSelected ? 1 : 0.5);
            bg.strokeRoundedRect(centerX - 200, y - 25, 400, 50, 8);
            
            // Vehicle color indicator
            const indicator = this.add.graphics().setDepth(102);
            indicator.fillStyle(vehicle.color, 1);
            indicator.fillCircle(centerX - 170, y, 15);
            
            // Name
            const name = this.add.text(centerX - 140, y - 10, vehicle.name, {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '20px',
                color: isSelected ? '#00ffff' : '#ffffff',
            }).setDepth(102);
            
            // Description
            const desc = this.add.text(centerX - 140, y + 10, vehicle.description, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '14px',
                color: '#888888',
            }).setDepth(102);
            
            // Stats
            const stats = this.add.text(centerX + 100, y, 
                `SPD:${Math.round(vehicle.maxSpeed/10)} ACC:${Math.round(vehicle.acceleration/100)} HDL:${vehicle.handling}`, {
                fontFamily: 'Rajdhani, sans-serif',
                fontSize: '12px',
                color: '#666666',
            }).setOrigin(0, 0.5).setDepth(102);
            
            // Hit area
            const hit = this.add.rectangle(centerX, y, 400, 50)
                .setInteractive({ useHandCursor: true })
                .setDepth(103)
                .setAlpha(0.01)
                .on('pointerdown', () => {
                    this.registry.set('selectedVehicle', key);
                    this.audioManager.playSFX('select');
                    this.saveSettings();
                    closeModal();
                });
            
            vehicleButtons.push({ bg, indicator, name, desc, stats, hit });
        });
        
        // Close button
        const closeBtn = this.add.text(centerX, centerY + 160, 'CLOSE', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#ff00ff',
        }).setOrigin(0.5).setDepth(102)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => closeBtn.setColor('#ffffff'))
            .on('pointerout', () => closeBtn.setColor('#ff00ff'))
            .on('pointerdown', () => closeModal());
        
        const closeModal = () => {
            this.audioManager.playSFX('select');
            overlay.destroy();
            panel.destroy();
            title.destroy();
            closeBtn.destroy();
            vehicleButtons.forEach(b => {
                b.bg.destroy();
                b.indicator.destroy();
                b.name.destroy();
                b.desc.destroy();
                b.stats.destroy();
                b.hit.destroy();
            });
            this.transitioning = false;
        };
    }
    
    saveSettings() {
        try {
            const settings = {
                masterVolume: this.registry.get('masterVolume'),
                musicVolume: this.registry.get('musicVolume'),
                sfxVolume: this.registry.get('sfxVolume'),
                muted: this.registry.get('muted'),
                selectedVehicle: this.registry.get('selectedVehicle'),
            };
            localStorage.setItem(GAME_CONFIG.STORAGE.SETTINGS, JSON.stringify(settings));
        } catch (e) {
            console.warn('Could not save settings');
        }
    }
    
    createHighscoreDisplay() {
        const x = this.scale.width - 20;
        const y = 20;
        
        // Get total stars
        const totalStars = this.levelManager.getTotalStars();
        const maxStars = Object.keys(LEVELS).length * 3;
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a0a0f, 0.8);
        bg.fillRoundedRect(x - 150, y, 150, 60, 8);
        bg.lineStyle(1, 0xffff00, 0.5);
        bg.strokeRoundedRect(x - 150, y, 150, 60, 8);
        
        // Star icon
        this.add.image(x - 130, y + 30, 'star_filled').setScale(0.6);
        
        // Star count
        this.add.text(x - 105, y + 30, `${totalStars} / ${maxStars}`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '18px',
            color: '#ffff00',
        }).setOrigin(0, 0.5);
    }
    
    createControlsHint() {
        const y = this.scale.height - 30;
        const centerX = this.scale.width / 2;
        
        const hasTouch = this.registry.get('hasTouch');
        const hasGamepad = this.registry.get('hasGamepad');
        
        let hint = '↑↓ SELECT • ENTER CONFIRM';
        if (hasGamepad) {
            hint = 'D-PAD SELECT • A CONFIRM';
        } else if (hasTouch) {
            hint = 'TAP TO SELECT';
        }
        
        this.add.text(centerX, y, hint, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#444444',
        }).setOrigin(0.5);
    }
    
    createParticles() {
        // Floating particles in background
        this.particles = [];
        
        for (let i = 0; i < 30; i++) {
            const x = Math.random() * this.scale.width;
            const y = Math.random() * this.scale.height;
            
            const particle = this.add.graphics();
            particle.fillStyle(0x00ffff, Math.random() * 0.3 + 0.1);
            particle.fillCircle(0, 0, Math.random() * 2 + 1);
            particle.setPosition(x, y);
            
            this.particles.push({
                graphics: particle,
                speed: Math.random() * 20 + 10,
                angle: Math.random() * Math.PI * 2,
            });
        }
    }
    
    setupInput() {
        // Keyboard navigation
        this.input.keyboard.on('keydown-UP', () => {
            this.selectedOption = (this.selectedOption - 1 + this.menuOptions.length) % this.menuOptions.length;
            this.updateButtonStates();
            this.audioManager.playSFX('hover');
        });
        
        this.input.keyboard.on('keydown-DOWN', () => {
            this.selectedOption = (this.selectedOption + 1) % this.menuOptions.length;
            this.updateButtonStates();
            this.audioManager.playSFX('hover');
        });
        
        this.input.keyboard.on('keydown-ENTER', () => this.confirmSelection());
        this.input.keyboard.on('keydown-SPACE', () => this.confirmSelection());
        
        // Gamepad
        if (this.input.gamepad) {
            this.input.gamepad.on('down', (pad, button) => {
                if (button.index === 12) { // D-pad up
                    this.selectedOption = (this.selectedOption - 1 + this.menuOptions.length) % this.menuOptions.length;
                    this.updateButtonStates();
                } else if (button.index === 13) { // D-pad down
                    this.selectedOption = (this.selectedOption + 1) % this.menuOptions.length;
                    this.updateButtonStates();
                } else if (button.index === 0) { // A button
                    this.confirmSelection();
                }
            });
        }
    }
    
    update(time, delta) {
        // Animate background
        if (this.starfield) {
            this.starfield.tilePositionY -= 0.2;
        }
        if (this.grid) {
            this.grid.tilePositionY -= 0.5;
        }
        
        // Animate particles
        this.particles.forEach(p => {
            p.graphics.y -= p.speed * delta / 1000;
            p.graphics.x += Math.sin(time / 1000 + p.angle) * 0.5;
            
            if (p.graphics.y < -10) {
                p.graphics.y = this.scale.height + 10;
                p.graphics.x = Math.random() * this.scale.width;
            }
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.MenuScene = MenuScene;
}
