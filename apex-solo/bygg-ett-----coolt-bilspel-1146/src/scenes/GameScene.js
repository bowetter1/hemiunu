/**
 * GRAVSHIFT - Game Scene
 * Main gameplay with pseudo-3D track and gravity manipulation
 */

class GameScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameScene' });
    }
    
    init(data) {
        this.levelId = data.levelId || this.registry.get('currentLevel') || 1;
        this.isEndless = this.levelId === 'endless';
    }
    
    create() {
        console.log('GameScene.create() called with levelId:', this.levelId);

        const width = this.scale.width;
        const height = this.scale.height;

        // Debug: Add visible background to confirm rendering works
        this.add.rectangle(width / 2, height / 2, width, height, 0xff0000).setAlpha(0.1);
        console.log('Added debug background rectangle');

        // Debug: Add level text
        this.add.text(width / 2, 50, `LEVEL ${this.levelId} LOADING...`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '32px',
            color: '#ffffff',
            stroke: '#000000',
            strokeThickness: 4,
        }).setOrigin(0.5);
        console.log('Added level loading text');
        
        // Get level configuration
        this.levelConfig = LEVELS[this.levelId] || LEVELS[1];
        
        // Initialize managers
        this.initManagers();
        
        // Build track
        this.buildTrack();
        
        // Create player
        this.createPlayer();
        
        // Create HUD
        this.createHUD();
        
        // Setup game state
        this.setupGameState();
        
        // Setup event listeners
        this.setupEvents();
        
        // Setup input
        this.inputManager = new InputManager(this);
        this.player.setInputManager(this.inputManager);
        
        // Camera setup
        this.setupCamera();
        
        // Start countdown
        this.startCountdown();
        
        // Fade in
        this.cameras.main.fadeIn(500);
    }
    
    initManagers() {
        // Audio
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Score
        this.scoreManager = new ScoreManager(this);
        
        // Level
        this.levelManager = new LevelManager(this);
        
        // Particles
        this.particleManager = new ParticleManager(this);
        
        // Collision
        this.collisionManager = new CollisionManager(this);
        
        // Effects
        this.effectsManager = new EffectsManager(this);
        this.effectsManager.init();
        
        // Camera
        this.cameraManager = new CameraManager(this);
    }
    
    buildTrack() {
        console.log('Building track for level:', this.levelId, this.levelConfig);

        // Create track builder
        this.trackBuilder = new TrackBuilder(this, this.levelConfig);
        this.trackBuilder.build();

        console.log('Track segments created:', this.trackBuilder.segments.length);

        // Create track renderer
        this.trackRenderer = new TrackRenderer(this, this.trackBuilder);
        this.trackRenderer.init();

        console.log('Track renderer initialized');

        // Apply level theme
        if (this.levelConfig.theme) {
            this.trackRenderer.setTheme(this.levelConfig.theme);
            console.log('Theme applied:', this.levelConfig.theme);
        }
    }
    
    createPlayer() {
        const vehicleType = this.registry.get('selectedVehicle') || 'BALANCED';
        const startX = this.scale.width / 2;
        const startY = this.scale.height - 150;

        console.log('Creating player:', vehicleType, 'at', startX, startY);
        
        this.player = new Player(this, startX, startY, vehicleType);
        this.player.createVisuals(this);
        
        // Set track boundaries
        const trackWidth = this.levelConfig.track?.width || 400;
        const minX = (this.scale.width - trackWidth) / 2 + 30;
        const maxX = (this.scale.width + trackWidth) / 2 - 30;
        this.player.setBoundaries(minX, maxX);
    }
    
    createHUD() {
        this.hud = new HUD(this);
    }
    
    setupGameState() {
        console.log('Setting up game state for level:', this.levelId, 'config:', this.levelConfig);

        // Game state
        this.gameState = 'countdown'; // countdown, playing, paused, gameover, victory
        this.gameTime = 0;
        this.countdownValue = 3;
        
        // Track current rotation for gravity effect
        this.currentRotation = 0;
        this.targetRotation = 0;
        this.rotationIndex = 0;
        
        // Obstacles and powerups in active area
        this.activeObstacles = [];
        this.activePowerups = [];
        this.activeCheckpoints = [];
        
        // Level progress
        this.distanceTraveled = 0;
        this.targetDistance = this.levelConfig.goals?.target || 5000;
        
        // Ghost recording
        this.ghost = new Ghost(this);
        this.ghost.createVisuals(this);
        this.ghost.loadFromStorage(this.levelId);
        this.ghost.startRecording();
    }
    
    setupEvents() {
        // Score events
        this.events.on('scoreAdded', (data) => {
            // Visual feedback for score
        });
        
        this.events.on('comboChanged', (data) => {
            if (data.combo > 0 && data.combo % 5 === 0) {
                this.hud.showComboPopup(data.combo, data.multiplier);
                this.audioManager.playSFX('powerup');
            }
        });
        
        this.events.on('comboBroken', (data) => {
            this.cameraManager.shake(5, 100);
        });
        
        this.events.on('playerDrift', (deltaTime) => {
            this.scoreManager.addDriftTime(deltaTime);
            this.particleManager.emitTrail(
                this.player.x,
                this.player.y + 20,
                this.player.color,
                { x: this.player.velocity.x, y: this.player.speed }
            );
        });
        
        this.events.on('vehicleHit', (vehicle) => {
            this.onPlayerHit();
        });
        
        this.events.on('powerupCollected', (data) => {
            this.onPowerupCollected(data);
        });
        
        this.events.on('checkpointPassed', (data) => {
            this.onCheckpointPassed(data);
        });
        
        this.events.on('obstacleDestroyed', (obstacle) => {
            this.particleManager.emitExplosion(
                obstacle.x,
                obstacle.y,
                obstacle.color,
                20
            );
            this.scoreManager.recordObstacleDestroyed();
        });
        
        // Pause on window blur
        this.game.events.on('windowBlur', () => {
            if (this.gameState === 'playing') {
                this.pauseGame();
            }
        });
    }
    
    setupCamera() {
        // Camera follows player subtly
        this.cameraManager.follow(this.player, 0, -100);
    }
    
    startCountdown() {
        console.log('Starting countdown for level:', this.levelId);
        this.gameState = 'countdown';
        this.countdownValue = 3;
        
        // Create countdown display
        this.countdownText = this.add.text(
            this.scale.width / 2,
            this.scale.height / 2,
            '3',
            {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '120px',
                color: '#00ffff',
                stroke: '#000000',
                strokeThickness: 8,
            }
        ).setOrigin(0.5).setDepth(2000);
        
        // Countdown timer
        this.time.addEvent({
            delay: 1000,
            repeat: 3,
            callback: () => {
                this.countdownValue--;
                
                if (this.countdownValue > 0) {
                    this.countdownText.setText(this.countdownValue.toString());
                    this.audioManager.playSFX('beep');
                    
                    // Pulse animation
                    this.tweens.add({
                        targets: this.countdownText,
                        scaleX: 1.3,
                        scaleY: 1.3,
                        duration: 100,
                        yoyo: true,
                    });
                } else if (this.countdownValue === 0) {
                    this.countdownText.setText('GO!');
                    this.countdownText.setColor('#00ff00');
                    this.audioManager.playSFX('go');
                    
                    this.tweens.add({
                        targets: this.countdownText,
                        scaleX: 2,
                        scaleY: 2,
                        alpha: 0,
                        duration: 500,
                        onComplete: () => {
                            this.countdownText.destroy();
                        },
                    });
                    
                    this.startPlaying();
                }
            },
        });
    }
    
    startPlaying() {
        this.gameState = 'playing';
        this.audioManager.playMusic('game');
        
        // Start ghost playback if available
        if (this.ghost.recordedData.length > 0) {
            this.ghost.startPlayback();
        }
    }
    
    pauseGame() {
        if (this.gameState !== 'playing') return;
        
        this.gameState = 'paused';
        this.audioManager.pauseMusic();
        
        // Launch pause scene
        this.scene.launch('PauseScene', { parentScene: this });
        this.scene.pause();
    }
    
    resumeGame() {
        this.gameState = 'playing';
        this.audioManager.resumeMusic();
        this.scene.resume();
    }
    
    update(time, delta) {
        console.log('GameScene.update() called, gameState:', this.gameState, 'delta:', delta);

        if (this.gameState !== 'playing') {
            // Still render track even when paused
            this.trackRenderer.render();
            return;
        }
        
        // Update game time
        this.gameTime += delta;
        
        // Update input
        this.inputManager.update();
        
        // Check for pause
        if (this.inputManager.justPressed('pause')) {
            this.pauseGame();
            return;
        }
        
        // Update player
        this.player.update(delta);
        
        // Update track renderer and camera
        this.trackRenderer.updateCamera(this.player.x, this.player.speed, delta);
        
        // Update distance
        this.distanceTraveled = this.trackRenderer.getTrackPosition();
        this.scoreManager.addDistance(this.player.speed * delta / 1000 * 0.1);
        
        // Update track rotation (gravity effect)
        this.updateTrackRotation();
        
        // Update active objects
        this.updateActiveObjects();
        
        // Check collisions
        this.checkCollisions();
        
        // Update managers
        this.scoreManager.update(delta);
        this.particleManager.update(delta);
        this.effectsManager.update(delta);
        this.cameraManager.update(delta);
        
        // Update ghost
        this.ghost.recordFrame(this.player, this.gameTime);
        this.ghost.update(this.gameTime);
        
        // Render
        this.trackRenderer.render();
        this.player.render();
        this.ghost.render();
        this.renderParticles();
        
        // Update HUD
        this.updateHUD();
        
        // Check win/lose conditions
        this.checkGameConditions();
        
        // Endless mode: extend track
        if (this.isEndless && this.trackBuilder.segments.length - this.trackRenderer.cameraZ / 200 < 50) {
            this.trackBuilder.extendTrack(20);
        }
    }
    
    updateTrackRotation() {
        const segments = this.trackBuilder.segments;
        const currentSegment = this.trackBuilder.getSegmentAt(this.distanceTraveled);
        
        if (currentSegment && currentSegment.rotation !== this.currentRotation) {
            this.targetRotation = currentSegment.rotation;
        }
        
        // Smooth rotation transition
        this.currentRotation = MathUtils.lerp(this.currentRotation, this.targetRotation, 0.02);
        
        // Apply rotation to camera
        this.cameraManager.setRotation(this.currentRotation);
        this.trackRenderer.setTrackRotation(this.currentRotation);
        
        // Affect player controls based on rotation
        // (gravity shifts make steering feel different)
        const rotationEffect = Math.sin(MathUtils.degToRad(this.currentRotation)) * 0.3;
        // This could be used to modify player physics
    }
    
    updateActiveObjects() {
        const segments = this.trackBuilder.getVisibleSegments(
            this.trackRenderer.cameraZ,
            this.trackRenderer.drawDistance
        );
        
        // Collect active objects
        this.activeObstacles = [];
        this.activePowerups = [];
        this.activeCheckpoints = [];
        
        for (const segment of segments) {
            if (segment.obstacles) {
                this.activeObstacles.push(...segment.obstacles.filter(o => o.active));
            }
            if (segment.powerups) {
                this.activePowerups.push(...segment.powerups.filter(p => p.active && !p.collected));
            }
            if (segment.checkpoint && !segment.checkpoint.passed) {
                this.activeCheckpoints.push(segment.checkpoint);
            }
        }
        
        // Update obstacles
        for (const obstacle of this.activeObstacles) {
            obstacle.update(this.game.loop.delta);
        }
        
        // Update powerups
        for (const powerup of this.activePowerups) {
            powerup.update(this.game.loop.delta);
        }
    }
    
    checkCollisions() {
        // Get collision results
        const results = this.collisionManager.checkPlayerCollisions(
            this.player,
            this.activeObstacles,
            this.activePowerups,
            this.activeCheckpoints
        );
        
        // Handle collisions
        if (results.hit) {
            this.onPlayerHit();
        }
        
        // Handle near misses
        for (const nearMiss of results.nearMisses) {
            this.onNearMiss(nearMiss);
        }
        
        // Handle powerup collection
        for (const powerup of results.collectedPowerups) {
            powerup.collect(this.player);
        }
        
        // Handle checkpoint passes
        for (const checkpoint of results.passedCheckpoints) {
            checkpoint.pass();
        }
        
        // Check track bounds
        const bounds = this.collisionManager.checkTrackBounds(
            this.player,
            this.trackRenderer.getRoadBoundaries()
        );
        
        if (!bounds.inBounds) {
            // Player hitting edge - slow down and push back
            this.player.speed *= 0.98;
            if (bounds.edge === 'left') {
                this.player.x += 2;
            } else {
                this.player.x -= 2;
            }
            
            // Spark effect
            this.particleManager.emitSparks(
                this.player.x + (bounds.edge === 'left' ? -20 : 20),
                this.player.y,
                0xff8800,
                bounds.edge === 'left' ? 45 : 135,
                5
            );
        }
    }
    
    onPlayerHit() {
        if (this.player.isInvincible || this.player.isGhost) return;
        
        // Apply damage
        const tookDamage = this.player.takeDamage();
        
        if (tookDamage) {
            // Visual effects
            this.cameraManager.shake(15, 200);
            this.effectsManager.flash(0xff0000, 100, 0.5);
            this.audioManager.playSFX('hit');
            
            // Particles
            this.particleManager.emitExplosion(
                this.player.x,
                this.player.y,
                0xff0000,
                15
            );
            
            // Record hit
            this.scoreManager.recordHit();
            
            // Grant brief invincibility
            this.player.isInvincible = true;
            this.player.invincibleTimer = 1000;
        }
    }
    
    onNearMiss(obstacle) {
        this.scoreManager.recordNearMiss();
        this.hud.showBonusPopup('NEAR MISS!', GAME_CONFIG.SCORE.NEAR_MISS_BONUS);
        this.audioManager.playSFX('whoosh');
        
        // Particles
        this.particleManager.emitSparks(
            obstacle.x,
            obstacle.y,
            0x00ffff,
            this.player.x < obstacle.x ? 180 : 0,
            5
        );
    }
    
    onPowerupCollected(data) {
        this.scoreManager.recordPowerup();
        this.hud.showPowerup(data.type, data.name, POWERUPS[data.type].duration, data.color);
        this.hud.showBonusPopup(data.name, 50);
        this.audioManager.playSFX('powerup');
        
        // Collection effect
        this.particleManager.emitExplosion(data.x, data.y, data.color, 20);
        this.effectsManager.flash(data.color, 50, 0.3);
    }
    
    onCheckpointPassed(data) {
        this.scoreManager.recordCheckpoint();
        this.hud.showBonusPopup('CHECKPOINT!', GAME_CONFIG.SCORE.CHECKPOINT_BONUS);
        this.audioManager.playSFX('checkpoint');
        
        // Celebration effect
        this.effectsManager.checkpointCelebration(
            this.scale.width / 2,
            this.scale.height / 2,
            GAME_CONFIG.COLORS.CHECKPOINT
        );
    }
    
    renderParticles() {
        // Create graphics object for particles if not exists
        if (!this.particleGraphics) {
            this.particleGraphics = this.add.graphics();
            this.particleGraphics.setDepth(500);
        }
        
        this.particleManager.render(this.particleGraphics);
    }
    
    updateHUD() {
        this.hud.update({
            score: this.scoreManager.score,
            displayScore: this.scoreManager.displayScore,
            combo: this.scoreManager.combo,
            multiplier: this.scoreManager.multiplier,
            time: this.gameTime,
            speed: this.player.speed,
            maxSpeed: this.player.maxSpeed * this.player.boostMultiplier,
            nitro: this.player.nitro,
            maxNitro: this.player.nitroMax,
            isBoosting: this.player.isBoosting,
            distance: this.distanceTraveled,
            targetDistance: this.targetDistance,
            levelName: this.levelConfig.name,
        });
        
        // Update powerup timer
        this.hud.updatePowerup(this.game.loop.delta);
    }
    
    checkGameConditions() {
        const goals = this.levelConfig.goals;
        if (!goals) return;
        
        // Check win condition
        if (goals.type === 'distance' && this.distanceTraveled >= goals.target) {
            this.onVictory();
        }
        
        // Check time limit
        if (goals.timeLimit && this.gameTime >= goals.timeLimit) {
            this.onGameOver('TIME UP');
        }
        
        // Check survival (for survival mode levels)
        if (goals.type === 'survival' && this.gameTime >= goals.target) {
            this.onVictory();
        }
    }
    
    onVictory() {
        if (this.gameState !== 'playing') return;
        
        this.gameState = 'victory';
        this.audioManager.stopMusic();
        
        // Stop ghost recording and save if better
        const ghostData = this.ghost.stopRecording();
        
        // Calculate results
        const stats = this.scoreManager.getStats();
        stats.time = this.gameTime;
        
        const result = this.levelManager.completeLevel(stats);
        this.scoreManager.updateHighscore(this.levelId);
        
        // Save ghost if new record
        if (result.newRecord) {
            this.ghost.saveToStorage(this.levelId);
        }
        
        // Transition to victory scene
        this.time.delayedCall(500, () => {
            this.cameras.main.fadeOut(500);
            this.cameras.main.once('camerafadeoutcomplete', () => {
                this.scene.start('VictoryScene', {
                    levelId: this.levelId,
                    stats: stats,
                    stars: result.stars,
                    newRecord: result.newRecord,
                    nextUnlocked: result.nextUnlocked,
                });
            });
        });
    }
    
    onGameOver(reason = 'GAME OVER') {
        if (this.gameState !== 'playing') return;
        
        this.gameState = 'gameover';
        this.audioManager.stopMusic();
        this.audioManager.playSFX('gameover');
        
        // Stop ghost recording
        this.ghost.stopRecording();
        
        // Get stats
        const stats = this.scoreManager.getStats();
        stats.time = this.gameTime;
        stats.reason = reason;
        
        // Transition to game over scene
        this.time.delayedCall(1000, () => {
            this.cameras.main.fadeOut(500);
            this.cameras.main.once('camerafadeoutcomplete', () => {
                this.scene.start('GameOverScene', {
                    levelId: this.levelId,
                    stats: stats,
                });
            });
        });
    }
    
    shutdown() {
        // Clean up
        this.events.off('scoreAdded');
        this.events.off('comboChanged');
        this.events.off('comboBroken');
        this.events.off('playerDrift');
        this.events.off('vehicleHit');
        this.events.off('powerupCollected');
        this.events.off('checkpointPassed');
        this.events.off('obstacleDestroyed');
        
        if (this.audioManager) this.audioManager.destroy();
        if (this.trackRenderer) this.trackRenderer.destroy();
        if (this.player) this.player.destroy();
        if (this.ghost) this.ghost.destroy();
        if (this.hud) this.hud.destroy();
        if (this.effectsManager) this.effectsManager.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.GameScene = GameScene;
}
