/**
 * GRAVSHIFT - Particle Manager
 * GPU-accelerated particle effects for neon visuals
 */

class ParticleManager {
    constructor(scene) {
        this.scene = scene;
        this.emitters = {};
        this.particles = [];
        this.maxParticles = 1000;
    }
    
    /**
     * Create a particle emitter configuration
     */
    createEmitter(key, config) {
        const defaultConfig = {
            x: 0,
            y: 0,
            quantity: 10,
            frequency: 100,
            lifespan: 1000,
            speed: { min: 50, max: 200 },
            angle: { min: 0, max: 360 },
            scale: { start: 1, end: 0 },
            alpha: { start: 1, end: 0 },
            tint: 0xffffff,
            blendMode: 'ADD',
            gravityY: 0,
            ...config,
        };
        
        this.emitters[key] = defaultConfig;
        return defaultConfig;
    }
    
    /**
     * Emit particles at position
     */
    emit(key, x, y, count = null) {
        const config = this.emitters[key];
        if (!config) return;
        
        const numParticles = count || config.quantity;
        
        for (let i = 0; i < numParticles; i++) {
            if (this.particles.length >= this.maxParticles) {
                // Remove oldest particle
                this.particles.shift();
            }
            
            const angle = MathUtils.randomRange(
                config.angle.min || 0,
                config.angle.max || 360
            );
            const speed = MathUtils.randomRange(
                config.speed.min || 50,
                config.speed.max || 200
            );
            
            const rad = MathUtils.degToRad(angle);
            const vx = Math.cos(rad) * speed;
            const vy = Math.sin(rad) * speed;
            
            this.particles.push({
                x: x + MathUtils.randomRange(-5, 5),
                y: y + MathUtils.randomRange(-5, 5),
                vx: vx,
                vy: vy,
                life: config.lifespan,
                maxLife: config.lifespan,
                scaleStart: config.scale.start || 1,
                scaleEnd: config.scale.end || 0,
                alphaStart: config.alpha.start || 1,
                alphaEnd: config.alpha.end || 0,
                tint: config.tint,
                gravityY: config.gravityY || 0,
                size: config.size || 4,
                type: config.type || 'circle',
            });
        }
    }
    
    /**
     * Create trail effect
     */
    emitTrail(x, y, color, velocity = { x: 0, y: 0 }) {
        if (this.particles.length >= this.maxParticles) {
            this.particles.shift();
        }
        
        this.particles.push({
            x: x,
            y: y,
            vx: -velocity.x * 0.1 + MathUtils.randomRange(-10, 10),
            vy: -velocity.y * 0.1 + MathUtils.randomRange(-10, 10),
            life: 500,
            maxLife: 500,
            scaleStart: 1,
            scaleEnd: 0,
            alphaStart: 0.8,
            alphaEnd: 0,
            tint: color,
            gravityY: 0,
            size: 3,
            type: 'circle',
        });
    }
    
    /**
     * Create explosion effect
     */
    emitExplosion(x, y, color, count = 30) {
        for (let i = 0; i < count; i++) {
            const angle = (i / count) * Math.PI * 2;
            const speed = MathUtils.randomRange(100, 300);
            
            this.particles.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: MathUtils.randomRange(300, 600),
                maxLife: 600,
                scaleStart: MathUtils.randomRange(0.5, 1.5),
                scaleEnd: 0,
                alphaStart: 1,
                alphaEnd: 0,
                tint: color,
                gravityY: 100,
                size: MathUtils.randomRange(2, 6),
                type: 'circle',
            });
        }
    }
    
    /**
     * Create spark effect
     */
    emitSparks(x, y, color, direction = 0, count = 10) {
        for (let i = 0; i < count; i++) {
            const angle = direction + MathUtils.randomRange(-30, 30);
            const speed = MathUtils.randomRange(150, 400);
            const rad = MathUtils.degToRad(angle);
            
            this.particles.push({
                x: x,
                y: y,
                vx: Math.cos(rad) * speed,
                vy: Math.sin(rad) * speed,
                life: MathUtils.randomRange(200, 400),
                maxLife: 400,
                scaleStart: 0.5,
                scaleEnd: 0,
                alphaStart: 1,
                alphaEnd: 0,
                tint: color,
                gravityY: 200,
                size: 2,
                type: 'line',
                rotation: angle,
                length: MathUtils.randomRange(5, 15),
            });
        }
    }
    
    /**
     * Create boost/nitro flame effect
     */
    emitFlame(x, y, color, intensity = 1) {
        const count = Math.floor(3 * intensity);
        
        for (let i = 0; i < count; i++) {
            this.particles.push({
                x: x + MathUtils.randomRange(-5, 5),
                y: y,
                vx: MathUtils.randomRange(-30, 30),
                vy: MathUtils.randomRange(50, 150),
                life: MathUtils.randomRange(100, 300),
                maxLife: 300,
                scaleStart: MathUtils.randomRange(0.8, 1.2) * intensity,
                scaleEnd: 0,
                alphaStart: 0.9,
                alphaEnd: 0,
                tint: color,
                gravityY: -50,
                size: MathUtils.randomRange(4, 8),
                type: 'circle',
            });
        }
    }
    
    /**
     * Create score popup effect
     */
    emitScorePopup(x, y, score, color = 0xffffff) {
        this.particles.push({
            x: x,
            y: y,
            vx: 0,
            vy: -50,
            life: 1000,
            maxLife: 1000,
            scaleStart: 1,
            scaleEnd: 1.5,
            alphaStart: 1,
            alphaEnd: 0,
            tint: color,
            gravityY: 0,
            type: 'text',
            text: '+' + score,
        });
    }
    
    /**
     * Create checkpoint ring effect
     */
    emitCheckpointRing(x, y, color) {
        for (let i = 0; i < 36; i++) {
            const angle = (i / 36) * Math.PI * 2;
            const radius = 100;
            
            this.particles.push({
                x: x + Math.cos(angle) * radius,
                y: y + Math.sin(angle) * radius,
                vx: Math.cos(angle) * 50,
                vy: Math.sin(angle) * 50,
                life: 500,
                maxLife: 500,
                scaleStart: 1,
                scaleEnd: 0,
                alphaStart: 1,
                alphaEnd: 0,
                tint: color,
                gravityY: 0,
                size: 4,
                type: 'circle',
            });
        }
    }
    
    /**
     * Update all particles
     */
    update(deltaTime) {
        const dt = deltaTime / 1000;
        
        for (let i = this.particles.length - 1; i >= 0; i--) {
            const p = this.particles[i];
            
            // Update position
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            
            // Apply gravity
            p.vy += p.gravityY * dt;
            
            // Update life
            p.life -= deltaTime;
            
            // Remove dead particles
            if (p.life <= 0) {
                this.particles.splice(i, 1);
            }
        }
    }
    
    /**
     * Render all particles to graphics object
     */
    render(graphics) {
        graphics.clear();
        
        for (const p of this.particles) {
            const lifeRatio = p.life / p.maxLife;
            const scale = MathUtils.lerp(p.scaleEnd, p.scaleStart, lifeRatio);
            const alpha = MathUtils.lerp(p.alphaEnd, p.alphaStart, lifeRatio);
            
            if (p.type === 'text') {
                // Text particles handled separately
                continue;
            }
            
            graphics.fillStyle(p.tint, alpha);
            
            if (p.type === 'circle') {
                graphics.fillCircle(p.x, p.y, p.size * scale);
            } else if (p.type === 'line') {
                const rad = MathUtils.degToRad(p.rotation || 0);
                const length = (p.length || 10) * scale;
                graphics.lineStyle(2 * scale, p.tint, alpha);
                graphics.lineBetween(
                    p.x - Math.cos(rad) * length / 2,
                    p.y - Math.sin(rad) * length / 2,
                    p.x + Math.cos(rad) * length / 2,
                    p.y + Math.sin(rad) * length / 2
                );
            } else if (p.type === 'rect') {
                const size = p.size * scale;
                graphics.fillRect(p.x - size / 2, p.y - size / 2, size, size);
            }
        }
    }
    
    /**
     * Get text particles for separate rendering
     */
    getTextParticles() {
        return this.particles.filter(p => p.type === 'text');
    }
    
    /**
     * Clear all particles
     */
    clear() {
        this.particles = [];
    }
    
    /**
     * Get particle count
     */
    getCount() {
        return this.particles.length;
    }
}

// Export
if (typeof window !== 'undefined') {
    window.ParticleManager = ParticleManager;
}
