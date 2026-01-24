/**
 * Car entity with drift physics
 */
import { COLORS, GAME_CONFIG } from '../config/constants.js';

export class Car {
    constructor(scene, x, y) {
        this.scene = scene;
        
        // Create car graphics
        this.graphics = scene.add.graphics();
        this.drawCar();
        
        // Create container for car
        this.container = scene.add.container(x, y, [this.graphics]);
        
        // Physics properties
        this.velocity = { x: 0, y: 0 };
        this.speed = 0;
        this.angle = -90; // Start facing up (in degrees)
        this.angularVelocity = 0;
        
        // Drift detection
        this.isDrifting = false;
        this.driftIntensity = 0;
        
        // Input
        this.cursors = scene.input.keyboard.createCursorKeys();
        this.wasd = scene.input.keyboard.addKeys({
            up: Phaser.Input.Keyboard.KeyCodes.W,
            down: Phaser.Input.Keyboard.KeyCodes.S,
            left: Phaser.Input.Keyboard.KeyCodes.A,
            right: Phaser.Input.Keyboard.KeyCodes.D,
        });
    }
    
    drawCar() {
        const g = this.graphics;
        g.clear();
        
        // Car body (taxi yellow-orange)
        g.fillStyle(COLORS.CAR_BODY);
        g.fillRoundedRect(-20, -12, 40, 24, 4);
        
        // Car roof/cabin
        g.fillStyle(COLORS.CAR_ACCENT);
        g.fillRoundedRect(-10, -8, 20, 16, 2);
        
        // Windshield (front)
        g.fillStyle(COLORS.CALM);
        g.fillRect(12, -6, 6, 12);
        
        // Rear window
        g.fillStyle(COLORS.CALM);
        g.fillRect(-18, -5, 4, 10);
        
        // Wheels
        g.fillStyle(COLORS.DARK);
        g.fillRect(-16, -14, 8, 4);  // Front left
        g.fillRect(-16, 10, 8, 4);   // Rear left
        g.fillRect(8, -14, 8, 4);    // Front right
        g.fillRect(8, 10, 8, 4);     // Rear right
        
        // Taxi light on top
        g.fillStyle(COLORS.UI_ACCENT);
        g.fillRect(-4, -4, 8, 8);
    }
    
    update(delta) {
        const dt = delta / 1000;
        
        // Get input
        const accel = this.cursors.up.isDown || this.wasd.up.isDown;
        const brake = this.cursors.down.isDown || this.wasd.down.isDown;
        const left = this.cursors.left.isDown || this.wasd.left.isDown;
        const right = this.cursors.right.isDown || this.wasd.right.isDown;
        
        // Acceleration/braking
        if (accel) {
            this.speed += GAME_CONFIG.CAR_ACCELERATION * dt;
        } else if (brake) {
            this.speed -= GAME_CONFIG.CAR_BRAKE_FORCE * dt;
        } else {
            // Natural deceleration
            this.speed *= 0.98;
        }
        
        // Clamp speed
        this.speed = Phaser.Math.Clamp(this.speed, -GAME_CONFIG.CAR_MAX_SPEED * 0.3, GAME_CONFIG.CAR_MAX_SPEED);
        
        // Turning (only when moving)
        const turnAmount = Math.abs(this.speed) > 10 ? GAME_CONFIG.CAR_TURN_SPEED : 0;
        if (left) {
            this.angularVelocity = -turnAmount * Math.sign(this.speed);
        } else if (right) {
            this.angularVelocity = turnAmount * Math.sign(this.speed);
        } else {
            this.angularVelocity *= 0.9;
        }
        
        // Apply angular velocity
        this.angle += this.angularVelocity;
        
        // Calculate target velocity based on current angle
        const radians = Phaser.Math.DegToRad(this.angle);
        const targetVelX = Math.cos(radians) * this.speed;
        const targetVelY = Math.sin(radians) * this.speed;
        
        // Drift physics: interpolate between current and target velocity
        // When turning fast at high speed, use lower grip (more drift)
        const isTurning = Math.abs(this.angularVelocity) > 0.5;
        const highSpeed = Math.abs(this.speed) > GAME_CONFIG.CAR_MAX_SPEED * 0.5;
        
        const gripFactor = (isTurning && highSpeed) 
            ? GAME_CONFIG.CAR_DRIFT_FACTOR 
            : GAME_CONFIG.CAR_GRIP_FACTOR;
        
        this.velocity.x = Phaser.Math.Linear(this.velocity.x, targetVelX, 1 - gripFactor);
        this.velocity.y = Phaser.Math.Linear(this.velocity.y, targetVelY, 1 - gripFactor);
        
        // Calculate drift intensity (difference between facing direction and movement direction)
        if (Math.abs(this.speed) > 20) {
            const movementAngle = Math.atan2(this.velocity.y, this.velocity.x);
            const facingAngle = radians;
            let angleDiff = Math.abs(movementAngle - facingAngle);
            if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;
            this.driftIntensity = angleDiff / Math.PI; // 0 to 1
            this.isDrifting = this.driftIntensity > 0.1 && highSpeed;
        } else {
            this.driftIntensity = 0;
            this.isDrifting = false;
        }
        
        // Apply velocity to position
        this.container.x += this.velocity.x * dt;
        this.container.y += this.velocity.y * dt;
        
        // Update rotation
        this.container.angle = this.angle;
        
        // Keep car on screen (wrap around for now)
        const margin = 50;
        if (this.container.x < -margin) this.container.x = GAME_CONFIG.WIDTH + margin;
        if (this.container.x > GAME_CONFIG.WIDTH + margin) this.container.x = -margin;
        if (this.container.y < -margin) this.container.y = GAME_CONFIG.HEIGHT + margin;
        if (this.container.y > GAME_CONFIG.HEIGHT + margin) this.container.y = -margin;
    }
    
    getPosition() {
        return { x: this.container.x, y: this.container.y };
    }
    
    getSpeed() {
        return Math.abs(this.speed);
    }
    
    getSpeedPercent() {
        return this.getSpeed() / GAME_CONFIG.CAR_MAX_SPEED;
    }
}
