/**
 * GRAVSHIFT - Checkpoint Entity
 * Track checkpoints for progress and scoring
 */

class Checkpoint {
    constructor(scene, x, y, width = 400) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = 20;
        
        this.active = true;
        this.visible = true;
        this.passed = false;
        
        // Animation
        this.animTime = 0;
        this.flashAlpha = 0;
        
        // Visual style
        this.color = GAME_CONFIG.COLORS.CHECKPOINT;
        this.glowColor = 0xffff00;
        
        this.graphics = null;
    }
    
    /**
     * Update checkpoint
     */
    update(deltaTime) {
        this.animTime += deltaTime;
        
        // Fade out flash after being passed
        if (this.passed && this.flashAlpha > 0) {
            this.flashAlpha -= deltaTime / 500;
        }
    }
    
    /**
     * Create visuals
     */
    createVisuals(scene) {
        this.graphics = scene.add.graphics();
        this.graphics.setDepth(40);
    }
    
    /**
     * Render checkpoint
     */
    render(graphics = null) {
        const g = graphics || this.graphics;
        if (!g || !this.visible) return;
        
        if (!graphics) g.clear();
        
        const x = this.x;
        const y = this.y;
        const w = this.width;
        const h = this.height;
        
        // Base pulse animation
        const pulse = Math.sin(this.animTime / 200) * 0.3 + 0.7;
        
        if (!this.passed) {
            // Glow effect
            for (let i = 3; i > 0; i--) {
                g.fillStyle(this.glowColor, 0.1 * pulse / i);
                g.fillRect(x - w / 2 - i * 5, y - h / 2 - i * 5, w + i * 10, h + i * 10);
            }
            
            // Checkered pattern
            const squareSize = 20;
            const numSquares = Math.floor(w / squareSize);
            
            for (let i = 0; i < numSquares; i++) {
                const isLight = i % 2 === 0;
                g.fillStyle(isLight ? 0xffffff : this.color, pulse);
                g.fillRect(
                    x - w / 2 + i * squareSize,
                    y - h / 2,
                    squareSize,
                    h
                );
            }
            
            // Border
            g.lineStyle(3, this.color, 1);
            g.strokeRect(x - w / 2, y - h / 2, w, h);
            
            // Animated particles along the line
            const particleCount = 5;
            for (let i = 0; i < particleCount; i++) {
                const offset = ((this.animTime / 20 + i * (w / particleCount)) % w) - w / 2;
                g.fillStyle(0xffffff, 0.8);
                g.fillCircle(x + offset, y, 4);
            }
            
            // "CHECKPOINT" text indicator (small glow above)
            g.fillStyle(this.glowColor, pulse * 0.5);
            g.fillTriangle(
                x - 10, y - h / 2 - 5,
                x + 10, y - h / 2 - 5,
                x, y - h / 2 - 15
            );
        } else {
            // Passed state - faded
            g.fillStyle(0x444444, 0.3);
            g.fillRect(x - w / 2, y - h / 2, w, h);
            
            // Flash effect when just passed
            if (this.flashAlpha > 0) {
                g.fillStyle(0xffffff, this.flashAlpha);
                g.fillRect(x - w / 2, y - h / 2, w, h);
            }
        }
    }
    
    /**
     * Player passes through checkpoint
     */
    pass() {
        if (this.passed) return false;
        
        this.passed = true;
        this.flashAlpha = 1;
        
        // Emit event
        this.scene.events.emit('checkpointPassed', {
            x: this.x,
            y: this.y,
            width: this.width,
        });
        
        return true;
    }
    
    /**
     * Reset checkpoint
     */
    reset() {
        this.passed = false;
        this.flashAlpha = 0;
    }
    
    /**
     * Get bounds for collision
     */
    getBounds() {
        return {
            x: this.x - this.width / 2,
            y: this.y - this.height / 2,
            width: this.width,
            height: this.height,
            centerX: this.x,
            centerY: this.y,
        };
    }
    
    /**
     * Check if on screen
     */
    isOnScreen(cameraY, screenHeight) {
        return this.y > cameraY - this.height &&
               this.y < cameraY + screenHeight + this.height;
    }
    
    /**
     * Clean up
     */
    destroy() {
        if (this.graphics) {
            this.graphics.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Checkpoint = Checkpoint;
}
