/**
 * GRAVSHIFT - Preload Scene
 * Asset loading with animated progress bar
 */

class PreloadScene extends Phaser.Scene {
    constructor() {
        super({ key: 'PreloadScene' });
        this.loadProgress = 0;
        this.assetsToGenerate = 20;
        this.assetsGenerated = 0;
    }
    
    init() {
        this.cameras.main.setBackgroundColor(GAME_CONFIG.COLORS.BACKGROUND);
    }
    
    preload() {
        this.createLoadingUI();
        
        // Setup load events
        this.load.on('progress', this.updateProgress, this);
        this.load.on('complete', this.loadComplete, this);
        
        // We generate most assets procedurally, but load any external assets here
        // For now, simulate loading time while generating procedural assets
    }
    
    create() {
        // Generate procedural assets
        this.generateProceduralAssets();
    }
    
    createLoadingUI() {
        const width = this.scale.width;
        const height = this.scale.height;
        const centerX = width / 2;
        const centerY = height / 2;
        
        // Background
        this.add.rectangle(centerX, centerY, width, height, GAME_CONFIG.COLORS.BACKGROUND);
        
        // Title with glow effect
        this.titleText = this.add.text(centerX, centerY - 100, 'GRAVSHIFT', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '64px',
            fontWeight: 'bold',
            color: '#00ffff',
            align: 'center',
        }).setOrigin(0.5);
        
        // Subtitle
        this.subtitleText = this.add.text(centerX, centerY - 40, 'GRAVITY IS JUST A SUGGESTION', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '18px',
            color: '#888888',
            align: 'center',
            letterSpacing: 8,
        }).setOrigin(0.5);
        
        // Loading bar background
        this.loadBarBg = this.add.graphics();
        this.loadBarBg.fillStyle(0x1a1a2e, 1);
        this.loadBarBg.fillRoundedRect(centerX - 150, centerY + 50, 300, 8, 4);
        
        // Loading bar fill
        this.loadBar = this.add.graphics();
        
        // Loading text
        this.loadingText = this.add.text(centerX, centerY + 80, 'INITIALIZING...', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#00ffff',
            align: 'center',
        }).setOrigin(0.5);
        
        // Pulsing animation for title
        this.tweens.add({
            targets: this.titleText,
            alpha: 0.7,
            duration: 1000,
            yoyo: true,
            repeat: -1,
            ease: 'Sine.easeInOut',
        });
        
        // Version text
        this.add.text(width - 10, height - 10, 'v1.0.0', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#444444',
        }).setOrigin(1, 1);
    }
    
    updateProgress(progress) {
        this.loadProgress = progress;
        this.drawLoadBar();
    }

    loadComplete() {
        // Called when Phaser's asset loading is complete
        // We still need to wait for procedural assets to finish
        console.log('Asset loading complete');
    }
    
    drawLoadBar() {
        const width = this.scale.width;
        const centerX = width / 2;
        const centerY = this.scale.height / 2;
        const barWidth = 300;
        const progress = (this.loadProgress * 0.5) + (this.assetsGenerated / this.assetsToGenerate * 0.5);
        
        this.loadBar.clear();
        
        // Gradient effect
        const gradient = this.loadBar.createGeometryMask();
        
        // Main bar
        this.loadBar.fillStyle(0x00ffff, 1);
        this.loadBar.fillRoundedRect(
            centerX - 150,
            centerY + 50,
            barWidth * Math.min(progress, 1),
            8,
            4
        );
        
        // Glow effect
        this.loadBar.fillStyle(0x00ffff, 0.3);
        this.loadBar.fillRoundedRect(
            centerX - 152,
            centerY + 48,
            (barWidth + 4) * Math.min(progress, 1),
            12,
            6
        );
    }
    
    generateProceduralAssets() {
        const steps = [
            { name: 'GENERATING VEHICLE SPRITES...', fn: () => this.generateVehicleSprites() },
            { name: 'CREATING PARTICLE TEXTURES...', fn: () => this.generateParticleTextures() },
            { name: 'BUILDING OBSTACLE SPRITES...', fn: () => this.generateObstacleSprites() },
            { name: 'CREATING POWERUP GRAPHICS...', fn: () => this.generatePowerupSprites() },
            { name: 'GENERATING UI ELEMENTS...', fn: () => this.generateUIElements() },
            { name: 'CREATING TRACK TEXTURES...', fn: () => this.generateTrackTextures() },
            { name: 'BUILDING BACKGROUND LAYERS...', fn: () => this.generateBackgrounds() },
            { name: 'INITIALIZING SYSTEMS...', fn: () => this.initializeSystems() },
        ];
        
        this.assetsToGenerate = steps.length;
        
        // Process each step with delay for visual feedback
        steps.forEach((step, index) => {
            this.time.delayedCall(index * 150, () => {
                this.loadingText.setText(step.name);
                step.fn();
                this.assetsGenerated++;
                this.drawLoadBar();
                
                if (this.assetsGenerated >= this.assetsToGenerate) {
                    this.finishLoading();
                }
            });
        });
    }
    
    generateVehicleSprites() {
        // Generate vehicle sprites for each type
        Object.entries(VEHICLES).forEach(([key, vehicle]) => {
            const graphics = this.make.graphics({ x: 0, y: 0, add: false });
            
            // Vehicle body (futuristic shape)
            graphics.fillStyle(vehicle.color, 1);
            
            // Main body
            graphics.fillTriangle(25, 0, 0, 50, 50, 50);
            
            // Cockpit
            graphics.fillStyle(ColorUtils.darken(vehicle.color, 0.3), 1);
            graphics.fillTriangle(25, 10, 15, 35, 35, 35);
            
            // Engine glow
            graphics.fillStyle(vehicle.color, 0.8);
            graphics.fillRect(10, 45, 10, 8);
            graphics.fillRect(30, 45, 10, 8);
            
            // Wing details
            graphics.lineStyle(2, ColorUtils.lighten(vehicle.color, 0.3), 1);
            graphics.lineBetween(5, 40, 20, 25);
            graphics.lineBetween(45, 40, 30, 25);
            
            graphics.generateTexture(`vehicle_${key.toLowerCase()}`, 50, 60);
            graphics.destroy();
        });
    }
    
    generateParticleTextures() {
        // Basic particle
        const particle = this.make.graphics({ x: 0, y: 0, add: false });
        particle.fillStyle(0xffffff, 1);
        particle.fillCircle(8, 8, 8);
        particle.generateTexture('particle', 16, 16);
        particle.destroy();
        
        // Glow particle
        const glow = this.make.graphics({ x: 0, y: 0, add: false });
        for (let i = 16; i > 0; i--) {
            const alpha = i / 16;
            glow.fillStyle(0xffffff, alpha * 0.3);
            glow.fillCircle(16, 16, i);
        }
        glow.generateTexture('glow', 32, 32);
        glow.destroy();
        
        // Trail particle
        const trail = this.make.graphics({ x: 0, y: 0, add: false });
        trail.fillStyle(0xffffff, 1);
        trail.fillEllipse(16, 4, 32, 8);
        trail.generateTexture('trail', 32, 8);
        trail.destroy();
        
        // Spark
        const spark = this.make.graphics({ x: 0, y: 0, add: false });
        spark.fillStyle(0xffffff, 1);
        spark.fillRect(0, 3, 16, 2);
        spark.generateTexture('spark', 16, 8);
        spark.destroy();
    }
    
    generateObstacleSprites() {
        // Barrier
        const barrier = this.make.graphics({ x: 0, y: 0, add: false });
        barrier.fillStyle(OBSTACLES.BARRIER.color, 1);
        barrier.fillRect(0, 0, 100, 50);
        barrier.lineStyle(3, ColorUtils.lighten(OBSTACLES.BARRIER.color, 0.5), 1);
        barrier.strokeRect(0, 0, 100, 50);
        // Warning stripes
        barrier.fillStyle(0x000000, 0.5);
        for (let i = 0; i < 5; i++) {
            barrier.fillRect(i * 25, 0, 12, 50);
        }
        barrier.generateTexture('obstacle_barrier', 100, 50);
        barrier.destroy();
        
        // Spike
        const spike = this.make.graphics({ x: 0, y: 0, add: false });
        spike.fillStyle(OBSTACLES.SPIKE.color, 1);
        spike.fillTriangle(20, 0, 0, 60, 40, 60);
        spike.lineStyle(2, ColorUtils.lighten(OBSTACLES.SPIKE.color, 0.5), 1);
        spike.strokeTriangle(20, 0, 0, 60, 40, 60);
        spike.generateTexture('obstacle_spike', 40, 60);
        spike.destroy();
        
        // Laser
        const laser = this.make.graphics({ x: 0, y: 0, add: false });
        laser.fillStyle(OBSTACLES.LASER.color, 0.8);
        laser.fillRect(0, 0, 200, 10);
        laser.fillStyle(0xffffff, 1);
        laser.fillRect(0, 4, 200, 2);
        laser.generateTexture('obstacle_laser', 200, 10);
        laser.destroy();
    }
    
    generatePowerupSprites() {
        Object.entries(POWERUPS).forEach(([key, powerup]) => {
            const graphics = this.make.graphics({ x: 0, y: 0, add: false });
            
            // Outer glow
            for (let i = 30; i > 20; i--) {
                const alpha = (30 - i) / 10 * 0.3;
                graphics.fillStyle(powerup.color, alpha);
                graphics.fillCircle(30, 30, i);
            }
            
            // Inner orb
            graphics.fillStyle(powerup.color, 1);
            graphics.fillCircle(30, 30, 15);
            
            // Highlight
            graphics.fillStyle(0xffffff, 0.5);
            graphics.fillCircle(25, 25, 5);
            
            // Icon based on type
            graphics.fillStyle(0xffffff, 1);
            switch (key) {
                case 'BOOST':
                    // Arrow up
                    graphics.fillTriangle(30, 20, 22, 35, 38, 35);
                    break;
                case 'SHIELD':
                    // Shield shape
                    graphics.lineStyle(3, 0xffffff, 1);
                    graphics.strokeCircle(30, 30, 10);
                    break;
                case 'SLOWMO':
                    // Clock
                    graphics.lineStyle(2, 0xffffff, 1);
                    graphics.strokeCircle(30, 30, 8);
                    graphics.lineBetween(30, 30, 30, 24);
                    graphics.lineBetween(30, 30, 35, 30);
                    break;
                case 'MAGNET':
                    // Magnet shape
                    graphics.fillRect(25, 25, 4, 12);
                    graphics.fillRect(31, 25, 4, 12);
                    graphics.fillRect(25, 22, 10, 4);
                    break;
                case 'GHOST':
                    // Ghost outline
                    graphics.lineStyle(2, 0xffffff, 0.5);
                    graphics.strokeCircle(30, 30, 10);
                    break;
            }
            
            graphics.generateTexture(`powerup_${key.toLowerCase()}`, 60, 60);
            graphics.destroy();
        });
    }
    
    generateUIElements() {
        // Button
        const button = this.make.graphics({ x: 0, y: 0, add: false });
        button.fillStyle(0x1a1a2e, 1);
        button.fillRoundedRect(0, 0, 200, 50, 8);
        button.lineStyle(2, 0x00ffff, 1);
        button.strokeRoundedRect(0, 0, 200, 50, 8);
        button.generateTexture('button', 200, 50);
        button.destroy();
        
        // Button hover
        const buttonHover = this.make.graphics({ x: 0, y: 0, add: false });
        buttonHover.fillStyle(0x00ffff, 0.2);
        buttonHover.fillRoundedRect(0, 0, 200, 50, 8);
        buttonHover.lineStyle(2, 0x00ffff, 1);
        buttonHover.strokeRoundedRect(0, 0, 200, 50, 8);
        buttonHover.generateTexture('button_hover', 200, 50);
        buttonHover.destroy();
        
        // Panel
        const panel = this.make.graphics({ x: 0, y: 0, add: false });
        panel.fillStyle(0x0a0a0f, 0.9);
        panel.fillRoundedRect(0, 0, 400, 300, 16);
        panel.lineStyle(2, 0x00ffff, 0.5);
        panel.strokeRoundedRect(0, 0, 400, 300, 16);
        panel.generateTexture('panel', 400, 300);
        panel.destroy();
        
        // Star (filled)
        const starFilled = this.make.graphics({ x: 0, y: 0, add: false });
        this.drawStar(starFilled, 20, 20, 5, 20, 10, 0xffff00, 1);
        starFilled.generateTexture('star_filled', 40, 40);
        starFilled.destroy();
        
        // Star (empty)
        const starEmpty = this.make.graphics({ x: 0, y: 0, add: false });
        this.drawStar(starEmpty, 20, 20, 5, 20, 10, 0x444444, 1);
        starEmpty.generateTexture('star_empty', 40, 40);
        starEmpty.destroy();
    }
    
    drawStar(graphics, cx, cy, spikes, outerRadius, innerRadius, color, alpha) {
        graphics.fillStyle(color, alpha);
        graphics.beginPath();
        
        let rot = Math.PI / 2 * 3;
        const step = Math.PI / spikes;
        
        graphics.moveTo(cx, cy - outerRadius);
        
        for (let i = 0; i < spikes; i++) {
            let x = cx + Math.cos(rot) * outerRadius;
            let y = cy + Math.sin(rot) * outerRadius;
            graphics.lineTo(x, y);
            rot += step;
            
            x = cx + Math.cos(rot) * innerRadius;
            y = cy + Math.sin(rot) * innerRadius;
            graphics.lineTo(x, y);
            rot += step;
        }
        
        graphics.lineTo(cx, cy - outerRadius);
        graphics.closePath();
        graphics.fillPath();
    }
    
    generateTrackTextures() {
        // Road segment
        const road = this.make.graphics({ x: 0, y: 0, add: false });
        road.fillStyle(GAME_CONFIG.COLORS.ROAD, 1);
        road.fillRect(0, 0, 400, 100);
        
        // Lane markers
        road.fillStyle(GAME_CONFIG.COLORS.LANE_MARKER, 0.5);
        road.fillRect(130, 0, 4, 100);
        road.fillRect(266, 0, 4, 100);
        
        // Edge glow
        road.fillStyle(GAME_CONFIG.COLORS.EDGE_GLOW, 0.8);
        road.fillRect(0, 0, 4, 100);
        road.fillRect(396, 0, 4, 100);
        
        road.generateTexture('road_segment', 400, 100);
        road.destroy();
        
        // Checkpoint line
        const checkpoint = this.make.graphics({ x: 0, y: 0, add: false });
        checkpoint.fillStyle(GAME_CONFIG.COLORS.CHECKPOINT, 1);
        checkpoint.fillRect(0, 0, 400, 10);
        checkpoint.fillStyle(0xffffff, 0.5);
        for (let i = 0; i < 20; i += 2) {
            checkpoint.fillRect(i * 20, 0, 20, 10);
        }
        checkpoint.generateTexture('checkpoint', 400, 10);
        checkpoint.destroy();
    }
    
    generateBackgrounds() {
        // Starfield
        const stars = this.make.graphics({ x: 0, y: 0, add: false });
        stars.fillStyle(0x0a0a0f, 1);
        stars.fillRect(0, 0, 800, 600);
        
        // Random stars
        for (let i = 0; i < 200; i++) {
            const x = Math.random() * 800;
            const y = Math.random() * 600;
            const size = Math.random() * 2 + 0.5;
            const brightness = Math.random();
            
            stars.fillStyle(0xffffff, brightness);
            stars.fillCircle(x, y, size);
        }
        
        stars.generateTexture('starfield', 800, 600);
        stars.destroy();
        
        // Grid pattern
        const grid = this.make.graphics({ x: 0, y: 0, add: false });
        grid.lineStyle(1, 0x00ffff, 0.1);
        
        for (let x = 0; x <= 800; x += 50) {
            grid.lineBetween(x, 0, x, 600);
        }
        for (let y = 0; y <= 600; y += 50) {
            grid.lineBetween(0, y, 800, y);
        }
        
        grid.generateTexture('grid', 800, 600);
        grid.destroy();
    }
    
    initializeSystems() {
        // Pre-create any shared systems or data
        console.log('GRAVSHIFT systems initialized');
    }
    
    finishLoading() {
        this.loadingText.setText('READY');
        
        // Final animations
        this.tweens.add({
            targets: [this.loadingText, this.loadBar, this.loadBarBg],
            alpha: 0,
            duration: 500,
            delay: 500,
        });
        
        this.tweens.add({
            targets: this.titleText,
            y: this.scale.height / 2 - 50,
            scaleX: 1.2,
            scaleY: 1.2,
            duration: 800,
            delay: 500,
            ease: 'Back.easeOut',
        });
        
        this.tweens.add({
            targets: this.subtitleText,
            alpha: 0,
            duration: 300,
            delay: 500,
        });
        
        // Transition to menu
        this.time.delayedCall(1500, () => {
            this.cameras.main.fadeOut(500, 0, 0, 0);
            this.cameras.main.once('camerafadeoutcomplete', () => {
                this.scene.start('MenuScene');
            });
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.PreloadScene = PreloadScene;
}
