/**
 * GRAVSHIFT - Track Renderer
 * Pseudo-3D track rendering with rotation effects
 */

class TrackRenderer {
    constructor(scene, trackBuilder) {
        this.scene = scene;
        this.trackBuilder = trackBuilder;
        
        // Camera settings
        this.cameraX = 0;
        this.cameraY = 1000; // Height above road
        this.cameraZ = 0; // Position along track
        this.cameraDepth = 0.84; // Camera depth (affects FOV)
        
        // Render settings
        this.drawDistance = 100; // Number of segments to draw
        this.roadWidth = 2000; // Base road width for projection
        this.fogDensity = 5;
        
        // Screen dimensions
        this.screenWidth = GAME_CONFIG.WIDTH;
        this.screenHeight = GAME_CONFIG.HEIGHT;
        
        // Graphics objects
        this.roadGraphics = null;
        this.objectGraphics = null;
        this.backgroundGraphics = null;
        
        // Track rotation (for gravity effect)
        this.trackRotation = 0;
        this.targetTrackRotation = 0;
        
        // Colors from level theme
        this.theme = {
            skyColor: 0x0a0a1a,
            roadColor: 0x1a1a3a,
            roadLightColor: 0x2a2a5a,
            accentColor: 0x00ffff,
            edgeColor: 0xff00ff,
            fogColor: 0x0a0a1a,
        };
    }
    
    /**
     * Initialize graphics objects
     */
    init() {
        // Background layer
        this.backgroundGraphics = this.scene.add.graphics();
        this.backgroundGraphics.setDepth(0);
        
        // Road layer
        this.roadGraphics = this.scene.add.graphics();
        this.roadGraphics.setDepth(10);
        
        // Objects layer (obstacles, powerups, checkpoints)
        this.objectGraphics = this.scene.add.graphics();
        this.objectGraphics.setDepth(50);
    }
    
    /**
     * Set theme from level config
     */
    setTheme(themeConfig) {
        this.theme = {
            skyColor: themeConfig.skyColor || 0x0a0a1a,
            roadColor: themeConfig.roadColor || 0x1a1a3a,
            roadLightColor: ColorUtils.lighten(themeConfig.roadColor || 0x1a1a3a, 0.15),
            accentColor: themeConfig.accentColor || 0x00ffff,
            edgeColor: themeConfig.secondaryAccent || 0xff00ff,
            fogColor: themeConfig.skyColor || 0x0a0a1a,
        };
        this.fogDensity = (themeConfig.fogDensity || 0.003) * 1000;
    }
    
    /**
     * Update camera position
     */
    updateCamera(playerX, playerSpeed, deltaTime) {
        // Camera follows player's track position
        this.cameraZ += playerSpeed * deltaTime / 1000;
        
        // Camera X follows player with smoothing
        const targetX = playerX - this.screenWidth / 2;
        this.cameraX = MathUtils.lerp(this.cameraX, targetX * 0.5, 0.1);
        
        // Update track rotation smoothly
        this.trackRotation = MathUtils.lerp(this.trackRotation, this.targetTrackRotation, 0.05);
    }
    
    /**
     * Set track rotation (gravity direction)
     */
    setTrackRotation(degrees) {
        this.targetTrackRotation = degrees;
    }
    
    /**
     * Get current track position
     */
    getTrackPosition() {
        return this.cameraZ;
    }
    
    /**
     * Render the track
     */
    render() {
        console.log('TrackRenderer.render() called, segments:', this.trackBuilder.segments.length);

        // Clear all graphics
        this.backgroundGraphics.clear();
        this.roadGraphics.clear();
        this.objectGraphics.clear();
        
        // Draw background
        this.renderBackground();
        
        // Get visible segments
        const segments = this.trackBuilder.segments;
        const baseSegmentIndex = Math.floor(this.cameraZ / this.trackBuilder.segmentLength);
        
        // Find player segment for reference
        const playerSegment = segments[Math.min(baseSegmentIndex, segments.length - 1)];
        
        // Calculate player position on track
        let maxY = this.screenHeight;
        
        // Render segments from back to front
        for (let n = this.drawDistance - 1; n >= 0; n--) {
            const segmentIndex = (baseSegmentIndex + n) % segments.length;
            const segment = segments[segmentIndex];
            
            if (!segment) continue;
            
            // Project segment to screen
            this.projectSegment(segment, this.cameraZ);
            
            // Skip if behind camera
            if (segment.screen.y <= 0 || segment.screen.y >= maxY) continue;
            
            // Get previous segment for quad rendering
            const prevIndex = segmentIndex > 0 ? segmentIndex - 1 : segments.length - 1;
            const prevSegment = segments[prevIndex];
            this.projectSegment(prevSegment, this.cameraZ);
            
            // Render road segment
            this.renderRoadSegment(segment, prevSegment, segmentIndex);
            
            // Update clipping
            maxY = segment.screen.y;
            
            // Render objects on this segment
            this.renderSegmentObjects(segment);
        }
        
        // Apply track rotation to entire scene
        if (Math.abs(this.trackRotation) > 0.1) {
            this.applyTrackRotation();
        }
    }
    
    /**
     * Project segment to screen coordinates
     */
    projectSegment(segment, cameraZ) {
        const scale = this.cameraDepth / (segment.z - cameraZ);
        
        if (scale <= 0) {
            segment.screen = { x: 0, y: 0, w: 0, scale: 0 };
            return;
        }
        
        segment.screen = {
            scale: scale,
            x: Math.round(this.screenWidth / 2 + scale * (segment.curve * 1000 - this.cameraX) * this.screenWidth / 4),
            y: Math.round(this.screenHeight / 2 - scale * this.cameraY * this.screenHeight / 2 + this.screenHeight / 2),
            w: Math.round(scale * this.roadWidth * this.screenWidth / 2),
        };
    }
    
    /**
     * Render background (sky, stars, grid)
     */
    renderBackground() {
        const g = this.backgroundGraphics;
        
        // Sky gradient
        const gradientSteps = 10;
        for (let i = 0; i < gradientSteps; i++) {
            const y = (i / gradientSteps) * this.screenHeight;
            const height = this.screenHeight / gradientSteps;
            const color = ColorUtils.lerpColor(
                this.theme.skyColor,
                ColorUtils.darken(this.theme.skyColor, 0.5),
                i / gradientSteps
            );
            g.fillStyle(color, 1);
            g.fillRect(0, y, this.screenWidth, height + 1);
        }
        
        // Horizon line
        const horizonY = this.screenHeight / 2;
        g.lineStyle(2, this.theme.accentColor, 0.5);
        g.lineBetween(0, horizonY, this.screenWidth, horizonY);
        
        // Grid lines (perspective)
        g.lineStyle(1, this.theme.accentColor, 0.1);
        const gridLines = 20;
        for (let i = 0; i < gridLines; i++) {
            const y = horizonY + (i / gridLines) * (this.screenHeight - horizonY);
            g.lineBetween(0, y, this.screenWidth, y);
        }
        
        // Vertical grid lines
        for (let i = 0; i < gridLines; i++) {
            const x = (i / gridLines) * this.screenWidth;
            const startY = horizonY;
            const endY = this.screenHeight;
            
            // Converge to center at horizon
            const centerX = this.screenWidth / 2;
            const topX = centerX + (x - centerX) * 0.1;
            
            g.lineBetween(topX, startY, x, endY);
        }
    }
    
    /**
     * Render a road segment quad
     */
    renderRoadSegment(segment, prevSegment, index) {
        const g = this.roadGraphics;
        
        const s1 = segment.screen;
        const s2 = prevSegment.screen;
        
        if (s1.y >= s2.y) return; // Skip if wrong order
        
        // Determine colors based on segment index
        const isAlternate = Math.floor(index / 2) % 2 === 0;
        const roadColor = isAlternate ? this.theme.roadColor : this.theme.roadLightColor;
        
        // Calculate fog based on distance
        const fog = Math.min(1, (s1.y - this.screenHeight / 2) / (this.screenHeight * 0.6));
        const foggedColor = ColorUtils.lerpColor(roadColor, this.theme.fogColor, fog * 0.7);
        
        // Main road
        g.fillStyle(foggedColor, 1);
        g.beginPath();
        g.moveTo(s1.x - s1.w, s1.y);
        g.lineTo(s1.x + s1.w, s1.y);
        g.lineTo(s2.x + s2.w, s2.y);
        g.lineTo(s2.x - s2.w, s2.y);
        g.closePath();
        g.fillPath();
        
        // Rumble strips (edges)
        const rumbleWidth = s1.w * 0.05;
        const rumbleColor = isAlternate ? 0xff0000 : 0xffffff;
        
        // Left rumble
        g.fillStyle(ColorUtils.lerpColor(rumbleColor, this.theme.fogColor, fog * 0.5), 0.8);
        g.beginPath();
        g.moveTo(s1.x - s1.w - rumbleWidth, s1.y);
        g.lineTo(s1.x - s1.w, s1.y);
        g.lineTo(s2.x - s2.w, s2.y);
        g.lineTo(s2.x - s2.w - s2.w * 0.05, s2.y);
        g.closePath();
        g.fillPath();
        
        // Right rumble
        g.beginPath();
        g.moveTo(s1.x + s1.w, s1.y);
        g.lineTo(s1.x + s1.w + rumbleWidth, s1.y);
        g.lineTo(s2.x + s2.w + s2.w * 0.05, s2.y);
        g.lineTo(s2.x + s2.w, s2.y);
        g.closePath();
        g.fillPath();
        
        // Lane markers
        if (index % 4 < 2) {
            const laneColor = ColorUtils.lerpColor(this.theme.accentColor, this.theme.fogColor, fog * 0.7);
            g.fillStyle(laneColor, 0.5);
            
            // Left lane marker
            const laneWidth = s1.w * 0.01;
            const lane1X = s1.w / 3;
            
            g.beginPath();
            g.moveTo(s1.x - lane1X - laneWidth, s1.y);
            g.lineTo(s1.x - lane1X + laneWidth, s1.y);
            g.lineTo(s2.x - s2.w / 3 + s2.w * 0.01, s2.y);
            g.lineTo(s2.x - s2.w / 3 - s2.w * 0.01, s2.y);
            g.closePath();
            g.fillPath();
            
            // Right lane marker
            g.beginPath();
            g.moveTo(s1.x + lane1X - laneWidth, s1.y);
            g.lineTo(s1.x + lane1X + laneWidth, s1.y);
            g.lineTo(s2.x + s2.w / 3 + s2.w * 0.01, s2.y);
            g.lineTo(s2.x + s2.w / 3 - s2.w * 0.01, s2.y);
            g.closePath();
            g.fillPath();
        }
        
        // Edge glow
        const glowColor = ColorUtils.lerpColor(this.theme.edgeColor, this.theme.fogColor, fog * 0.8);
        g.lineStyle(2, glowColor, 0.8 - fog * 0.6);
        g.lineBetween(s1.x - s1.w - rumbleWidth, s1.y, s2.x - s2.w - s2.w * 0.05, s2.y);
        g.lineBetween(s1.x + s1.w + rumbleWidth, s1.y, s2.x + s2.w + s2.w * 0.05, s2.y);
    }
    
    /**
     * Render objects on a segment
     */
    renderSegmentObjects(segment) {
        const g = this.objectGraphics;
        const s = segment.screen;
        
        if (s.scale <= 0) return;
        
        // Render checkpoint
        if (segment.checkpoint && !segment.checkpoint.passed) {
            this.renderCheckpoint(segment.checkpoint, s);
        }
        
        // Render obstacles
        for (const obstacle of segment.obstacles) {
            if (obstacle.active) {
                this.renderObstacle(obstacle, s);
            }
        }
        
        // Render powerups
        for (const powerup of segment.powerups) {
            if (powerup.active && !powerup.collected) {
                this.renderPowerup(powerup, s);
            }
        }
    }
    
    /**
     * Render obstacle at segment position
     */
    renderObstacle(obstacle, screen) {
        const scale = screen.scale * 10;
        if (scale <= 0.05) return;
        
        // Calculate screen position
        const relativeX = (obstacle.x - this.screenWidth / 2) / (this.screenWidth / 2);
        const screenX = screen.x + relativeX * screen.w;
        const screenY = screen.y;
        
        // Update obstacle's render position
        obstacle.screenX = screenX;
        obstacle.screenY = screenY;
        obstacle.screenScale = scale;
        
        // Draw obstacle
        const width = obstacle.width * scale;
        const height = obstacle.height * scale;
        
        const g = this.objectGraphics;
        
        // Glow
        g.fillStyle(obstacle.color, 0.3);
        g.fillRect(screenX - width / 2 - 5, screenY - height - 5, width + 10, height + 10);
        
        // Main body
        g.fillStyle(obstacle.color, 0.9);
        g.fillRect(screenX - width / 2, screenY - height, width, height);
        
        // Highlight
        g.lineStyle(2, ColorUtils.lighten(obstacle.color, 0.5), 1);
        g.strokeRect(screenX - width / 2, screenY - height, width, height);
    }
    
    /**
     * Render powerup at segment position
     */
    renderPowerup(powerup, screen) {
        const scale = screen.scale * 10;
        if (scale <= 0.05) return;
        
        const relativeX = (powerup.x - this.screenWidth / 2) / (this.screenWidth / 2);
        const screenX = screen.x + relativeX * screen.w;
        const screenY = screen.y - 30 * scale;
        
        powerup.screenX = screenX;
        powerup.screenY = screenY;
        powerup.screenScale = scale;
        
        const radius = powerup.radius * scale;
        
        const g = this.objectGraphics;
        
        // Outer glow
        for (let i = 3; i > 0; i--) {
            g.fillStyle(powerup.color, 0.1 / i);
            g.fillCircle(screenX, screenY, radius + i * 10 * scale);
        }
        
        // Core
        g.fillStyle(powerup.color, 0.9);
        g.fillCircle(screenX, screenY, radius);
        
        // Highlight
        g.fillStyle(0xffffff, 0.5);
        g.fillCircle(screenX - radius * 0.3, screenY - radius * 0.3, radius * 0.3);
    }
    
    /**
     * Render checkpoint
     */
    renderCheckpoint(checkpoint, screen) {
        const scale = screen.scale * 10;
        if (scale <= 0.05) return;
        
        const screenY = screen.y;
        const width = screen.w * 2;
        const height = 20 * scale;
        
        const g = this.objectGraphics;
        
        // Glow
        g.fillStyle(GAME_CONFIG.COLORS.CHECKPOINT, 0.3);
        g.fillRect(screen.x - width / 2, screenY - height - 10 * scale, width, height + 20 * scale);
        
        // Checkered pattern
        const squareSize = width / 10;
        for (let i = 0; i < 10; i++) {
            const isLight = i % 2 === 0;
            g.fillStyle(isLight ? 0xffffff : GAME_CONFIG.COLORS.CHECKPOINT, 1);
            g.fillRect(screen.x - width / 2 + i * squareSize, screenY - height, squareSize, height);
        }
    }
    
    /**
     * Apply track rotation effect
     */
    applyTrackRotation() {
        // This would ideally use a render texture and rotation
        // For now, we'll handle rotation in the camera manager
        // The visual effect comes from the camera rotation
    }
    
    /**
     * Get road boundaries at current position
     */
    getRoadBoundaries() {
        const segment = this.trackBuilder.getSegmentAt(this.cameraZ);
        const trackWidth = this.trackBuilder.trackWidth;
        const centerX = this.screenWidth / 2 + segment.curve * 100;
        
        return {
            left: centerX - trackWidth / 2,
            right: centerX + trackWidth / 2,
            center: centerX,
            width: trackWidth,
        };
    }
    
    /**
     * Clean up
     */
    destroy() {
        if (this.backgroundGraphics) this.backgroundGraphics.destroy();
        if (this.roadGraphics) this.roadGraphics.destroy();
        if (this.objectGraphics) this.objectGraphics.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.TrackRenderer = TrackRenderer;
}
