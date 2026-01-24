/**
 * GRAVSHIFT - HUD (Heads-Up Display)
 * In-game UI showing score, speed, nitro, etc.
 */

class HUD {
    constructor(scene) {
        this.scene = scene;
        this.visible = true;
        
        // Container for all HUD elements
        this.container = scene.add.container(0, 0);
        this.container.setDepth(1000);
        
        // References
        this.elements = {};
        
        // Create HUD elements
        this.create();
    }
    
    create() {
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        const padding = 20;
        
        // === TOP LEFT: Score and Combo ===
        this.createScoreDisplay(padding, padding);
        
        // === TOP RIGHT: Level/Time info ===
        this.createLevelInfo(width - padding, padding);
        
        // === BOTTOM LEFT: Speedometer ===
        this.createSpeedometer(padding + 60, height - padding - 60);
        
        // === BOTTOM CENTER: Nitro Bar ===
        this.createNitroBar(width / 2, height - padding - 20);
        
        // === BOTTOM RIGHT: Mini-map or distance ===
        this.createDistanceDisplay(width - padding, height - padding - 30);
        
        // === CENTER: Combo popup area ===
        this.createComboPopup(width / 2, height / 2 - 100);
        
        // === TOP CENTER: Powerup display ===
        this.createPowerupDisplay(width / 2, padding + 20);
    }
    
    createScoreDisplay(x, y) {
        // Score background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x000000, 0.5);
        bg.fillRoundedRect(x, y, 200, 70, 8);
        this.container.add(bg);
        
        // Score label
        const label = this.scene.add.text(x + 10, y + 5, 'SCORE', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#888888',
        });
        this.container.add(label);
        
        // Score value
        this.elements.score = this.scene.add.text(x + 10, y + 18, '0', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '32px',
            color: '#00ffff',
        });
        this.container.add(this.elements.score);
        
        // Combo display
        this.elements.combo = this.scene.add.text(x + 10, y + 52, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '14px',
            color: '#ffff00',
        });
        this.container.add(this.elements.combo);
        
        // Multiplier
        this.elements.multiplier = this.scene.add.text(x + 150, y + 30, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#ff00ff',
        });
        this.container.add(this.elements.multiplier);
    }
    
    createLevelInfo(x, y) {
        // Level name
        this.elements.levelName = this.scene.add.text(x, y, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '16px',
            color: '#ffffff',
        }).setOrigin(1, 0);
        this.container.add(this.elements.levelName);
        
        // Time/Distance
        this.elements.time = this.scene.add.text(x, y + 25, '00:00.00', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '24px',
            color: '#00ffff',
        }).setOrigin(1, 0);
        this.container.add(this.elements.time);
        
        // Progress bar background
        const progressBg = this.scene.add.graphics();
        progressBg.fillStyle(0x333333, 0.8);
        progressBg.fillRoundedRect(x - 150, y + 55, 150, 8, 4);
        this.container.add(progressBg);
        
        // Progress bar fill
        this.elements.progressBar = this.scene.add.graphics();
        this.container.add(this.elements.progressBar);
        
        this.elements.progressX = x - 150;
        this.elements.progressY = y + 55;
    }
    
    createSpeedometer(x, y) {
        // Speedometer background circle
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x000000, 0.5);
        bg.fillCircle(x, y, 55);
        bg.lineStyle(3, 0x00ffff, 0.5);
        bg.strokeCircle(x, y, 55);
        this.container.add(bg);
        
        // Speed arc (will be drawn dynamically)
        this.elements.speedArc = this.scene.add.graphics();
        this.container.add(this.elements.speedArc);
        
        // Speed text
        this.elements.speed = this.scene.add.text(x, y - 5, '0', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '24px',
            color: '#ffffff',
        }).setOrigin(0.5);
        this.container.add(this.elements.speed);
        
        // KPH label
        const kphLabel = this.scene.add.text(x, y + 20, 'KM/H', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '10px',
            color: '#888888',
        }).setOrigin(0.5);
        this.container.add(kphLabel);
        
        this.elements.speedometerX = x;
        this.elements.speedometerY = y;
    }
    
    createNitroBar(x, y) {
        const barWidth = 300;
        const barHeight = 15;
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x000000, 0.5);
        bg.fillRoundedRect(x - barWidth / 2, y, barWidth, barHeight, 4);
        bg.lineStyle(2, 0xff00ff, 0.5);
        bg.strokeRoundedRect(x - barWidth / 2, y, barWidth, barHeight, 4);
        this.container.add(bg);
        
        // Nitro fill
        this.elements.nitroBar = this.scene.add.graphics();
        this.container.add(this.elements.nitroBar);
        
        // Nitro label
        const label = this.scene.add.text(x - barWidth / 2 - 50, y + barHeight / 2, 'NITRO', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#ff00ff',
        }).setOrigin(0, 0.5);
        this.container.add(label);
        
        this.elements.nitroX = x - barWidth / 2;
        this.elements.nitroY = y;
        this.elements.nitroWidth = barWidth;
        this.elements.nitroHeight = barHeight;
    }
    
    createDistanceDisplay(x, y) {
        // Distance label
        const label = this.scene.add.text(x, y, 'DISTANCE', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#888888',
        }).setOrigin(1, 0);
        this.container.add(label);
        
        // Distance value
        this.elements.distance = this.scene.add.text(x, y + 15, '0m', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#00ffff',
        }).setOrigin(1, 0);
        this.container.add(this.elements.distance);
    }
    
    createComboPopup(x, y) {
        // Combo popup text (hidden by default)
        this.elements.comboPopup = this.scene.add.text(x, y, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '36px',
            color: '#ffff00',
            stroke: '#000000',
            strokeThickness: 4,
        }).setOrigin(0.5).setAlpha(0);
        this.container.add(this.elements.comboPopup);
        
        // Bonus text
        this.elements.bonusPopup = this.scene.add.text(x, y + 50, '', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '24px',
            color: '#00ff00',
            stroke: '#000000',
            strokeThickness: 3,
        }).setOrigin(0.5).setAlpha(0);
        this.container.add(this.elements.bonusPopup);
    }
    
    createPowerupDisplay(x, y) {
        // Active powerup icon area
        this.elements.powerupBg = this.scene.add.graphics();
        this.container.add(this.elements.powerupBg);
        
        this.elements.powerupIcon = this.scene.add.graphics();
        this.container.add(this.elements.powerupIcon);
        
        this.elements.powerupText = this.scene.add.text(x, y + 30, '', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#ffffff',
        }).setOrigin(0.5).setAlpha(0);
        this.container.add(this.elements.powerupText);
        
        this.elements.powerupX = x;
        this.elements.powerupY = y;
        
        this.activePowerup = null;
    }
    
    /**
     * Update HUD with current game state
     */
    update(state) {
        // Update score
        this.elements.score.setText(MathUtils.formatNumber(state.displayScore || state.score || 0));
        
        // Update combo
        if (state.combo > 0) {
            this.elements.combo.setText(`COMBO x${state.combo}`);
            this.elements.multiplier.setText(`x${state.multiplier.toFixed(1)}`);
        } else {
            this.elements.combo.setText('');
            this.elements.multiplier.setText('');
        }
        
        // Update time
        this.elements.time.setText(MathUtils.formatTime(state.time || 0));
        
        // Update speed
        const speedKmh = Math.floor((state.speed || 0) * 0.5);
        this.elements.speed.setText(speedKmh.toString());
        this.drawSpeedArc(state.speed || 0, state.maxSpeed || 800);
        
        // Update nitro
        this.drawNitroBar(state.nitro || 0, state.maxNitro || 100, state.isBoosting);
        
        // Update distance
        this.elements.distance.setText(`${Math.floor(state.distance || 0)}m`);
        
        // Update progress
        if (state.targetDistance) {
            this.drawProgress((state.distance || 0) / state.targetDistance);
        }
        
        // Update level name
        if (state.levelName && this.elements.levelName.text !== state.levelName) {
            this.elements.levelName.setText(state.levelName);
        }
    }
    
    drawSpeedArc(speed, maxSpeed) {
        const g = this.elements.speedArc;
        g.clear();
        
        const x = this.elements.speedometerX;
        const y = this.elements.speedometerY;
        const radius = 45;
        
        const percent = Math.min(speed / maxSpeed, 1);
        const startAngle = Math.PI * 0.75;
        const endAngle = startAngle + (Math.PI * 1.5 * percent);
        
        // Speed arc
        const color = percent > 0.8 ? 0xff0000 : (percent > 0.6 ? 0xffff00 : 0x00ffff);
        g.lineStyle(6, color, 0.8);
        g.beginPath();
        g.arc(x, y, radius, startAngle, endAngle);
        g.strokePath();
        
        // Speed indicator needle
        const needleAngle = startAngle + (Math.PI * 1.5 * percent);
        const needleX = x + Math.cos(needleAngle) * (radius - 10);
        const needleY = y + Math.sin(needleAngle) * (radius - 10);
        
        g.fillStyle(0xffffff, 1);
        g.fillCircle(needleX, needleY, 4);
    }
    
    drawNitroBar(nitro, maxNitro, isBoosting) {
        const g = this.elements.nitroBar;
        g.clear();
        
        const x = this.elements.nitroX;
        const y = this.elements.nitroY;
        const width = this.elements.nitroWidth;
        const height = this.elements.nitroHeight;
        
        const percent = nitro / maxNitro;
        const fillWidth = width * percent;
        
        // Determine color
        let color = 0xff00ff;
        if (isBoosting) {
            color = 0xff8800;
        } else if (percent < 0.2) {
            color = 0xff0000;
        }
        
        // Fill
        g.fillStyle(color, 0.8);
        g.fillRoundedRect(x + 2, y + 2, Math.max(0, fillWidth - 4), height - 4, 2);
        
        // Glow when boosting
        if (isBoosting) {
            g.fillStyle(color, 0.3);
            g.fillRoundedRect(x - 2, y - 2, fillWidth + 4, height + 4, 4);
        }
    }
    
    drawProgress(percent) {
        const g = this.elements.progressBar;
        g.clear();
        
        const x = this.elements.progressX;
        const y = this.elements.progressY;
        const width = 150;
        const height = 8;
        
        g.fillStyle(0x00ffff, 0.8);
        g.fillRoundedRect(x, y, width * Math.min(percent, 1), height, 4);
    }
    
    /**
     * Show combo popup
     */
    showComboPopup(combo, multiplier) {
        const popup = this.elements.comboPopup;
        popup.setText(`${combo}x COMBO!`);
        popup.setAlpha(1);
        popup.setScale(1.5);
        
        this.scene.tweens.add({
            targets: popup,
            alpha: 0,
            scaleX: 1,
            scaleY: 1,
            y: popup.y - 50,
            duration: 1000,
            ease: 'Quad.easeOut',
            onComplete: () => {
                popup.y += 50;
            },
        });
    }
    
    /**
     * Show bonus popup
     */
    showBonusPopup(text, points) {
        const popup = this.elements.bonusPopup;
        popup.setText(`${text} +${points}`);
        popup.setAlpha(1);
        
        this.scene.tweens.add({
            targets: popup,
            alpha: 0,
            y: popup.y - 30,
            duration: 800,
            ease: 'Quad.easeOut',
            onComplete: () => {
                popup.y += 30;
            },
        });
    }
    
    /**
     * Show active powerup
     */
    showPowerup(type, name, duration, color) {
        this.activePowerup = { type, name, duration, remaining: duration, color };
        
        const x = this.elements.powerupX;
        const y = this.elements.powerupY;
        
        // Draw background
        this.elements.powerupBg.clear();
        this.elements.powerupBg.fillStyle(0x000000, 0.7);
        this.elements.powerupBg.fillRoundedRect(x - 40, y - 25, 80, 50, 8);
        this.elements.powerupBg.lineStyle(2, color, 1);
        this.elements.powerupBg.strokeRoundedRect(x - 40, y - 25, 80, 50, 8);
        
        // Draw icon
        this.elements.powerupIcon.clear();
        this.elements.powerupIcon.fillStyle(color, 1);
        this.elements.powerupIcon.fillCircle(x, y - 5, 15);
        
        // Show text
        this.elements.powerupText.setText(name);
        this.elements.powerupText.setAlpha(1);
    }
    
    /**
     * Update powerup timer
     */
    updatePowerup(deltaTime) {
        if (!this.activePowerup) return;
        
        this.activePowerup.remaining -= deltaTime;
        
        if (this.activePowerup.remaining <= 0) {
            this.hidePowerup();
        }
    }
    
    /**
     * Hide powerup display
     */
    hidePowerup() {
        this.activePowerup = null;
        this.elements.powerupBg.clear();
        this.elements.powerupIcon.clear();
        this.elements.powerupText.setAlpha(0);
    }
    
    /**
     * Set visibility
     */
    setVisible(visible) {
        this.visible = visible;
        this.container.setVisible(visible);
    }
    
    /**
     * Destroy HUD
     */
    destroy() {
        this.container.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.HUD = HUD;
}
