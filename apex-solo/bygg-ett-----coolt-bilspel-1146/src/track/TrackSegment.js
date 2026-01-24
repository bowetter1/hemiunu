/**
 * GRAVSHIFT - Track Segment
 * Individual segment of the track
 */

class TrackSegment {
    constructor(index, config) {
        this.index = index;
        this.config = config;
        
        // Position
        this.z = index * (config.segmentLength || 200);
        this.worldY = 0;
        
        // Track properties
        this.curve = config.curve || 0;
        this.rotation = config.rotation || 0;
        this.width = config.width || 400;
        this.type = config.type || 'straight';
        
        // Visual properties
        this.color = config.color || GAME_CONFIG.COLORS.ROAD;
        this.lightColor = config.lightColor || GAME_CONFIG.COLORS.ROAD_LIGHT;
        
        // Rumble strips
        this.rumbleWidth = 30;
        this.hasRumble = true;
        
        // Lane markers
        this.hasLaneMarkers = config.type !== 'special';
        
        // Obstacles and powerups at this segment
        this.obstacles = [];
        this.powerups = [];
        this.checkpoint = null;
        
        // Screen projection (set during render)
        this.screen = {
            x: 0,
            y: 0,
            w: 0,
            scale: 0,
        };
        
        // Clipping
        this.clip = 0;
    }
    
    /**
     * Project segment to screen coordinates
     */
    project(cameraX, cameraY, cameraZ, cameraDepth, screenWidth, screenHeight, roadWidth) {
        const scale = cameraDepth / (this.z - cameraZ);
        
        this.screen = {
            scale: scale,
            x: Math.round(screenWidth / 2 + scale * (this.curve - cameraX) * screenWidth / 2),
            y: Math.round(screenHeight / 2 - scale * cameraY * screenHeight / 2),
            w: Math.round(scale * roadWidth * screenWidth / 2),
        };
        
        return this.screen;
    }
    
    /**
     * Check if segment is behind camera
     */
    isBehindCamera(cameraZ) {
        return this.z <= cameraZ;
    }
    
    /**
     * Check if segment is visible
     */
    isVisible(screenHeight) {
        return this.screen.y >= 0 && this.screen.y < screenHeight;
    }
    
    /**
     * Get the X position on the road at a given percentage (0 = left edge, 1 = right edge)
     */
    getXPosition(percent, screenWidth) {
        const roadLeft = this.screen.x - this.screen.w;
        const roadWidth = this.screen.w * 2;
        return roadLeft + roadWidth * percent;
    }
    
    /**
     * Add obstacle to segment
     */
    addObstacle(obstacle) {
        this.obstacles.push(obstacle);
    }
    
    /**
     * Add powerup to segment
     */
    addPowerup(powerup) {
        this.powerups.push(powerup);
    }
    
    /**
     * Set checkpoint
     */
    setCheckpoint(checkpoint) {
        this.checkpoint = checkpoint;
    }
    
    /**
     * Get rumble strip color
     */
    getRumbleColor(isAlternate) {
        if (isAlternate) {
            return { color: 0xff0000, alpha: 1 };
        }
        return { color: 0xffffff, alpha: 1 };
    }
    
    /**
     * Get lane marker color
     */
    getLaneMarkerColor() {
        return { color: GAME_CONFIG.COLORS.LANE_MARKER, alpha: 0.5 };
    }
}

// Export
if (typeof window !== 'undefined') {
    window.TrackSegment = TrackSegment;
}
