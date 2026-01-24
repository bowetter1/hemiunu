/**
 * GRAVSHIFT - Track Builder
 * Procedural track generation with curves and rotations
 */

class TrackBuilder {
    constructor(scene, levelConfig) {
        this.scene = scene;
        this.levelConfig = levelConfig;
        this.segments = [];
        this.segmentLength = 200;
        this.trackWidth = levelConfig.track?.width || 400;
        this.totalLength = levelConfig.track?.length || 5000;
    }
    
    /**
     * Build track from level configuration
     */
    build() {
        this.segments = [];
        
        // Calculate number of segments
        const numSegments = Math.ceil(this.totalLength / this.segmentLength);
        
        // Get rotation events from level config
        const rotations = this.levelConfig.track?.rotations || [];
        
        // Generate segments
        for (let i = 0; i < numSegments; i++) {
            const z = i * this.segmentLength;
            
            // Determine curve and rotation at this position
            const { curve, rotation } = this.getTrackPropertiesAt(z, rotations);
            
            // Determine segment type
            const type = this.getSegmentType(i, numSegments);
            
            // Create segment
            const segment = new TrackSegment(i, {
                segmentLength: this.segmentLength,
                curve: curve,
                rotation: rotation,
                width: this.trackWidth,
                type: type,
                color: this.getSegmentColor(i),
                lightColor: this.getSegmentLightColor(i),
            });
            
            this.segments.push(segment);
        }
        
        // Add checkpoints
        this.addCheckpoints();
        
        // Add obstacles based on level config
        this.addObstacles();
        
        // Add powerups
        this.addPowerups();
        
        return this.segments;
    }
    
    /**
     * Get curve and rotation at specific position
     */
    getTrackPropertiesAt(z, rotations) {
        let curve = 0;
        let rotation = 0;
        
        // Apply rotations based on position
        for (const rot of rotations) {
            if (rot.continuous) {
                // Continuous rotation (spiral)
                rotation = (z / this.segmentLength) * (rot.rate || 1);
            } else if (z >= rot.position && z < rot.position + (rot.duration || 200)) {
                // Transition rotation
                const progress = (z - rot.position) / (rot.duration || 200);
                rotation = rot.angle * this.smoothStep(progress);
                
                // Add curve during rotation for visual interest
                curve = Math.sin(progress * Math.PI) * (rot.angle / 90) * 3;
            }
        }
        
        // Add procedural curves based on level's curve type
        const curveType = this.levelConfig.track?.curves || 'gentle';
        curve += this.getProceduralCurve(z, curveType);
        
        return { curve, rotation };
    }
    
    /**
     * Get procedural curve based on position and type
     */
    getProceduralCurve(z, type) {
        const frequency = 0.002; // Base frequency
        
        switch (type) {
            case 'gentle':
                return Math.sin(z * frequency) * 2;
            case 'moderate':
                return Math.sin(z * frequency) * 3 + Math.sin(z * frequency * 2) * 1.5;
            case 'aggressive':
                return Math.sin(z * frequency) * 4 + Math.sin(z * frequency * 3) * 2;
            case 'extreme':
                return Math.sin(z * frequency * 1.5) * 5 + Math.cos(z * frequency * 2) * 3;
            case 'chaotic':
                return Math.sin(z * frequency * 2) * 6 + 
                       Math.sin(z * frequency * 3.7) * 3 + 
                       Math.cos(z * frequency * 5) * 2;
            case 'nightmare':
                return Math.sin(z * frequency * 2.5) * 8 + 
                       Math.sin(z * frequency * 4) * 4 + 
                       Math.cos(z * frequency * 7) * 3;
            case 'procedural':
                // For endless mode - varies based on distance
                const difficulty = Math.min(z / 10000, 1);
                return Math.sin(z * frequency * (1 + difficulty)) * (3 + difficulty * 5);
            default:
                return 0;
        }
    }
    
    /**
     * Smooth step function for transitions
     */
    smoothStep(t) {
        return t * t * (3 - 2 * t);
    }
    
    /**
     * Get segment type based on position
     */
    getSegmentType(index, total) {
        // Start and finish
        if (index < 3) return 'start';
        if (index >= total - 3) return 'finish';
        
        // Normal segments
        return 'normal';
    }
    
    /**
     * Get segment color (alternating for visual reference)
     */
    getSegmentColor(index) {
        const theme = this.levelConfig.theme || {};
        const baseColor = theme.roadColor || GAME_CONFIG.COLORS.ROAD;
        
        // Alternate every few segments
        if (Math.floor(index / 3) % 2 === 0) {
            return baseColor;
        }
        return ColorUtils.lighten(baseColor, 0.1);
    }
    
    /**
     * Get segment light color
     */
    getSegmentLightColor(index) {
        const theme = this.levelConfig.theme || {};
        return theme.accentColor || GAME_CONFIG.COLORS.LANE_MARKER;
    }
    
    /**
     * Add checkpoints to track
     */
    addCheckpoints() {
        const rules = TRACK_RULES.checkpointFrequency;
        let lastCheckpoint = 0;
        
        for (let i = rules.minSegments; i < this.segments.length; i++) {
            if (i - lastCheckpoint >= rules.minSegments) {
                // Random chance to place checkpoint
                if (Math.random() < 0.3 || i - lastCheckpoint >= rules.maxSegments) {
                    const segment = this.segments[i];
                    const checkpoint = new Checkpoint(
                        this.scene,
                        GAME_CONFIG.WIDTH / 2,
                        0, // Y will be set during rendering
                        this.trackWidth
                    );
                    checkpoint.segmentIndex = i;
                    segment.setCheckpoint(checkpoint);
                    lastCheckpoint = i;
                }
            }
        }
    }
    
    /**
     * Add obstacles based on level configuration
     */
    addObstacles() {
        const spawns = this.levelConfig.spawns?.obstacles;
        if (!spawns) return;
        
        const types = spawns.types || ['BARRIER'];
        const frequency = spawns.frequency || 0.02;
        const maxActive = spawns.maxActive || 5;
        
        let obstacleCount = 0;
        let lastObstacleIndex = 0;
        
        for (let i = 10; i < this.segments.length - 5; i++) {
            // Check spawn rules
            if (i - lastObstacleIndex < TRACK_RULES.spawnRules.minDistanceBetweenObstacles) {
                continue;
            }
            
            // Random spawn
            if (Math.random() < frequency && obstacleCount < maxActive * 3) {
                const segment = this.segments[i];
                const type = types[Math.floor(Math.random() * types.length)];
                
                // Random lane position
                const lanePercent = 0.2 + Math.random() * 0.6; // 20% to 80% of track width
                const x = GAME_CONFIG.WIDTH / 2 - this.trackWidth / 2 + this.trackWidth * lanePercent;
                
                const obstacle = new Obstacle(this.scene, x, 0, type);
                obstacle.segmentIndex = i;
                segment.addObstacle(obstacle);
                
                obstacleCount++;
                lastObstacleIndex = i;
            }
        }
    }
    
    /**
     * Add powerups based on level configuration
     */
    addPowerups() {
        const spawns = this.levelConfig.spawns?.powerups;
        if (!spawns) return;
        
        const types = spawns.types || ['BOOST'];
        const frequency = spawns.frequency || 0.01;
        
        let lastPowerupIndex = 0;
        
        for (let i = 15; i < this.segments.length - 10; i++) {
            // Check spawn rules
            if (i - lastPowerupIndex < TRACK_RULES.spawnRules.minDistanceBetweenPowerups) {
                continue;
            }
            
            // Random spawn
            if (Math.random() < frequency) {
                const segment = this.segments[i];
                const type = types[Math.floor(Math.random() * types.length)];
                
                // Random lane position
                const lanePercent = 0.3 + Math.random() * 0.4; // 30% to 70% of track width
                const x = GAME_CONFIG.WIDTH / 2 - this.trackWidth / 2 + this.trackWidth * lanePercent;
                
                const powerup = new PowerUp(this.scene, x, 0, type);
                powerup.segmentIndex = i;
                segment.addPowerup(powerup);
                
                lastPowerupIndex = i;
            }
        }
    }
    
    /**
     * Get segment at world position
     */
    getSegmentAt(z) {
        const index = Math.floor(z / this.segmentLength);
        return this.segments[Math.min(index, this.segments.length - 1)];
    }
    
    /**
     * Get track length
     */
    getLength() {
        return this.segments.length * this.segmentLength;
    }
    
    /**
     * Get visible segments for rendering
     */
    getVisibleSegments(cameraZ, drawDistance) {
        const startIndex = Math.max(0, Math.floor(cameraZ / this.segmentLength));
        const endIndex = Math.min(this.segments.length - 1, startIndex + drawDistance);
        
        return this.segments.slice(startIndex, endIndex + 1);
    }
    
    /**
     * Generate endless track extension
     */
    extendTrack(numSegments) {
        const currentLength = this.segments.length;
        const difficulty = Math.min(currentLength / 100, 1);
        
        for (let i = 0; i < numSegments; i++) {
            const index = currentLength + i;
            const z = index * this.segmentLength;
            
            // Increasing difficulty for endless mode
            const curveIntensity = 3 + difficulty * 5;
            const rotationChance = 0.05 + difficulty * 0.1;
            
            let curve = Math.sin(z * 0.002) * curveIntensity;
            let rotation = 0;
            
            if (Math.random() < rotationChance) {
                rotation = (Math.random() - 0.5) * 90 * difficulty;
            }
            
            const segment = new TrackSegment(index, {
                segmentLength: this.segmentLength,
                curve: curve,
                rotation: rotation,
                width: this.trackWidth - difficulty * 50,
                type: 'normal',
                color: this.getSegmentColor(index),
                lightColor: this.getSegmentLightColor(index),
            });
            
            this.segments.push(segment);
            
            // Add obstacles with increasing frequency
            if (Math.random() < 0.02 + difficulty * 0.03) {
                const types = Object.keys(OBSTACLES);
                const type = types[Math.floor(Math.random() * Math.min(types.length, 2 + Math.floor(difficulty * 3)))];
                const x = GAME_CONFIG.WIDTH / 2 + (Math.random() - 0.5) * (this.trackWidth - 100);
                
                const obstacle = new Obstacle(this.scene, x, 0, type);
                obstacle.segmentIndex = index;
                segment.addObstacle(obstacle);
            }
            
            // Add powerups
            if (Math.random() < 0.01) {
                const types = Object.keys(POWERUPS);
                const type = types[Math.floor(Math.random() * types.length)];
                const x = GAME_CONFIG.WIDTH / 2 + (Math.random() - 0.5) * (this.trackWidth - 100);
                
                const powerup = new PowerUp(this.scene, x, 0, type);
                powerup.segmentIndex = index;
                segment.addPowerup(powerup);
            }
            
            // Add checkpoints periodically
            if (index % 20 === 0) {
                const checkpoint = new Checkpoint(this.scene, GAME_CONFIG.WIDTH / 2, 0, this.trackWidth);
                checkpoint.segmentIndex = index;
                segment.setCheckpoint(checkpoint);
            }
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.TrackBuilder = TrackBuilder;
}
