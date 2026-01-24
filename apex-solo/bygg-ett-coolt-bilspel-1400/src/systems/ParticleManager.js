/**
 * NEON TRAIL - Particle Manager
 * Handles all particle effects for juice and polish
 */

class ParticleManager {
    constructor(scene) {
        this.scene = scene;
        
        // Particle emitters
        this.emitters = {};
        
        // Active effects
        this.activeEffects = [];
    }
    
    /**
     * Create all particle emitters
     */
    create() {
        // We'll create particles programmatically using graphics
        // since we're not loading external assets
        
        this.createParticleTextures();
        
        return this;
    }
    
    /**
     * Create procedural particle textures
     */
    createParticleTextures() {
        // Spark particle (small square)
        if (!this.scene.textures.exists('particle_spark')) {
            const sparkGraphics = this.scene.make.graphics({ x: 0, y: 0, add: false });
            sparkGraphics.fillStyle(0xffffff, 1);
            sparkGraphics.fillRect(0, 0, 8, 8);
            sparkGraphics.generateTexture('particle_spark', 8, 8);
            sparkGraphics.destroy();
        }
        
        // Glow particle (circle with gradient)
        if (!this.scene.textures.exists('particle_glow')) {
            const glowGraphics = this.scene.make.graphics({ x: 0, y: 0, add: false });
            glowGraphics.fillStyle(0xffffff, 1);
            glowGraphics.fillCircle(16, 16, 16);
            glowGraphics.generateTexture('particle_glow', 32, 32);
            glowGraphics.destroy();
        }
        
        // Trail particle (elongated)
        if (!this.scene.textures.exists('particle_trail')) {
            const trailGraphics = this.scene.make.graphics({ x: 0, y: 0, add: false });
            trailGraphics.fillStyle(0xffffff, 1);
            trailGraphics.fillRect(0, 0, 4, 16);
            trailGraphics.generateTexture('particle_trail', 4, 16);
            trailGraphics.destroy();
        }
    }
    
    /**
     * Emit sparks at position
     */
    emitSparks(x, y, color = GAME_CONFIG.COLORS.CYAN, count = 10) {
        for (let i = 0; i < count; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = 100 + Math.random() * 200;
            const vx = Math.cos(angle) * speed;
            const vy = Math.sin(angle) * speed;
            
            const spark = this.scene.add.image(x, y, 'particle_spark')
                .setTint(color)
                .setScale(0.5 + Math.random() * 0.5)
                .setAlpha(1)
                .setDepth(100);
            
            this.scene.tweens.add({
                targets: spark,
                x: x + vx * 0.5,
                y: y + vy * 0.5,
                alpha: 0,
                scale: 0,
                duration: 300 + Math.random() * 200,
                ease: 'Power2',
                onComplete: () => spark.destroy(),
            });
        }
    }
    
    /**
     * Emit explosion effect
     */
    emitExplosion(x, y, color = GAME_CONFIG.COLORS.MAGENTA) {
        // Central flash
        const flash = this.scene.add.circle(x, y, 10, color, 1)
            .setDepth(100);
        
        this.scene.tweens.add({
            targets: flash,
            scale: 5,
            alpha: 0,
            duration: 300,
            ease: 'Power2',
            onComplete: () => flash.destroy(),
        });
        
        // Ring
        const ring = this.scene.add.circle(x, y, 20, color, 0)
            .setStrokeStyle(4, color, 1)
            .setDepth(100);
        
        this.scene.tweens.add({
            targets: ring,
            scale: 4,
            alpha: 0,
            duration: 400,
            ease: 'Power2',
            onComplete: () => ring.destroy(),
        });
        
        // Sparks
        this.emitSparks(x, y, color, 20);
        
        // Secondary colored sparks
        this.emitSparks(x, y, GAME_CONFIG.COLORS.YELLOW, 10);
    }
    
    /**
     * Emit drift particles
     */
    emitDrift(x, y, angle, intensity = 1) {
        const count = Math.floor(2 * intensity);
        
        for (let i = 0; i < count; i++) {
            // Tire smoke
            const offsetX = (Math.random() - 0.5) * 20;
            const smoke = this.scene.add.circle(
                x + offsetX,
                y,
                5 + Math.random() * 5,
                GAME_CONFIG.COLORS.GRAY,
                0.5
            ).setDepth(4);
            
            this.scene.tweens.add({
                targets: smoke,
                y: y + 50 + Math.random() * 30,
                scale: 2,
                alpha: 0,
                duration: 500 + Math.random() * 300,
                ease: 'Power1',
                onComplete: () => smoke.destroy(),
            });
            
            // Cyan sparks from trail
            if (Math.random() > 0.5) {
                const spark = this.scene.add.image(
                    x + offsetX,
                    y,
                    'particle_spark'
                )
                    .setTint(GAME_CONFIG.COLORS.CYAN)
                    .setScale(0.3)
                    .setAlpha(0.8)
                    .setDepth(11);
                
                const sparkAngle = angle + Math.PI + (Math.random() - 0.5) * 0.5;
                const sparkSpeed = 50 + Math.random() * 100;
                
                this.scene.tweens.add({
                    targets: spark,
                    x: spark.x + Math.cos(sparkAngle) * sparkSpeed * 0.3,
                    y: spark.y + Math.sin(sparkAngle) * sparkSpeed * 0.3 + 30,
                    alpha: 0,
                    duration: 200 + Math.random() * 100,
                    onComplete: () => spark.destroy(),
                });
            }
        }
    }
    
    /**
     * Emit power-up collect effect
     */
    emitPowerUpCollect(x, y, color) {
        // Central burst
        const burst = this.scene.add.circle(x, y, 20, color, 0.8)
            .setDepth(100);
        
        this.scene.tweens.add({
            targets: burst,
            scale: 3,
            alpha: 0,
            duration: 400,
            ease: 'Power2',
            onComplete: () => burst.destroy(),
        });
        
        // Radial lines
        for (let i = 0; i < 8; i++) {
            const angle = (i / 8) * Math.PI * 2;
            const line = this.scene.add.rectangle(
                x, y,
                4, 30,
                color, 1
            )
                .setRotation(angle)
                .setDepth(100);
            
            this.scene.tweens.add({
                targets: line,
                scaleY: 3,
                alpha: 0,
                duration: 300,
                ease: 'Power2',
                onComplete: () => line.destroy(),
            });
        }
        
        // Sparks
        this.emitSparks(x, y, color, 15);
    }
    
    /**
     * Emit near miss effect
     */
    emitNearMiss(x, y) {
        // Quick flash
        const flash = this.scene.add.rectangle(
            x, y,
            30, 30,
            GAME_CONFIG.COLORS.MAGENTA,
            0.5
        ).setDepth(100);
        
        this.scene.tweens.add({
            targets: flash,
            scale: 2,
            alpha: 0,
            duration: 200,
            ease: 'Power2',
            onComplete: () => flash.destroy(),
        });
        
        // Small sparks
        this.emitSparks(x, y, GAME_CONFIG.COLORS.MAGENTA, 5);
    }
    
    /**
     * Emit boost trail effect
     */
    emitBoostTrail(x, y) {
        // Fire trail
        const flame = this.scene.add.circle(
            x + (Math.random() - 0.5) * 10,
            y,
            8 + Math.random() * 8,
            GAME_CONFIG.COLORS.ORANGE,
            0.8
        ).setDepth(4);
        
        this.scene.tweens.add({
            targets: flame,
            y: y + 40,
            scale: 0.5,
            alpha: 0,
            duration: 200,
            ease: 'Power1',
            onComplete: () => flame.destroy(),
        });
    }
    
    /**
     * Emit shield effect
     */
    emitShieldPulse(x, y, radius) {
        const ring = this.scene.add.circle(x, y, radius, GAME_CONFIG.COLORS.CYAN, 0)
            .setStrokeStyle(3, GAME_CONFIG.COLORS.CYAN, 0.5)
            .setDepth(50);
        
        this.scene.tweens.add({
            targets: ring,
            scale: 1.3,
            alpha: 0,
            duration: 500,
            ease: 'Power1',
            onComplete: () => ring.destroy(),
        });
    }
    
    /**
     * Screen shake effect
     */
    shake(intensity = 0.01, duration = 100) {
        if (this.scene.cameras && this.scene.cameras.main) {
            this.scene.cameras.main.shake(duration, intensity);
        }
    }
    
    /**
     * Flash screen
     */
    flash(color = 0xffffff, duration = 100, alpha = 0.3) {
        if (this.scene.cameras && this.scene.cameras.main) {
            const r = (color >> 16) & 0xff;
            const g = (color >> 8) & 0xff;
            const b = color & 0xff;
            this.scene.cameras.main.flash(duration, r, g, b, false, null, this, alpha);
        }
    }
    
    /**
     * Chromatic aberration effect (simplified)
     */
    chromaticPulse() {
        // This would require shaders for real implementation
        // For now, just do a quick color flash
        this.flash(GAME_CONFIG.COLORS.CYAN, 50, 0.1);
        this.scene.time.delayedCall(50, () => {
            this.flash(GAME_CONFIG.COLORS.MAGENTA, 50, 0.1);
        });
    }
    
    /**
     * Cleanup
     */
    destroy() {
        this.activeEffects.forEach(effect => {
            if (effect && effect.destroy) {
                effect.destroy();
            }
        });
        this.activeEffects = [];
        this.emitters = {};
    }
}
