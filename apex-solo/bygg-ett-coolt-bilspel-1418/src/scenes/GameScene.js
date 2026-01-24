/**
 * Main game scene - Full game loop with deliveries
 */
import { COLORS, GAME_CONFIG, PASSENGER_STATES } from '../config/constants.js';
import { Car } from '../entities/Car.js';
import { Passenger } from '../entities/Passenger.js';
import { ScreenEffects } from '../systems/ScreenEffects.js';

export class GameScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameScene' });
    }
    
    create() {
        // Game state
        this.score = 0;
        this.deliveries = 0;
        this.timeLeft = GAME_CONFIG.DELIVERY_TIME;
        this.panicLevel = 0;
        this.passengerState = PASSENGER_STATES.CALM;
        this.hasPassenger = false;
        this.gameOver = false;
        
        // Screen effects
        this.effects = new ScreenEffects(this);
        
        // Draw background
        this.drawBackground();
        
        // Create pickup and dropoff points
        this.createDestinations();
        
        // Create car
        this.car = new Car(this, GAME_CONFIG.WIDTH / 2, GAME_CONFIG.HEIGHT - 100);
        
        // Create passenger visual
        this.passenger = new Passenger(this);
        
        // Create UI
        this.createUI();
        
        // Drift particles
        this.driftSmoke = [];
        
        // Tire marks
        this.tireMarks = this.add.graphics();
        this.tireMarks.setDepth(1);
        
        // Timer
        this.timerEvent = this.time.addEvent({
            delay: 1000,
            callback: this.onTimerTick,
            callbackScope: this,
            loop: true
        });
        
        // Start with a pickup point active
        this.activatePickup();
    }
    
    drawBackground() {
        const g = this.add.graphics();
        
        // Grass background with slight texture
        g.fillStyle(COLORS.GRASS);
        g.fillRect(0, 0, GAME_CONFIG.WIDTH, GAME_CONFIG.HEIGHT);
        
        // Add some grass texture dots
        g.fillStyle(0x2d8a5e); // Darker green
        for (let i = 0; i < 100; i++) {
            const x = Phaser.Math.Between(0, GAME_CONFIG.WIDTH);
            const y = Phaser.Math.Between(0, GAME_CONFIG.HEIGHT);
            g.fillCircle(x, y, 2);
        }
        
        // Main roads - grid pattern
        g.fillStyle(COLORS.ROAD);
        
        // Horizontal roads
        g.fillRect(0, 100, GAME_CONFIG.WIDTH, 80);
        g.fillRect(0, GAME_CONFIG.HEIGHT / 2 - 40, GAME_CONFIG.WIDTH, 80);
        g.fillRect(0, GAME_CONFIG.HEIGHT - 180, GAME_CONFIG.WIDTH, 80);
        
        // Vertical roads
        g.fillRect(100, 0, 80, GAME_CONFIG.HEIGHT);
        g.fillRect(GAME_CONFIG.WIDTH / 2 - 40, 0, 80, GAME_CONFIG.HEIGHT);
        g.fillRect(GAME_CONFIG.WIDTH - 180, 0, 80, GAME_CONFIG.HEIGHT);
        
        // Road edge lines (white)
        g.lineStyle(2, COLORS.TEXT, 0.5);
        
        // Horizontal road edges
        g.lineBetween(0, 100, GAME_CONFIG.WIDTH, 100);
        g.lineBetween(0, 180, GAME_CONFIG.WIDTH, 180);
        g.lineBetween(0, GAME_CONFIG.HEIGHT / 2 - 40, GAME_CONFIG.WIDTH, GAME_CONFIG.HEIGHT / 2 - 40);
        g.lineBetween(0, GAME_CONFIG.HEIGHT / 2 + 40, GAME_CONFIG.WIDTH, GAME_CONFIG.HEIGHT / 2 + 40);
        g.lineBetween(0, GAME_CONFIG.HEIGHT - 180, GAME_CONFIG.WIDTH, GAME_CONFIG.HEIGHT - 180);
        g.lineBetween(0, GAME_CONFIG.HEIGHT - 100, GAME_CONFIG.WIDTH, GAME_CONFIG.HEIGHT - 100);
        
        // Road markings (center lines - dashed yellow)
        g.fillStyle(COLORS.UI_ACCENT);
        
        // Horizontal markings
        for (let x = 0; x < GAME_CONFIG.WIDTH; x += 40) {
            g.fillRect(x, 138, 20, 4);
            g.fillRect(x, GAME_CONFIG.HEIGHT / 2 - 2, 20, 4);
            g.fillRect(x, GAME_CONFIG.HEIGHT - 142, 20, 4);
        }
        
        // Vertical markings  
        for (let y = 0; y < GAME_CONFIG.HEIGHT; y += 40) {
            g.fillRect(138, y, 4, 20);
            g.fillRect(GAME_CONFIG.WIDTH / 2 - 2, y, 4, 20);
            g.fillRect(GAME_CONFIG.WIDTH - 142, y, 4, 20);
        }
        
        // Buildings/decorations at corners
        this.drawBuildings(g);
    }
    
    drawBuildings(g) {
        const buildingColor = COLORS.CAR_ACCENT;
        const roofColor = COLORS.PANIC;
        const windowColor = COLORS.UI_ACCENT;
        
        // Helper to draw a simple building
        const drawBuilding = (x, y, w, h) => {
            // Building body
            g.fillStyle(buildingColor);
            g.fillRect(x, y, w, h);
            
            // Roof
            g.fillStyle(roofColor);
            g.fillRect(x - 3, y - 8, w + 6, 10);
            
            // Windows
            g.fillStyle(windowColor, 0.6);
            const winW = 8;
            const winH = 10;
            const padding = 6;
            for (let wx = x + padding; wx < x + w - winW; wx += winW + padding) {
                for (let wy = y + padding; wy < y + h - winH - 5; wy += winH + padding) {
                    g.fillRect(wx, wy, winW, winH);
                }
            }
        };
        
        // Corner buildings (avoiding roads)
        drawBuilding(10, 10, 70, 70);           // Top-left
        drawBuilding(200, 10, 50, 70);          // Top 
        drawBuilding(GAME_CONFIG.WIDTH - 80, 10, 70, 70);  // Top-right
        
        drawBuilding(10, 200, 70, 80);          // Left
        drawBuilding(GAME_CONFIG.WIDTH - 80, 200, 70, 80); // Right
        
        drawBuilding(10, GAME_CONFIG.HEIGHT - 80, 70, 70);  // Bottom-left
        drawBuilding(200, GAME_CONFIG.HEIGHT - 80, 50, 70); // Bottom
        drawBuilding(GAME_CONFIG.WIDTH - 80, GAME_CONFIG.HEIGHT - 80, 70, 70); // Bottom-right
    }
    
    createDestinations() {
        // Possible pickup/dropoff locations (at intersections)
        this.locations = [
            { x: 140, y: 140, name: 'North Station' },
            { x: GAME_CONFIG.WIDTH / 2, y: 140, name: 'Central Park' },
            { x: GAME_CONFIG.WIDTH - 140, y: 140, name: 'East Side' },
            { x: 140, y: GAME_CONFIG.HEIGHT / 2, name: 'West End' },
            { x: GAME_CONFIG.WIDTH - 140, y: GAME_CONFIG.HEIGHT / 2, name: 'Downtown' },
            { x: 140, y: GAME_CONFIG.HEIGHT - 140, name: 'South Bay' },
            { x: GAME_CONFIG.WIDTH / 2, y: GAME_CONFIG.HEIGHT - 140, name: 'Main Square' },
            { x: GAME_CONFIG.WIDTH - 140, y: GAME_CONFIG.HEIGHT - 140, name: 'Harbor' },
        ];
        
        // Pickup marker (green)
        this.pickupMarker = this.add.container(0, 0);
        const pickupCircle = this.add.graphics();
        pickupCircle.fillStyle(COLORS.CALM, 0.3);
        pickupCircle.fillCircle(0, 0, 40);
        pickupCircle.lineStyle(4, COLORS.CALM);
        pickupCircle.strokeCircle(0, 0, 40);
        const pickupIcon = this.add.text(0, 0, '🧑', { fontSize: '28px' }).setOrigin(0.5);
        this.pickupMarker.add([pickupCircle, pickupIcon]);
        this.pickupMarker.setVisible(false);
        this.pickupMarker.setDepth(5);
        
        // Dropoff marker (orange/destination)
        this.dropoffMarker = this.add.container(0, 0);
        const dropoffCircle = this.add.graphics();
        dropoffCircle.fillStyle(COLORS.CAR_BODY, 0.3);
        dropoffCircle.fillCircle(0, 0, 40);
        dropoffCircle.lineStyle(4, COLORS.CAR_BODY);
        dropoffCircle.strokeCircle(0, 0, 40);
        const dropoffIcon = this.add.text(0, 0, '📍', { fontSize: '28px' }).setOrigin(0.5);
        this.dropoffMarker.add([dropoffCircle, dropoffIcon]);
        this.dropoffMarker.setVisible(false);
        this.dropoffMarker.setDepth(5);
        
        // Arrow pointing to destination
        this.directionArrow = this.add.text(0, 0, '➤', {
            fontSize: '32px',
            color: '#fff',
        }).setOrigin(0.5).setDepth(50);
        this.directionArrow.setVisible(false);
        
        // Pulse animations
        this.tweens.add({
            targets: [this.pickupMarker, this.dropoffMarker],
            scale: { from: 1, to: 1.1 },
            duration: 500,
            yoyo: true,
            repeat: -1,
        });
    }
    
    activatePickup() {
        // Choose random location for pickup
        const loc = Phaser.Utils.Array.GetRandom(this.locations);
        this.pickupMarker.setPosition(loc.x, loc.y);
        this.pickupMarker.setVisible(true);
        this.currentPickup = loc;
        this.currentTarget = loc;
        this.dropoffMarker.setVisible(false);
        this.statusText.setText(`🧑 Pick up at ${loc.name}`);
        this.directionArrow.setVisible(true);
    }
    
    activateDropoff() {
        // Choose random location different from pickup
        const available = this.locations.filter(l => l !== this.currentPickup);
        const loc = Phaser.Utils.Array.GetRandom(available);
        this.dropoffMarker.setPosition(loc.x, loc.y);
        this.dropoffMarker.setVisible(true);
        this.pickupMarker.setVisible(false);
        this.currentDropoff = loc;
        this.currentTarget = loc;
        this.statusText.setText(`📍 Go to ${loc.name}`);
    }
    
    createUI() {
        // Top bar background
        const topBar = this.add.graphics();
        topBar.fillStyle(COLORS.DARK, 0.85);
        topBar.fillRoundedRect(5, 5, GAME_CONFIG.WIDTH - 10, 65, 8);
        topBar.setDepth(200);
        
        // Panic meter background
        this.add.graphics()
            .fillStyle(COLORS.ROAD)
            .fillRoundedRect(15, 15, 180, 22, 6)
            .setDepth(201);
        
        // Panic meter fill
        this.panicFill = this.add.graphics().setDepth(202);
        
        // Panic label
        this.panicLabel = this.add.text(15, 40, '😊 CALM', {
            fontFamily: 'Arial',
            fontSize: '13px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setDepth(203);
        
        // Score
        this.scoreText = this.add.text(GAME_CONFIG.WIDTH - 15, 15, 'SCORE: 0', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '18px',
            color: '#' + COLORS.UI_ACCENT.toString(16).padStart(6, '0'),
        }).setOrigin(1, 0).setDepth(203);
        
        // Time
        this.timeText = this.add.text(GAME_CONFIG.WIDTH - 15, 40, `⏱️ ${this.timeLeft}s`, {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(1, 0).setDepth(203);
        
        // Deliveries counter
        this.deliveryText = this.add.text(GAME_CONFIG.WIDTH / 2, 15, '🚕 Deliveries: 0', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5, 0).setDepth(203);
        
        // Status/objective text
        this.statusText = this.add.text(GAME_CONFIG.WIDTH / 2, 45, '', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5, 0).setDepth(203);
        
        // Drift indicator (bottom)
        this.driftText = this.add.text(GAME_CONFIG.WIDTH / 2, GAME_CONFIG.HEIGHT - 25, '', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '26px',
            color: '#' + COLORS.UI_ACCENT.toString(16).padStart(6, '0'),
            stroke: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
            strokeThickness: 4,
        }).setOrigin(0.5).setDepth(203);
        
        // Speed bar (bottom right)
        this.speedBg = this.add.graphics().setDepth(200);
        this.speedBg.fillStyle(COLORS.DARK, 0.7);
        this.speedBg.fillRoundedRect(GAME_CONFIG.WIDTH - 90, GAME_CONFIG.HEIGHT - 50, 80, 40, 6);
        
        this.speedText = this.add.text(GAME_CONFIG.WIDTH - 50, GAME_CONFIG.HEIGHT - 30, '0', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '20px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5).setDepth(201);
        
        this.add.text(GAME_CONFIG.WIDTH - 50, GAME_CONFIG.HEIGHT - 15, 'km/h', {
            fontFamily: 'Arial',
            fontSize: '10px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5).setDepth(201);
    }
    
    onTimerTick() {
        if (this.gameOver) return;
        
        this.timeLeft--;
        this.timeText.setText(`⏱️ ${this.timeLeft}s`);
        
        if (this.timeLeft <= 10) {
            this.timeText.setColor('#' + COLORS.DANGER.toString(16).padStart(6, '0'));
            // Pulse effect on low time
            this.tweens.add({
                targets: this.timeText,
                scale: { from: 1, to: 1.2 },
                duration: 100,
                yoyo: true,
            });
        }
        
        if (this.timeLeft <= 0) {
            this.endGame('time_up');
        }
    }
    
    spawnDriftSmoke() {
        const pos = this.car.getPosition();
        const smoke = this.add.graphics();
        smoke.fillStyle(COLORS.TEXT, 0.3);
        smoke.fillCircle(0, 0, 5);
        smoke.x = pos.x + Phaser.Math.Between(-12, 12);
        smoke.y = pos.y + Phaser.Math.Between(-12, 12);
        smoke.alpha = 0.4;
        smoke.scale = 0.4;
        smoke.setDepth(2);
        
        this.driftSmoke.push(smoke);
        
        this.tweens.add({
            targets: smoke,
            alpha: 0,
            scale: 1.2,
            duration: 350,
            onComplete: () => {
                smoke.destroy();
                this.driftSmoke = this.driftSmoke.filter(s => s !== smoke);
            }
        });
    }
    
    drawTireMark() {
        const pos = this.car.getPosition();
        this.tireMarks.fillStyle(COLORS.DARK, 0.15);
        this.tireMarks.fillCircle(pos.x + Phaser.Math.Between(-8, 8), pos.y + Phaser.Math.Between(-8, 8), 3);
    }
    
    update(time, delta) {
        if (this.gameOver) return;
        
        // Update car
        this.car.update(delta);
        
        // Check collisions with markers
        this.checkDestinations();
        
        // Update panic
        this.updatePanic(delta);
        
        // Update passenger visual
        if (this.hasPassenger) {
            const pos = this.car.getPosition();
            this.passenger.setPosition(pos.x, pos.y - 35);
            this.passenger.setState(this.passengerState);
            this.passenger.update(delta, this.panicLevel);
        }
        
        // Update direction arrow
        this.updateDirectionArrow();
        
        // Update UI
        this.updateUI();
        
        // Drift effects
        if (this.car.isDrifting) {
            if (Math.random() < 0.5) {
                this.spawnDriftSmoke();
            }
            if (Math.random() < 0.3) {
                this.drawTireMark();
            }
        }
        
        // Screen shake on high panic
        this.effects.updatePanicShake(this.panicLevel);
    }
    
    updateDirectionArrow() {
        if (!this.currentTarget || !this.directionArrow.visible) return;
        
        const pos = this.car.getPosition();
        const angle = Phaser.Math.Angle.Between(
            pos.x, pos.y,
            this.currentTarget.x, this.currentTarget.y
        );
        
        // Position arrow near car
        const dist = 50;
        this.directionArrow.x = pos.x + Math.cos(angle) * dist;
        this.directionArrow.y = pos.y + Math.sin(angle) * dist;
        this.directionArrow.rotation = angle;
        
        // Color based on distance
        const targetDist = Phaser.Math.Distance.Between(
            pos.x, pos.y,
            this.currentTarget.x, this.currentTarget.y
        );
        if (targetDist < 100) {
            this.directionArrow.setAlpha(0.3);
        } else {
            this.directionArrow.setAlpha(0.7);
        }
    }
    
    checkDestinations() {
        const carPos = this.car.getPosition();
        const checkRadius = 45;
        
        // Check pickup
        if (!this.hasPassenger && this.pickupMarker.visible) {
            const dist = Phaser.Math.Distance.Between(
                carPos.x, carPos.y,
                this.pickupMarker.x, this.pickupMarker.y
            );
            
            if (dist < checkRadius && this.car.getSpeed() < 50) {
                this.pickupPassenger();
            }
        }
        
        // Check dropoff
        if (this.hasPassenger && this.dropoffMarker.visible) {
            const dist = Phaser.Math.Distance.Between(
                carPos.x, carPos.y,
                this.dropoffMarker.x, this.dropoffMarker.y
            );
            
            if (dist < checkRadius && this.car.getSpeed() < 50) {
                this.dropoffPassenger();
            }
        }
    }
    
    pickupPassenger() {
        this.hasPassenger = true;
        this.panicLevel = 10; // Start slightly nervous
        this.passenger.setVisible(true);
        this.activateDropoff();
        
        // Pickup sound feedback (visual)
        this.effects.flash(COLORS.CALM, 0.2);
        
        // Brief message
        this.showFloatingText(this.car.getPosition().x, this.car.getPosition().y - 60, '✓ Picked up!', COLORS.CALM);
    }
    
    dropoffPassenger() {
        this.hasPassenger = false;
        this.deliveries++;
        
        // Score based on remaining calm
        const calmBonus = Math.max(0, Math.round((100 - this.panicLevel) * 1.5));
        const deliveryScore = 100 + calmBonus;
        this.score += deliveryScore;
        
        // Add time bonus
        const timeBonus = 12;
        this.timeLeft = Math.min(this.timeLeft + timeBonus, GAME_CONFIG.DELIVERY_TIME + 10);
        this.timeText.setColor('#' + COLORS.TEXT.toString(16).padStart(6, '0'));
        
        this.passenger.setVisible(false);
        this.deliveryText.setText(`🚕 Deliveries: ${this.deliveries}`);
        
        // Show score popup
        const pos = this.car.getPosition();
        this.showFloatingText(pos.x, pos.y - 50, `+${deliveryScore}`, COLORS.UI_ACCENT);
        this.showFloatingText(pos.x + 40, pos.y - 30, `+${timeBonus}s`, COLORS.CALM);
        
        // Flash and next pickup
        this.effects.flash(COLORS.UI_ACCENT, 0.25);
        this.activatePickup();
        this.panicLevel = 0;
    }
    
    showFloatingText(x, y, text, color) {
        const popup = this.add.text(x, y, text, {
            fontFamily: 'Arial Black, Arial',
            fontSize: '22px',
            color: '#' + color.toString(16).padStart(6, '0'),
            stroke: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
            strokeThickness: 4,
        }).setOrigin(0.5).setDepth(300);
        
        this.tweens.add({
            targets: popup,
            y: popup.y - 40,
            alpha: 0,
            duration: 1000,
            onComplete: () => popup.destroy()
        });
    }
    
    updatePanic(delta) {
        if (!this.hasPassenger) {
            this.panicLevel = 0;
            return;
        }
        
        const dt = delta / 1000;
        
        if (this.car.isDrifting) {
            // Drifting increases panic based on intensity
            const panicIncrease = GAME_CONFIG.PANIC_DRIFT_RATE * (0.5 + this.car.driftIntensity) * dt;
            this.panicLevel += panicIncrease;
        } else if (this.car.getSpeedPercent() > 0.85) {
            // Very high speed - mild panic
            const panicIncrease = GAME_CONFIG.PANIC_SPEED_RATE * dt;
            this.panicLevel += panicIncrease;
        } else {
            // Calm driving - reduce panic
            this.panicLevel -= GAME_CONFIG.PANIC_CALM_RATE * dt;
        }
        
        // Clamp panic
        this.panicLevel = Phaser.Math.Clamp(this.panicLevel, 0, GAME_CONFIG.PANIC_MAX);
        
        // Update passenger state
        if (this.panicLevel >= 100) {
            this.passengerState = PASSENGER_STATES.BAILING;
            this.endGame('passenger_bailed');
        } else if (this.panicLevel >= 70) {
            this.passengerState = PASSENGER_STATES.PANIC;
        } else if (this.panicLevel >= 40) {
            this.passengerState = PASSENGER_STATES.WORRIED;
        } else {
            this.passengerState = PASSENGER_STATES.CALM;
        }
    }
    
    updateUI() {
        // Update panic meter
        this.panicFill.clear();
        
        let fillColor = COLORS.CALM;
        let emoji = '😊';
        let stateText = 'CALM';
        
        if (this.passengerState === PASSENGER_STATES.WORRIED) {
            fillColor = COLORS.WORRIED;
            emoji = '😰';
            stateText = 'WORRIED';
        }
        if (this.passengerState === PASSENGER_STATES.PANIC) {
            fillColor = COLORS.PANIC;
            emoji = '😱';
            stateText = 'PANICKING';
        }
        if (this.passengerState === PASSENGER_STATES.BAILING) {
            fillColor = COLORS.DANGER;
            emoji = '🏃';
            stateText = 'BAILING!';
        }
        
        if (this.hasPassenger) {
            this.panicFill.fillStyle(fillColor);
            const fillWidth = (this.panicLevel / GAME_CONFIG.PANIC_MAX) * 176;
            this.panicFill.fillRoundedRect(17, 17, fillWidth, 18, 5);
            this.panicLabel.setText(`${emoji} ${stateText}`);
        } else {
            this.panicLabel.setText('🚕 No passenger');
        }
        
        // Update score
        this.scoreText.setText(`SCORE: ${this.score}`);
        
        // Update speed
        const speedKmh = Math.round(this.car.getSpeed() * 0.5);
        this.speedText.setText(`${speedKmh}`);
        
        // Update drift indicator
        if (this.car.isDrifting) {
            this.driftText.setText('🔥 DRIFTING!');
            this.driftText.setScale(1 + this.car.driftIntensity * 0.15);
        } else {
            this.driftText.setText('');
            this.driftText.setScale(1);
        }
    }
    
    endGame(reason) {
        this.gameOver = true;
        this.timerEvent.destroy();
        this.directionArrow.setVisible(false);
        
        // Visual feedback based on reason
        if (reason === 'passenger_bailed') {
            this.effects.shake(10, 500);
            this.effects.flash(COLORS.DANGER, 0.4, 300);
        }
        
        // Small delay before transitioning
        this.time.delayedCall(800, () => {
            this.scene.start('GameOverScene', {
                score: this.score,
                deliveries: this.deliveries,
                reason: reason
            });
        });
    }
}
