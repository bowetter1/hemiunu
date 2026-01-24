/**
 * GRAVSHIFT - Mini Map Component
 * Shows track progress and obstacles ahead
 */

class MiniMap {
    constructor(scene, x, y, width = 150, height = 100) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        
        this.container = scene.add.container(x, y);
        this.container.setDepth(1000);
        
        this.create();
    }
    
    create() {
        // Background
        this.background = this.scene.add.graphics();
        this.background.fillStyle(0x000000, 0.7);
        this.background.fillRoundedRect(0, 0, this.width, this.height, 8);
        this.background.lineStyle(2, 0x00ffff, 0.5);
        this.background.strokeRoundedRect(0, 0, this.width, this.height, 8);
        this.container.add(this.background);
        
        // Track visualization
        this.trackGraphics = this.scene.add.graphics();
        this.container.add(this.trackGraphics);
        
        // Player indicator
        this.playerIndicator = this.scene.add.graphics();
        this.container.add(this.playerIndicator);
        
        // Obstacle indicators
        this.obstacleGraphics = this.scene.add.graphics();
        this.container.add(this.obstacleGraphics);
    }
    
    update(playerPosition, trackLength, obstacles = [], checkpoints = []) {
        this.trackGraphics.clear();
        this.playerIndicator.clear();
        this.obstacleGraphics.clear();
        
        const trackY = this.height - 20;
        const trackStartX = 10;
        const trackWidth = this.width - 20;
        
        // Draw track
        this.trackGraphics.fillStyle(0x333333, 1);
        this.trackGraphics.fillRect(trackStartX, trackY - 3, trackWidth, 6);
        
        // Draw progress
        const progress = Math.min(playerPosition / trackLength, 1);
        this.trackGraphics.fillStyle(0x00ffff, 0.8);
        this.trackGraphics.fillRect(trackStartX, trackY - 3, trackWidth * progress, 6);
        
        // Draw checkpoints
        this.trackGraphics.fillStyle(0xffff00, 1);
        for (const checkpoint of checkpoints) {
            const cpProgress = checkpoint.position / trackLength;
            const cpX = trackStartX + trackWidth * cpProgress;
            this.trackGraphics.fillRect(cpX - 1, trackY - 8, 2, 16);
        }
        
        // Draw player position
        const playerX = trackStartX + trackWidth * progress;
        this.playerIndicator.fillStyle(0x00ff00, 1);
        this.playerIndicator.fillTriangle(
            playerX, trackY - 10,
            playerX - 5, trackY - 18,
            playerX + 5, trackY - 18
        );
        
        // Draw obstacles ahead
        this.obstacleGraphics.fillStyle(0xff0000, 0.8);
        for (const obstacle of obstacles) {
            const obsProgress = obstacle.position / trackLength;
            if (obsProgress > progress && obsProgress < progress + 0.2) {
                const obsX = trackStartX + trackWidth * obsProgress;
                const obsY = this.height / 2 + (obstacle.lane - 1) * 10;
                this.obstacleGraphics.fillRect(obsX - 2, obsY - 2, 4, 4);
            }
        }
        
        // Draw distance text
        // (Text is expensive to update every frame, so we skip it here)
    }
    
    setVisible(visible) {
        this.container.setVisible(visible);
    }
    
    destroy() {
        this.container.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.MiniMap = MiniMap;
}
