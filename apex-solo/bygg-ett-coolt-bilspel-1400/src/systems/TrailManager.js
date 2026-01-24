/**
 * NEON TRAIL - Trail Manager
 * The core mechanic - manages the deadly neon trail behind the player
 */

class TrailManager {
    constructor(scene) {
        this.scene = scene;
        
        // Trail segments
        this.segments = [];
        this.maxSegments = 500;
        
        // Graphics for drawing
        this.graphics = null;
        this.glowGraphics = null;
        
        // Trail settings
        this.width = PLAYER_CONFIG.TRAIL_WIDTH;
        this.fadeTime = PLAYER_CONFIG.TRAIL_FADE_TIME;
        this.spawnRate = PLAYER_CONFIG.TRAIL_SPAWN_RATE;
        this.lastSpawnTime = 0;
        
        // Colors
        this.color = GAME_CONFIG.COLORS.TRAIL_PLAYER;
        this.glowColor = GAME_CONFIG.COLORS.CYAN;
        
        // State
        this.isActive = true;
        this.isGhostMode = false;
        this.trailWidthMultiplier = 1;
        
        // Performance
        this.updateFrequency = 2; // Update every N frames
        this.frameCount = 0;
    }
    
    /**
     * Initialize graphics objects
     */
    create() {
        // Glow layer (drawn first, underneath)
        this.glowGraphics = this.scene.add.graphics();
        this.glowGraphics.setDepth(5);
        
        // Main trail layer
        this.graphics = this.scene.add.graphics();
        this.graphics.setDepth(10);
        
        return this;
    }
    
    /**
     * Reset trail for new game
     */
    reset() {
        this.segments = [];
        this.lastSpawnTime = 0;
        this.isActive = true;
        this.isGhostMode = false;
        this.trailWidthMultiplier = 1;
        this.frameCount = 0;
        
        if (this.graphics) {
            this.graphics.clear();
        }
        if (this.glowGraphics) {
            this.glowGraphics.clear();
        }
    }
    
    /**
     * Add a new trail segment at position
     */
    addSegment(x, y, angle) {
        if (!this.isActive) return;
        
        const now = this.scene.time.now;
        
        // Check spawn rate
        if (now - this.lastSpawnTime < this.spawnRate) {
            return;
        }
        
        this.lastSpawnTime = now;
        
        // Calculate trail width based on current settings
        const width = this.width * this.trailWidthMultiplier;
        
        // Create segment
        const segment = {
            x: x,
            y: y,
            angle: angle,
            width: width,
            createdAt: now,
            alpha: 1,
            isGhost: this.isGhostMode,
        };
        
        this.segments.push(segment);
        
        // Remove old segments if over limit
        while (this.segments.length > this.maxSegments) {
            this.segments.shift();
        }
    }
    
    /**
     * Update trail (fade out old segments)
     */
    update(time, delta) {
        this.frameCount++;
        
        // Only update visuals every N frames for performance
        if (this.frameCount % this.updateFrequency !== 0) {
            return;
        }
        
        const now = time;
        
        // Update segment alphas and remove faded ones
        this.segments = this.segments.filter(segment => {
            const age = now - segment.createdAt;
            const fadeProgress = age / this.fadeTime;
            
            if (fadeProgress >= 1) {
                return false; // Remove fully faded
            }
            
            // Ease out fade
            segment.alpha = 1 - this.easeOutQuad(fadeProgress);
            return true;
        });
        
        // Redraw trail
        this.draw();
    }
    
    /**
     * Draw the trail
     */
    draw() {
        if (!this.graphics || !this.glowGraphics) return;
        
        this.graphics.clear();
        this.glowGraphics.clear();
        
        if (this.segments.length < 2) return;
        
        // Draw glow first (wider, more transparent)
        this.drawTrailLayer(this.glowGraphics, 2.5, 0.3, true);
        
        // Draw main trail
        this.drawTrailLayer(this.graphics, 1, 1, false);
    }
    
    /**
     * Draw a single layer of the trail
     */
    drawTrailLayer(graphics, widthMultiplier, alphaMultiplier, isGlow) {
        for (let i = 1; i < this.segments.length; i++) {
            const prev = this.segments[i - 1];
            const curr = this.segments[i];
            
            // Skip ghost segments for collision but still draw them differently
            const alpha = curr.alpha * alphaMultiplier;
            if (alpha <= 0.01) continue;
            
            // Calculate width
            const width = curr.width * widthMultiplier;
            
            // Color based on ghost mode
            let color = curr.isGhost ? GAME_CONFIG.COLORS.MAGENTA : this.color;
            if (isGlow) {
                color = curr.isGhost ? 0xff66ff : this.glowColor;
            }
            
            // Set line style
            graphics.lineStyle(width, color, alpha * (curr.isGhost ? 0.5 : 1));
            
            // Draw line segment
            graphics.beginPath();
            graphics.moveTo(prev.x, prev.y);
            graphics.lineTo(curr.x, curr.y);
            graphics.strokePath();
            
            // Add node points for smoother look
            if (!isGlow && i % 3 === 0) {
                graphics.fillStyle(color, alpha);
                graphics.fillCircle(curr.x, curr.y, width / 2);
            }
        }
    }
    
    /**
     * Check collision with trail
     * Returns true if position collides with non-ghost trail
     */
    checkCollision(x, y, radius) {
        if (this.isGhostMode) return false;
        
        const collisionRadius = radius + (this.width * this.trailWidthMultiplier) / 2;
        
        // Skip recent segments (grace period)
        const gracePeriod = 20; // Number of recent segments to skip
        const checkSegments = this.segments.slice(0, -gracePeriod);
        
        for (const segment of checkSegments) {
            // Skip ghost segments
            if (segment.isGhost) continue;
            
            // Skip nearly faded segments
            if (segment.alpha < 0.3) continue;
            
            // Distance check
            const dx = x - segment.x;
            const dy = y - segment.y;
            const distance = Math.sqrt(dx * dx + dy * dy);
            
            if (distance < collisionRadius) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Check near miss with trail
     * Returns true if position is close but not colliding
     */
    checkNearMiss(x, y, radius) {
        const nearMissRadius = radius + this.width * 2;
        const collisionRadius = radius + this.width / 2;
        
        // Skip recent segments
        const gracePeriod = 30;
        const checkSegments = this.segments.slice(0, -gracePeriod);
        
        for (const segment of checkSegments) {
            if (segment.isGhost) continue;
            if (segment.alpha < 0.3) continue;
            
            const dx = x - segment.x;
            const dy = y - segment.y;
            const distance = Math.sqrt(dx * dx + dy * dy);
            
            // Near miss: close but not colliding
            if (distance < nearMissRadius && distance > collisionRadius) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Set ghost mode (phase through trail)
     */
    setGhostMode(enabled) {
        this.isGhostMode = enabled;
    }
    
    /**
     * Set trail width multiplier
     */
    setWidthMultiplier(multiplier) {
        this.trailWidthMultiplier = multiplier;
    }
    
    /**
     * Set fade time multiplier
     */
    setFadeTimeMultiplier(multiplier) {
        this.fadeTime = PLAYER_CONFIG.TRAIL_FADE_TIME * multiplier;
    }
    
    /**
     * Pause trail generation
     */
    pause() {
        this.isActive = false;
    }
    
    /**
     * Resume trail generation
     */
    resume() {
        this.isActive = true;
    }
    
    /**
     * Easing function for smooth fade
     */
    easeOutQuad(t) {
        return t * (2 - t);
    }
    
    /**
     * Get trail stats
     */
    getStats() {
        return {
            segmentCount: this.segments.length,
            activeSegments: this.segments.filter(s => s.alpha > 0.3).length,
            ghostSegments: this.segments.filter(s => s.isGhost).length,
        };
    }
    
    /**
     * Cleanup
     */
    destroy() {
        this.segments = [];
        
        if (this.graphics) {
            this.graphics.destroy();
            this.graphics = null;
        }
        
        if (this.glowGraphics) {
            this.glowGraphics.destroy();
            this.glowGraphics = null;
        }
    }
}
