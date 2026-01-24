/**
 * GRAVSHIFT - Tutorial Scene
 * Interactive tutorial explaining game mechanics
 */

class TutorialScene extends Phaser.Scene {
    constructor() {
        super({ key: 'TutorialScene' });
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Background
        this.add.rectangle(centerX, height / 2, width, height, 0x0a0a0f);
        
        // Fade in
        this.cameras.main.fadeIn(500);
        
        // Tutorial steps
        this.currentStep = 0;
        this.steps = [
            {
                title: 'WELCOME TO GRAVSHIFT',
                text: 'A racing game where gravity is just a suggestion.\n\nThe track can twist and rotate in any direction.\nYour job is to stay on the road and survive.',
                highlight: null,
            },
            {
                title: 'CONTROLS',
                text: '← → or A D to steer left and right\n\nSPACE or SHIFT to activate boost\n\nESC or P to pause the game',
                highlight: 'controls',
            },
            {
                title: 'OBSTACLES',
                text: 'Avoid barriers, spikes, and lasers.\n\nHitting obstacles slows you down and breaks your combo.\n\n"Near misses" give you bonus points!',
                highlight: 'obstacles',
            },
            {
                title: 'POWER-UPS',
                text: 'Collect power-ups for special abilities:\n\n🔵 BOOST - Extra speed\n🟡 SHIELD - Invincibility\n🟣 SLOWMO - Time slows down\n👻 GHOST - Pass through obstacles',
                highlight: 'powerups',
            },
            {
                title: 'SCORING',
                text: 'Build combos by collecting power-ups,\navoiding obstacles closely, and drifting.\n\nHigher combos = higher multiplier = more points!',
                highlight: 'scoring',
            },
            {
                title: 'GRAVITY SHIFTS',
                text: 'The track will rotate and twist.\n\nStay calm and trust your instincts.\n\nGravity always pulls you toward the road.',
                highlight: 'gravity',
            },
            {
                title: 'READY?',
                text: 'Complete levels to unlock new challenges.\n\nEarn stars for high scores.\n\nUnlock the ENDLESS mode for the ultimate test!',
                highlight: null,
            },
        ];
        
        // Create UI
        this.createUI();
        
        // Show first step
        this.showStep(0);
        
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Input
        this.input.keyboard.on('keydown-ESC', () => this.skip());
        this.input.keyboard.on('keydown-ENTER', () => this.nextStep());
        this.input.keyboard.on('keydown-SPACE', () => this.nextStep());
        this.input.keyboard.on('keydown-RIGHT', () => this.nextStep());
        this.input.keyboard.on('keydown-LEFT', () => this.prevStep());
    }
    
    createUI() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        
        // Panel
        this.panel = this.add.graphics();
        this.panel.fillStyle(0x1a1a2e, 0.95);
        this.panel.fillRoundedRect(centerX - 300, 100, 600, 400, 16);
        this.panel.lineStyle(2, 0x00ffff, 0.8);
        this.panel.strokeRoundedRect(centerX - 300, 100, 600, 400, 16);
        
        // Title
        this.titleText = this.add.text(centerX, 140, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '32px',
            color: '#00ffff',
        }).setOrigin(0.5);
        
        // Content
        this.contentText = this.add.text(centerX, 280, '', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '20px',
            color: '#ffffff',
            align: 'center',
            lineSpacing: 10,
        }).setOrigin(0.5);
        
        // Step indicator
        this.stepIndicator = this.add.container(centerX, 450);
        for (let i = 0; i < this.steps.length; i++) {
            const dot = this.add.graphics();
            dot.fillStyle(0x444444, 1);
            dot.fillCircle((i - (this.steps.length - 1) / 2) * 25, 0, 6);
            this.stepIndicator.add(dot);
        }
        
        // Navigation buttons
        this.prevButton = new Button(this, centerX - 150, height - 80, '← PREV', {
            width: 120,
            color: 0x888888,
            onClick: () => this.prevStep(),
        });
        
        this.nextButton = new Button(this, centerX + 150, height - 80, 'NEXT →', {
            width: 120,
            color: 0x00ffff,
            onClick: () => this.nextStep(),
        });
        
        this.skipButton = new Button(this, width - 80, 40, 'SKIP', {
            width: 100,
            height: 35,
            fontSize: '14px',
            color: 0xff00ff,
            onClick: () => this.skip(),
        });
    }
    
    showStep(index) {
        this.currentStep = index;
        const step = this.steps[index];
        
        // Update content
        this.titleText.setText(step.title);
        this.contentText.setText(step.text);
        
        // Update step indicator
        this.stepIndicator.each((dot, i) => {
            dot.clear();
            dot.fillStyle(i === index ? 0x00ffff : 0x444444, 1);
            dot.fillCircle((i - (this.steps.length - 1) / 2) * 25, 0, 6);
        });
        
        // Update button states
        this.prevButton.setDisabled(index === 0);
        this.nextButton.setText(index === this.steps.length - 1 ? 'START!' : 'NEXT →');
        
        // Play sound
        this.audioManager.playSFX('hover');
    }
    
    nextStep() {
        if (this.currentStep < this.steps.length - 1) {
            this.showStep(this.currentStep + 1);
        } else {
            this.startGame();
        }
    }
    
    prevStep() {
        if (this.currentStep > 0) {
            this.showStep(this.currentStep - 1);
        }
    }
    
    skip() {
        this.startGame();
    }
    
    startGame() {
        // Mark tutorial as seen
        try {
            localStorage.setItem('gravshift_tutorial_seen', 'true');
        } catch (e) {}
        
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('GameScene', { levelId: 1 });
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.TutorialScene = TutorialScene;
}
