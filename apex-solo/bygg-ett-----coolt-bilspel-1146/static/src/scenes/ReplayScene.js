/**
 * ReplayScene.js
 * Replay viewer scene for watching recorded gameplay
 * Features playback controls, speed adjustment, seeking
 */

class ReplayScene extends Phaser.Scene {
    constructor() {
        super({ key: 'ReplayScene' });
        
        // Playback state
        this.replayData = null;
        this.isPlaying = false;
        this.isPaused = false;
        this.playbackSpeed = 1.0;
        this.currentFrame = 0;
        this.totalFrames = 0;
        this.playbackTime = 0;
        
        // UI elements
        this.controlsVisible = true;
        this.hideControlsTimer = 0;
        
        // Rendering
        this.trackGraphics = null;
        this.vehicleGraphics = null;
        this.effectsGraphics = null;
    }
    
    /**
     * Initialize with replay data
     */
    init(data) {
        this.replayId = data.replayId || null;
        this.returnScene = data.returnScene || 'MenuScene';
    }
    
    /**
     * Create scene elements
     */
    create() {
        const { width, height } = this.cameras.main;
        
        // Load replay
        this.loadReplay();
        
        // Background
        this.createBackground(width, height);
        
        // Game viewport
        this.createGameViewport(width, height);
        
        // UI overlay
        this.createUIOverlay(width, height);
        
        // Controls
        this.createPlaybackControls(width, height);
        
        // Info panel
        this.createInfoPanel(width);
        
        // Timeline
        this.createTimeline(width, height);
        
        // Input handling
        this.setupInput();
        
        // Start playback
        if (this.replayData) {
            this.startPlayback();
        }
    }
    
    /**
     * Load replay data
     */
    loadReplay() {
        if (this.replayId && window.ReplayManager) {
            this.replayData = ReplayManager.getReplay(this.replayId);
        }
        
        if (!this.replayData) {
            // Generate mock replay for demo
            this.replayData = this.generateMockReplay();
        }
        
        this.totalFrames = this.replayData.frames.length;
        this.totalDuration = this.replayData.duration || this.totalFrames / 60;
    }
    
    /**
     * Generate mock replay data
     */
    generateMockReplay() {
        const frames = [];
        const duration = 60; // 60 seconds
        const fps = 60;
        
        for (let i = 0; i < duration * fps; i++) {
            const t = i / fps;
            const progress = t / duration;
            
            // Simulate vehicle position along track
            const trackProgress = progress * 5000; // Distance
            const laneOffset = Math.sin(t * 0.5) * 50;
            const rotation = Math.sin(t * 2) * 15;
            
            frames.push({
                frame: i,
                time: t,
                player: {
                    x: 200 + Math.sin(progress * Math.PI * 4) * 100,
                    y: 300 - progress * 100 + Math.sin(t * 3) * 20,
                    rotation: rotation,
                    velocity: 200 + Math.sin(t) * 50,
                    boost: Math.random() > 0.95,
                    drift: Math.abs(rotation) > 10
                },
                track: {
                    rotation: Math.sin(t * 0.3) * 30,
                    segment: Math.floor(progress * 100)
                },
                score: Math.floor(progress * 500000),
                combo: Math.floor(Math.sin(t * 0.5) * 10 + 15),
                obstacles: this.generateMockObstacles(t),
                powerups: this.generateMockPowerups(t),
                effects: this.generateMockEffects(t)
            });
        }
        
        return {
            id: 'mock_replay',
            date: Date.now(),
            level: 'level_3',
            vehicle: 'racer',
            duration: duration,
            finalScore: 500000,
            frames: frames,
            metadata: {
                playerName: 'Player',
                version: '1.0.0'
            }
        };
    }
    
    /**
     * Generate mock obstacles for a frame
     */
    generateMockObstacles(time) {
        const obstacles = [];
        const seed = Math.floor(time * 2);
        
        for (let i = 0; i < 3; i++) {
            const obstacleTime = seed + i * 10;
            if (Math.sin(obstacleTime) > 0.7) {
                obstacles.push({
                    x: 150 + (i * 100),
                    y: 200 + Math.sin(obstacleTime * 0.5) * 100,
                    type: ['BARRIER', 'SPIKE', 'DEBRIS'][i % 3],
                    rotation: time * 50
                });
            }
        }
        
        return obstacles;
    }
    
    /**
     * Generate mock powerups for a frame
     */
    generateMockPowerups(time) {
        const powerups = [];
        
        if (Math.sin(time * 0.8) > 0.9) {
            powerups.push({
                x: 250 + Math.sin(time) * 100,
                y: 250,
                type: ['BOOST', 'SHIELD', 'SLOWMO'][Math.floor(time) % 3]
            });
        }
        
        return powerups;
    }
    
    /**
     * Generate mock effects for a frame
     */
    generateMockEffects(time) {
        const effects = [];
        
        // Boost trail
        if (Math.sin(time * 2) > 0.8) {
            for (let i = 0; i < 5; i++) {
                effects.push({
                    type: 'particle',
                    x: 200 - i * 15,
                    y: 300 + Math.random() * 10,
                    alpha: 1 - i * 0.2,
                    color: 0x00ffff
                });
            }
        }
        
        return effects;
    }
    
    /**
     * Create background
     */
    createBackground(width, height) {
        const graphics = this.add.graphics();
        
        // Dark space background
        graphics.fillStyle(0x050a15, 1);
        graphics.fillRect(0, 0, width, height);
        
        // Stars
        for (let i = 0; i < 100; i++) {
            const x = Math.random() * width;
            const y = Math.random() * height;
            const size = Math.random() * 2;
            const alpha = Math.random() * 0.5 + 0.2;
            
            graphics.fillStyle(0xffffff, alpha);
            graphics.fillCircle(x, y, size);
        }
    }
    
    /**
     * Create game viewport for replay rendering
     */
    createGameViewport(width, height) {
        // Viewport bounds
        this.viewportX = 20;
        this.viewportY = 60;
        this.viewportWidth = width - 40;
        this.viewportHeight = height - 180;
        
        // Viewport border
        const border = this.add.graphics();
        border.lineStyle(2, 0x00ffff, 0.5);
        border.strokeRect(this.viewportX, this.viewportY, this.viewportWidth, this.viewportHeight);
        
        // Graphics layers
        this.trackGraphics = this.add.graphics();
        this.obstacleGraphics = this.add.graphics();
        this.powerupGraphics = this.add.graphics();
        this.vehicleGraphics = this.add.graphics();
        this.effectsGraphics = this.add.graphics();
        
        // Mask for viewport
        const mask = this.add.graphics();
        mask.fillStyle(0xffffff);
        mask.fillRect(this.viewportX, this.viewportY, this.viewportWidth, this.viewportHeight);
        
        const geometryMask = mask.createGeometryMask();
        
        this.trackGraphics.setMask(geometryMask);
        this.obstacleGraphics.setMask(geometryMask);
        this.powerupGraphics.setMask(geometryMask);
        this.vehicleGraphics.setMask(geometryMask);
        this.effectsGraphics.setMask(geometryMask);
    }
    
    /**
     * Create UI overlay elements
     */
    createUIOverlay(width, height) {
        // Header bar
        const header = this.add.graphics();
        header.fillStyle(0x0a1020, 0.9);
        header.fillRect(0, 0, width, 55);
        header.lineStyle(1, 0x00ffff, 0.3);
        header.lineBetween(0, 55, width, 55);
        
        // Title
        this.add.text(width / 2, 27, 'REPLAY VIEWER', {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#00ffff'
        }).setOrigin(0.5);
        
        // Back button
        const backBtn = this.add.text(20, 27, '< BACK', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#667788'
        }).setOrigin(0, 0.5).setInteractive({ useHandCursor: true });
        
        backBtn.on('pointerdown', () => this.goBack());
        backBtn.on('pointerover', () => backBtn.setColor('#00ffff'));
        backBtn.on('pointerout', () => backBtn.setColor('#667788'));
        
        // Score display
        this.scoreText = this.add.text(width - 20, 20, 'SCORE: 0', {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: '#ffaa00'
        }).setOrigin(1, 0);
        
        // Combo display
        this.comboText = this.add.text(width - 20, 38, 'COMBO: 0x', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ff4488'
        }).setOrigin(1, 0);
    }
    
    /**
     * Create playback controls
     */
    createPlaybackControls(width, height) {
        const controlsY = height - 100;
        const controlsContainer = this.add.container(width / 2, controlsY);
        
        // Background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a1525, 0.95);
        bg.fillRoundedRect(-180, -30, 360, 60, 10);
        bg.lineStyle(1, 0x334455, 0.5);
        bg.strokeRoundedRect(-180, -30, 360, 60, 10);
        controlsContainer.add(bg);
        
        // Play/Pause button
        this.playPauseBtn = this.createControlButton(controlsContainer, 0, 0, 'PLAY', () => {
            this.togglePlayback();
        });
        
        // Rewind button
        this.createControlButton(controlsContainer, -70, 0, '<<', () => {
            this.seekRelative(-5);
        });
        
        // Fast forward button
        this.createControlButton(controlsContainer, 70, 0, '>>', () => {
            this.seekRelative(5);
        });
        
        // Speed control
        this.speedText = this.add.text(150, 0, '1.0x', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#00ffff'
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        this.speedText.on('pointerdown', () => this.cycleSpeed());
        controlsContainer.add(this.speedText);
        
        // Restart button
        this.createControlButton(controlsContainer, -140, 0, '|<', () => {
            this.restart();
        });
        
        this.controlsContainer = controlsContainer;
    }
    
    /**
     * Create a control button
     */
    createControlButton(container, x, y, label, callback) {
        const btn = this.add.container(x, y);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x1a2535, 0.9);
        bg.fillRoundedRect(-20, -15, 40, 30, 5);
        btn.add(bg);
        
        const text = this.add.text(0, 0, label, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffffff'
        }).setOrigin(0.5);
        btn.add(text);
        
        const zone = this.add.zone(0, 0, 40, 30)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', callback);
        zone.on('pointerover', () => {
            bg.clear();
            bg.fillStyle(0x2a3545, 0.9);
            bg.fillRoundedRect(-20, -15, 40, 30, 5);
        });
        zone.on('pointerout', () => {
            bg.clear();
            bg.fillStyle(0x1a2535, 0.9);
            bg.fillRoundedRect(-20, -15, 40, 30, 5);
        });
        
        btn.add(zone);
        container.add(btn);
        
        return { bg, text, zone };
    }
    
    /**
     * Create info panel
     */
    createInfoPanel(width) {
        const panel = this.add.container(20, this.viewportY + this.viewportHeight + 10);
        
        // Level info
        this.levelText = this.add.text(0, 0, `Level: ${this.replayData.level.replace('_', ' ').toUpperCase()}`, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        panel.add(this.levelText);
        
        // Vehicle info
        this.vehicleText = this.add.text(150, 0, `Vehicle: ${this.replayData.vehicle.toUpperCase()}`, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        panel.add(this.vehicleText);
        
        // Date
        const dateStr = new Date(this.replayData.date).toLocaleDateString();
        this.dateText = this.add.text(300, 0, `Date: ${dateStr}`, {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#667788'
        });
        panel.add(this.dateText);
    }
    
    /**
     * Create timeline scrubber
     */
    createTimeline(width, height) {
        const timelineY = height - 40;
        const timelineWidth = width - 80;
        const timelineX = 40;
        
        // Background track
        const bg = this.add.graphics();
        bg.fillStyle(0x1a2535, 1);
        bg.fillRoundedRect(timelineX, timelineY, timelineWidth, 8, 4);
        
        // Progress bar
        this.timelineProgress = this.add.graphics();
        
        // Scrubber handle
        this.scrubber = this.add.graphics();
        this.updateTimelineProgress(0);
        
        // Time labels
        this.currentTimeText = this.add.text(timelineX - 5, timelineY + 4, '0:00', {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        }).setOrigin(1, 0.5);
        
        this.totalTimeText = this.add.text(timelineX + timelineWidth + 5, timelineY + 4,
            this.formatTime(this.totalDuration), {
            fontFamily: 'Arial',
            fontSize: '11px',
            color: '#667788'
        }).setOrigin(0, 0.5);
        
        // Interactive timeline
        const timelineZone = this.add.zone(timelineX + timelineWidth / 2, timelineY + 4, timelineWidth, 20)
            .setInteractive({ useHandCursor: true });
        
        timelineZone.on('pointerdown', (pointer) => {
            const progress = (pointer.x - timelineX) / timelineWidth;
            this.seekToProgress(Phaser.Math.Clamp(progress, 0, 1));
        });
        
        this.timelineX = timelineX;
        this.timelineWidth = timelineWidth;
        this.timelineY = timelineY;
    }
    
    /**
     * Update timeline progress
     */
    updateTimelineProgress(progress) {
        const x = this.timelineX || 40;
        const width = this.timelineWidth || 400;
        const y = this.timelineY || 400;
        
        // Progress fill
        this.timelineProgress.clear();
        this.timelineProgress.fillStyle(0x00ffff, 0.8);
        this.timelineProgress.fillRoundedRect(x, y, width * progress, 8, 4);
        
        // Scrubber handle
        this.scrubber.clear();
        this.scrubber.fillStyle(0x00ffff, 1);
        this.scrubber.fillCircle(x + width * progress, y + 4, 8);
        this.scrubber.fillStyle(0xffffff, 0.8);
        this.scrubber.fillCircle(x + width * progress, y + 4, 4);
    }
    
    /**
     * Setup input handling
     */
    setupInput() {
        // Keyboard controls
        this.input.keyboard.on('keydown-SPACE', () => this.togglePlayback());
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        this.input.keyboard.on('keydown-LEFT', () => this.seekRelative(-1));
        this.input.keyboard.on('keydown-RIGHT', () => this.seekRelative(1));
        this.input.keyboard.on('keydown-UP', () => this.adjustSpeed(0.25));
        this.input.keyboard.on('keydown-DOWN', () => this.adjustSpeed(-0.25));
        this.input.keyboard.on('keydown-R', () => this.restart());
    }
    
    /**
     * Start playback
     */
    startPlayback() {
        this.isPlaying = true;
        this.isPaused = false;
        this.currentFrame = 0;
        this.playbackTime = 0;
        
        this.updatePlayPauseButton();
    }
    
    /**
     * Toggle play/pause
     */
    togglePlayback() {
        if (this.isPlaying && !this.isPaused) {
            this.isPaused = true;
        } else {
            this.isPlaying = true;
            this.isPaused = false;
        }
        
        this.updatePlayPauseButton();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Update play/pause button text
     */
    updatePlayPauseButton() {
        if (this.playPauseBtn) {
            const label = (this.isPlaying && !this.isPaused) ? 'PAUSE' : 'PLAY';
            this.playPauseBtn.text.setText(label);
        }
    }
    
    /**
     * Seek relative to current position
     */
    seekRelative(seconds) {
        const targetTime = this.playbackTime + seconds;
        const targetFrame = Math.floor(targetTime * 60);
        this.currentFrame = Phaser.Math.Clamp(targetFrame, 0, this.totalFrames - 1);
        this.playbackTime = this.currentFrame / 60;
        
        this.renderFrame(this.replayData.frames[this.currentFrame]);
    }
    
    /**
     * Seek to specific progress (0-1)
     */
    seekToProgress(progress) {
        this.currentFrame = Math.floor(progress * (this.totalFrames - 1));
        this.playbackTime = this.currentFrame / 60;
        
        this.renderFrame(this.replayData.frames[this.currentFrame]);
    }
    
    /**
     * Restart replay
     */
    restart() {
        this.currentFrame = 0;
        this.playbackTime = 0;
        this.isPlaying = true;
        this.isPaused = false;
        
        this.updatePlayPauseButton();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Cycle through playback speeds
     */
    cycleSpeed() {
        const speeds = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0];
        const currentIndex = speeds.indexOf(this.playbackSpeed);
        const nextIndex = (currentIndex + 1) % speeds.length;
        this.playbackSpeed = speeds[nextIndex];
        
        this.speedText.setText(`${this.playbackSpeed}x`);
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Adjust speed incrementally
     */
    adjustSpeed(delta) {
        this.playbackSpeed = Phaser.Math.Clamp(this.playbackSpeed + delta, 0.25, 4.0);
        this.speedText.setText(`${this.playbackSpeed.toFixed(2)}x`);
    }
    
    /**
     * Main update loop
     */
    update(time, delta) {
        if (!this.replayData || !this.replayData.frames) return;
        
        // Advance playback
        if (this.isPlaying && !this.isPaused) {
            this.playbackTime += (delta / 1000) * this.playbackSpeed;
            this.currentFrame = Math.floor(this.playbackTime * 60);
            
            // Loop or stop at end
            if (this.currentFrame >= this.totalFrames) {
                this.currentFrame = this.totalFrames - 1;
                this.playbackTime = this.totalDuration;
                this.isPaused = true;
                this.updatePlayPauseButton();
            }
        }
        
        // Render current frame
        const frame = this.replayData.frames[this.currentFrame];
        if (frame) {
            this.renderFrame(frame);
        }
        
        // Update timeline
        const progress = this.currentFrame / (this.totalFrames - 1);
        this.updateTimelineProgress(progress);
        this.currentTimeText.setText(this.formatTime(this.playbackTime));
        
        // Update score display
        if (frame) {
            this.scoreText.setText(`SCORE: ${this.formatScore(frame.score)}`);
            this.comboText.setText(`COMBO: ${frame.combo}x`);
        }
    }
    
    /**
     * Render a single frame
     */
    renderFrame(frame) {
        if (!frame) return;
        
        const offsetX = this.viewportX;
        const offsetY = this.viewportY;
        
        // Clear graphics
        this.trackGraphics.clear();
        this.obstacleGraphics.clear();
        this.powerupGraphics.clear();
        this.vehicleGraphics.clear();
        this.effectsGraphics.clear();
        
        // Render track
        this.renderTrack(frame.track, offsetX, offsetY);
        
        // Render obstacles
        this.renderObstacles(frame.obstacles, offsetX, offsetY);
        
        // Render powerups
        this.renderPowerups(frame.powerups, offsetX, offsetY);
        
        // Render effects
        this.renderEffects(frame.effects, offsetX, offsetY);
        
        // Render vehicle
        this.renderVehicle(frame.player, offsetX, offsetY);
    }
    
    /**
     * Render track segment
     */
    renderTrack(trackData, offsetX, offsetY) {
        const g = this.trackGraphics;
        const centerX = offsetX + this.viewportWidth / 2;
        const centerY = offsetY + this.viewportHeight / 2;
        
        // Track lanes
        g.lineStyle(3, 0x1a3050, 0.8);
        
        const trackWidth = 200;
        const laneCount = 3;
        
        for (let i = 0; i <= laneCount; i++) {
            const laneX = centerX - trackWidth / 2 + (i * trackWidth / laneCount);
            g.lineBetween(laneX, offsetY, laneX, offsetY + this.viewportHeight);
        }
        
        // Lane markers
        g.fillStyle(0x00ffff, 0.3);
        const markerSpacing = 40;
        const markerOffset = (trackData.segment * 2) % markerSpacing;
        
        for (let y = offsetY - markerOffset; y < offsetY + this.viewportHeight; y += markerSpacing) {
            for (let i = 1; i < laneCount; i++) {
                const markerX = centerX - trackWidth / 2 + (i * trackWidth / laneCount);
                g.fillRect(markerX - 2, y, 4, 15);
            }
        }
        
        // Edge glow
        g.lineStyle(2, 0x00ffff, 0.5);
        g.lineBetween(centerX - trackWidth / 2, offsetY, centerX - trackWidth / 2, offsetY + this.viewportHeight);
        g.lineBetween(centerX + trackWidth / 2, offsetY, centerX + trackWidth / 2, offsetY + this.viewportHeight);
    }
    
    /**
     * Render obstacles
     */
    renderObstacles(obstacles, offsetX, offsetY) {
        const g = this.obstacleGraphics;
        
        obstacles.forEach(obs => {
            const x = offsetX + obs.x;
            const y = offsetY + obs.y;
            
            switch (obs.type) {
                case 'BARRIER':
                    g.fillStyle(0xff4444, 0.9);
                    g.fillRect(x - 30, y - 10, 60, 20);
                    g.lineStyle(2, 0xff8888, 0.8);
                    g.strokeRect(x - 30, y - 10, 60, 20);
                    break;
                    
                case 'SPIKE':
                    g.fillStyle(0xff8800, 0.9);
                    g.fillTriangle(x, y - 15, x - 12, y + 10, x + 12, y + 10);
                    break;
                    
                case 'DEBRIS':
                    g.fillStyle(0x888888, 0.8);
                    const angle = obs.rotation * Math.PI / 180;
                    const size = 15;
                    const corners = [
                        { x: -size, y: -size },
                        { x: size, y: -size },
                        { x: size, y: size },
                        { x: -size, y: size }
                    ].map(c => ({
                        x: x + c.x * Math.cos(angle) - c.y * Math.sin(angle),
                        y: y + c.x * Math.sin(angle) + c.y * Math.cos(angle)
                    }));
                    
                    g.fillTriangle(corners[0].x, corners[0].y, corners[1].x, corners[1].y, corners[2].x, corners[2].y);
                    g.fillTriangle(corners[0].x, corners[0].y, corners[2].x, corners[2].y, corners[3].x, corners[3].y);
                    break;
            }
        });
    }
    
    /**
     * Render powerups
     */
    renderPowerups(powerups, offsetX, offsetY) {
        const g = this.powerupGraphics;
        
        powerups.forEach(pu => {
            const x = offsetX + pu.x;
            const y = offsetY + pu.y;
            const r = 15;
            
            // Outer glow
            const color = {
                'BOOST': 0x00ffff,
                'SHIELD': 0x44ff44,
                'SLOWMO': 0xffff00
            }[pu.type] || 0xffffff;
            
            g.fillStyle(color, 0.2);
            g.fillCircle(x, y, r + 5);
            
            g.fillStyle(color, 0.8);
            g.fillCircle(x, y, r);
            
            g.lineStyle(2, 0xffffff, 0.5);
            g.strokeCircle(x, y, r);
        });
    }
    
    /**
     * Render visual effects
     */
    renderEffects(effects, offsetX, offsetY) {
        const g = this.effectsGraphics;
        
        effects.forEach(effect => {
            const x = offsetX + effect.x;
            const y = offsetY + effect.y;
            
            if (effect.type === 'particle') {
                g.fillStyle(effect.color, effect.alpha);
                g.fillCircle(x, y, 3);
            }
        });
    }
    
    /**
     * Render player vehicle
     */
    renderVehicle(playerData, offsetX, offsetY) {
        const g = this.vehicleGraphics;
        const x = offsetX + playerData.x;
        const y = offsetY + playerData.y;
        const rotation = playerData.rotation * Math.PI / 180;
        
        // Vehicle body
        const width = 30;
        const height = 50;
        
        // Calculate rotated corners
        const corners = [
            { x: 0, y: -height / 2 },      // Front
            { x: -width / 2, y: height / 2 }, // Back left
            { x: width / 2, y: height / 2 }   // Back right
        ].map(c => ({
            x: x + c.x * Math.cos(rotation) - c.y * Math.sin(rotation),
            y: y + c.x * Math.sin(rotation) + c.y * Math.cos(rotation)
        }));
        
        // Main body
        g.fillStyle(0x00ffff, 0.9);
        g.fillTriangle(
            corners[0].x, corners[0].y,
            corners[1].x, corners[1].y,
            corners[2].x, corners[2].y
        );
        
        // Outline
        g.lineStyle(2, 0xffffff, 0.8);
        g.strokeTriangle(
            corners[0].x, corners[0].y,
            corners[1].x, corners[1].y,
            corners[2].x, corners[2].y
        );
        
        // Boost effect
        if (playerData.boost) {
            g.fillStyle(0xff8800, 0.8);
            g.fillCircle(
                (corners[1].x + corners[2].x) / 2,
                (corners[1].y + corners[2].y) / 2,
                10
            );
        }
        
        // Drift indicator
        if (playerData.drift) {
            g.lineStyle(3, 0xff4488, 0.6);
            g.lineBetween(corners[1].x, corners[1].y, corners[1].x - 20, corners[1].y + 10);
            g.lineBetween(corners[2].x, corners[2].y, corners[2].x + 20, corners[2].y + 10);
        }
    }
    
    /**
     * Go back to previous scene
     */
    goBack() {
        this.isPlaying = false;
        
        if (window.SoundManager) {
            SoundManager.play('ui_back');
        }
        
        this.scene.start(this.returnScene);
    }
    
    /**
     * Format time as MM:SS
     */
    formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }
    
    /**
     * Format score with separators
     */
    formatScore(score) {
        return score.toLocaleString();
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.ReplayScene = ReplayScene;
}
