/**
 * GRAVSHIFT - Ghost Entity
 * Replay ghost from best run
 */

class Ghost {
    constructor(scene) {
        this.scene = scene;
        this.recordedData = [];
        this.playbackIndex = 0;
        this.isRecording = false;
        this.isPlaying = false;
        this.recordInterval = 50; // Record every 50ms
        this.lastRecordTime = 0;
        
        // Visual
        this.x = 0;
        this.y = 0;
        this.rotation = 0; // Stored in degrees
        this.visible = false;
        this.alpha = 0.3;
        this.color = 0x888888;
        
        this.graphics = null;
    }
    
    /**
     * Start recording ghost data
     */
    startRecording() {
        this.recordedData = [];
        this.isRecording = true;
        this.lastRecordTime = 0;
    }
    
    /**
     * Record a frame of ghost data
     */
    recordFrame(player, time) {
        if (!this.isRecording) return;
        
        if (time - this.lastRecordTime >= this.recordInterval) {
            this.recordedData.push({
                time: time,
                x: player.x,
                y: player.y,
                rotation: player.rotation, // Already in degrees
                speed: player.speed,
                isBoosting: player.isBoosting,
            });
            this.lastRecordTime = time;
        }
    }
    
    /**
     * Stop recording
     */
    stopRecording() {
        this.isRecording = false;
        return this.recordedData;
    }
    
    /**
     * Load ghost data for playback
     */
    loadGhostData(data) {
        this.recordedData = data;
        this.playbackIndex = 0;
    }
    
    /**
     * Start playback
     */
    startPlayback() {
        if (this.recordedData.length === 0) return false;
        
        this.isPlaying = true;
        this.playbackIndex = 0;
        this.visible = true;
        return true;
    }
    
    /**
     * Stop playback
     */
    stopPlayback() {
        this.isPlaying = false;
        this.visible = false;
    }
    
    /**
     * Update ghost position during playback
     */
    update(gameTime) {
        if (!this.isPlaying || this.recordedData.length === 0) return;
        
        // Find the appropriate frame
        while (this.playbackIndex < this.recordedData.length - 1 &&
               this.recordedData[this.playbackIndex + 1].time <= gameTime) {
            this.playbackIndex++;
        }
        
        // Interpolate between frames
        const current = this.recordedData[this.playbackIndex];
        const next = this.recordedData[Math.min(this.playbackIndex + 1, this.recordedData.length - 1)];
        
        if (current && next && next.time !== current.time) {
            const t = (gameTime - current.time) / (next.time - current.time);
            this.x = MathUtils.lerp(current.x, next.x, t);
            this.y = MathUtils.lerp(current.y, next.y, t);
            this.rotation = MathUtils.lerp(current.rotation, next.rotation, t);
        } else if (current) {
            this.x = current.x;
            this.y = current.y;
            this.rotation = current.rotation;
        }
        
        // Check if playback finished
        if (this.playbackIndex >= this.recordedData.length - 1) {
            this.stopPlayback();
        }
    }
    
    /**
     * Create graphics
     */
    createVisuals(scene) {
        this.graphics = scene.add.graphics();
        this.graphics.setDepth(90);
        this.graphics.setAlpha(this.alpha);
    }
    
    /**
     * Render ghost
     */
    render() {
        if (!this.graphics || !this.visible) return;
        
        this.graphics.clear();
        
        const x = this.x;
        const y = this.y;
        const w = 40;
        const h = 50;
        
        // Transform points using rotation in degrees
        // MathUtils.rotatePoint expects degrees
        const points = [
            { x: 0, y: -h / 2 },
            { x: -w / 2, y: h / 2 },
            { x: w / 2, y: h / 2 },
        ];
        
        const transformed = points.map(p => {
            const rotated = MathUtils.rotatePoint(p.x, p.y, this.rotation);
            return { x: x + rotated.x, y: y + rotated.y };
        });
        
        // Draw ghost outline
        this.graphics.lineStyle(2, this.color, this.alpha);
        this.graphics.strokeTriangle(
            transformed[0].x, transformed[0].y,
            transformed[1].x, transformed[1].y,
            transformed[2].x, transformed[2].y
        );
        
        // Fill with very low alpha
        this.graphics.fillStyle(this.color, this.alpha * 0.3);
        this.graphics.fillTriangle(
            transformed[0].x, transformed[0].y,
            transformed[1].x, transformed[1].y,
            transformed[2].x, transformed[2].y
        );
    }
    
    /**
     * Save ghost data to localStorage
     */
    saveToStorage(levelId) {
        if (this.recordedData.length === 0) return;
        
        try {
            const key = `${GAME_CONFIG.STORAGE.GHOST_DATA}_${levelId}`;
            localStorage.setItem(key, JSON.stringify(this.recordedData));
        } catch (e) {
            console.warn('Could not save ghost data');
        }
    }
    
    /**
     * Load ghost data from localStorage
     */
    loadFromStorage(levelId) {
        try {
            const key = `${GAME_CONFIG.STORAGE.GHOST_DATA}_${levelId}`;
            const data = localStorage.getItem(key);
            if (data) {
                this.recordedData = JSON.parse(data);
                return true;
            }
        } catch (e) {
            console.warn('Could not load ghost data');
        }
        return false;
    }
    
    /**
     * Destroy ghost
     */
    destroy() {
        if (this.graphics) {
            this.graphics.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Ghost = Ghost;
}
