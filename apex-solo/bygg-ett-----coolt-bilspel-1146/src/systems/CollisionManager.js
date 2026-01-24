/**
 * GRAVSHIFT - Collision Manager
 * Handles all collision detection and response
 */

class CollisionManager {
    constructor(scene) {
        this.scene = scene;
        this.colliders = [];
        this.triggers = [];
        this.nearMissDistance = 30;
        this.lastNearMissTime = 0;
        this.nearMissCooldown = 500;
    }
    
    /**
     * Register a collider
     */
    addCollider(entity, type, callback) {
        this.colliders.push({
            entity,
            type,
            callback,
            active: true,
        });
    }
    
    /**
     * Register a trigger (non-physical collision)
     */
    addTrigger(entity, type, callback) {
        this.triggers.push({
            entity,
            type,
            callback,
            active: true,
        });
    }
    
    /**
     * Remove a collider/trigger by entity
     */
    remove(entity) {
        this.colliders = this.colliders.filter(c => c.entity !== entity);
        this.triggers = this.triggers.filter(t => t.entity !== entity);
    }
    
    /**
     * Check collision between player and obstacles
     */
    checkPlayerCollisions(player, obstacles, powerups, checkpoints) {
        const results = {
            hit: false,
            hitObstacle: null,
            collectedPowerups: [],
            passedCheckpoints: [],
            nearMisses: [],
        };
        
        if (!player || !player.active) return results;
        
        const playerBounds = this.getEntityBounds(player);
        
        // Check obstacles
        if (obstacles) {
            for (const obstacle of obstacles) {
                if (!obstacle.active) continue;
                
                const obstacleBounds = this.getEntityBounds(obstacle);
                
                // Check near miss first
                const distance = this.getDistance(playerBounds, obstacleBounds);
                
                if (distance < this.nearMissDistance && distance > 0) {
                    const now = Date.now();
                    if (now - this.lastNearMissTime > this.nearMissCooldown) {
                        results.nearMisses.push(obstacle);
                        this.lastNearMissTime = now;
                    }
                }
                
                // Check actual collision
                if (this.boundsOverlap(playerBounds, obstacleBounds)) {
                    // Check if player has shield/ghost powerup
                    if (!player.isInvincible && !player.isGhost) {
                        results.hit = true;
                        results.hitObstacle = obstacle;
                        break;
                    }
                }
            }
        }
        
        // Check powerups
        if (powerups) {
            for (const powerup of powerups) {
                if (!powerup.active || powerup.collected) continue;
                
                const powerupBounds = this.getEntityBounds(powerup);
                
                // Use larger collection radius
                const collectRadius = 40;
                if (this.circleOverlap(
                    playerBounds.centerX, playerBounds.centerY, collectRadius,
                    powerupBounds.centerX, powerupBounds.centerY, powerup.radius || 20
                )) {
                    results.collectedPowerups.push(powerup);
                    powerup.collected = true;
                }
            }
        }
        
        // Check checkpoints
        if (checkpoints) {
            for (const checkpoint of checkpoints) {
                if (!checkpoint.active || checkpoint.passed) continue;
                
                const checkpointBounds = this.getEntityBounds(checkpoint);
                
                if (this.boundsOverlap(playerBounds, checkpointBounds)) {
                    results.passedCheckpoints.push(checkpoint);
                    checkpoint.passed = true;
                }
            }
        }
        
        return results;
    }
    
    /**
     * Check if player is within track bounds
     */
    checkTrackBounds(player, track) {
        if (!player || !track) return { inBounds: true, edge: null };
        
        const playerX = player.x;
        const trackWidth = track.width || 400;
        const trackCenter = track.centerX || GAME_CONFIG.WIDTH / 2;
        
        const leftEdge = trackCenter - trackWidth / 2;
        const rightEdge = trackCenter + trackWidth / 2;
        
        const buffer = 20;
        
        if (playerX < leftEdge + buffer) {
            return { inBounds: false, edge: 'left', distance: leftEdge - playerX };
        }
        
        if (playerX > rightEdge - buffer) {
            return { inBounds: false, edge: 'right', distance: playerX - rightEdge };
        }
        
        return { inBounds: true, edge: null };
    }
    
    /**
     * Get entity bounds
     */
    getEntityBounds(entity) {
        const x = entity.x || 0;
        const y = entity.y || 0;
        const width = entity.width || entity.displayWidth || 50;
        const height = entity.height || entity.displayHeight || 50;
        
        return {
            x: x - width / 2,
            y: y - height / 2,
            width: width,
            height: height,
            centerX: x,
            centerY: y,
        };
    }
    
    /**
     * Check if two bounds overlap
     */
    boundsOverlap(a, b) {
        return a.x < b.x + b.width &&
               a.x + a.width > b.x &&
               a.y < b.y + b.height &&
               a.y + a.height > b.y;
    }
    
    /**
     * Check if two circles overlap
     */
    circleOverlap(x1, y1, r1, x2, y2, r2) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        const dist = Math.sqrt(dx * dx + dy * dy);
        return dist < r1 + r2;
    }
    
    /**
     * Get distance between two bounds (edge to edge)
     */
    getDistance(a, b) {
        const dx = Math.max(0, Math.max(a.x - (b.x + b.width), b.x - (a.x + a.width)));
        const dy = Math.max(0, Math.max(a.y - (b.y + b.height), b.y - (a.y + a.height)));
        return Math.sqrt(dx * dx + dy * dy);
    }
    
    /**
     * Raycast from point in direction
     */
    raycast(startX, startY, dirX, dirY, maxDistance, obstacles) {
        const result = {
            hit: false,
            point: null,
            distance: maxDistance,
            obstacle: null,
        };
        
        // Normalize direction
        const len = Math.sqrt(dirX * dirX + dirY * dirY);
        dirX /= len;
        dirY /= len;
        
        // Step along ray
        const stepSize = 10;
        let distance = 0;
        
        while (distance < maxDistance) {
            const x = startX + dirX * distance;
            const y = startY + dirY * distance;
            
            // Check each obstacle
            for (const obstacle of obstacles) {
                if (!obstacle.active) continue;
                
                const bounds = this.getEntityBounds(obstacle);
                
                if (x >= bounds.x && x <= bounds.x + bounds.width &&
                    y >= bounds.y && y <= bounds.y + bounds.height) {
                    result.hit = true;
                    result.point = { x, y };
                    result.distance = distance;
                    result.obstacle = obstacle;
                    return result;
                }
            }
            
            distance += stepSize;
        }
        
        return result;
    }
    
    /**
     * Check collision with rotated rectangle (for angled obstacles)
     */
    checkRotatedRectCollision(player, rect, rotation) {
        // Transform player position to rect's local space
        const cos = Math.cos(-rotation);
        const sin = Math.sin(-rotation);
        
        const localX = cos * (player.x - rect.x) - sin * (player.y - rect.y);
        const localY = sin * (player.x - rect.x) + cos * (player.y - rect.y);
        
        // Check collision in local space (axis-aligned)
        const halfW = rect.width / 2;
        const halfH = rect.height / 2;
        const playerRadius = player.radius || 25;
        
        // Closest point on rect to player center
        const closestX = MathUtils.clamp(localX, -halfW, halfW);
        const closestY = MathUtils.clamp(localY, -halfH, halfH);
        
        // Distance from player to closest point
        const dx = localX - closestX;
        const dy = localY - closestY;
        const distSq = dx * dx + dy * dy;
        
        return distSq < playerRadius * playerRadius;
    }
    
    /**
     * Get collision normal (direction of impact)
     */
    getCollisionNormal(playerBounds, obstacleBounds) {
        const dx = playerBounds.centerX - obstacleBounds.centerX;
        const dy = playerBounds.centerY - obstacleBounds.centerY;
        const len = Math.sqrt(dx * dx + dy * dy);
        
        return {
            x: len > 0 ? dx / len : 0,
            y: len > 0 ? dy / len : 1,
        };
    }
    
    /**
     * Clear all colliders
     */
    clear() {
        this.colliders = [];
        this.triggers = [];
    }
    
    /**
     * Debug render collision bounds
     */
    debugRender(graphics, entities) {
        graphics.lineStyle(1, 0xff0000, 0.5);
        
        for (const entity of entities) {
            if (!entity.active) continue;
            const bounds = this.getEntityBounds(entity);
            graphics.strokeRect(bounds.x, bounds.y, bounds.width, bounds.height);
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.CollisionManager = CollisionManager;
}
