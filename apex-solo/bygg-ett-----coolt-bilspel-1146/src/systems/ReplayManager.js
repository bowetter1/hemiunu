/**
 * GRAVSHIFT - Replay Manager
 * Records and plays back complete game sessions
 */

class ReplayManager {
    constructor(scene) {
        this.scene = scene;
        
        // Recording state
        this.isRecording = false;
        this.isPlaying = false;
        this.isPaused = false;
        
        // Replay data
        this.currentReplay = null;
        this.replayBuffer = [];
        this.savedReplays = [];
        
        // Timing
        this.recordInterval = 16; // ~60fps
        this.lastRecordTime = 0;
        this.playbackTime = 0;
        this.playbackSpeed = 1;
        this.frameIndex = 0;
        
        // Configuration
        this.maxFrames = 18000; // 5 minutes at 60fps
        this.maxSavedReplays = 10;
        
        // Metadata
        this.replayMetadata = null;
        
        // Load saved replays
        this.loadSavedReplays();
    }
    
    /**
     * Start recording a new replay
     */
    startRecording(metadata = {}) {
        this.isRecording = true;
        this.isPlaying = false;
        this.replayBuffer = [];
        this.lastRecordTime = 0;
        
        this.replayMetadata = {
            id: Date.now().toString(36) + Math.random().toString(36).substr(2),
            timestamp: Date.now(),
            levelId: metadata.levelId || 1,
            vehicleId: metadata.vehicleId || 'BALANCED',
            version: '1.0.0',
            ...metadata,
        };
        
        console.log('Started recording replay:', this.replayMetadata.id);
    }
    
    /**
     * Record a frame of game state
     */
    recordFrame(gameState, time) {
        if (!this.isRecording) return;
        
        // Check frame limit
        if (this.replayBuffer.length >= this.maxFrames) {
            console.warn('Replay buffer full, stopping recording');
            this.stopRecording();
            return;
        }
        
        // Rate limiting
        if (time - this.lastRecordTime < this.recordInterval) return;
        this.lastRecordTime = time;
        
        // Create frame data
        const frame = this.createFrame(gameState, time);
        this.replayBuffer.push(frame);
    }
    
    /**
     * Create a frame from game state
     */
    createFrame(state, time) {
        return {
            t: time,
            
            // Player state
            p: {
                x: Math.round(state.player.x * 10) / 10,
                y: Math.round(state.player.y * 10) / 10,
                r: Math.round(state.player.rotation * 10) / 10,
                s: Math.round(state.player.speed),
                b: state.player.isBoosting ? 1 : 0,
                i: state.player.isInvincible ? 1 : 0,
                g: state.player.isGhost ? 1 : 0,
                n: Math.round(state.player.nitro),
            },
            
            // Camera state
            c: {
                z: Math.round(state.cameraZ || 0),
                r: Math.round((state.cameraRotation || 0) * 10) / 10,
            },
            
            // Score state
            sc: {
                s: state.score || 0,
                m: Math.round((state.multiplier || 1) * 10) / 10,
                cb: state.combo || 0,
            },
            
            // Input state (for validation)
            i: {
                h: Math.round((state.input?.horizontal || 0) * 100) / 100,
                v: Math.round((state.input?.vertical || 0) * 100) / 100,
                bo: state.input?.boost ? 1 : 0,
                br: state.input?.brake ? 1 : 0,
            },
            
            // Events this frame
            e: state.events || [],
        };
    }
    
    /**
     * Stop recording and finalize replay
     */
    stopRecording(finalStats = {}) {
        if (!this.isRecording) return null;
        
        this.isRecording = false;
        
        if (this.replayBuffer.length === 0) {
            console.log('No frames recorded');
            return null;
        }
        
        // Create replay object
        this.currentReplay = {
            metadata: {
                ...this.replayMetadata,
                duration: this.replayBuffer[this.replayBuffer.length - 1].t,
                frameCount: this.replayBuffer.length,
                finalScore: finalStats.score || 0,
                finalDistance: finalStats.distance || 0,
                completed: finalStats.completed || false,
                stars: finalStats.stars || 0,
            },
            frames: this.replayBuffer,
        };
        
        console.log('Stopped recording:', this.currentReplay.metadata.frameCount, 'frames');
        
        return this.currentReplay;
    }
    
    /**
     * Save current replay to storage
     */
    saveReplay(name = '') {
        if (!this.currentReplay) return false;
        
        // Add name
        this.currentReplay.metadata.name = name || `Replay ${new Date().toLocaleString()}`;
        
        // Compress frames for storage
        const compressedReplay = this.compressReplay(this.currentReplay);
        
        // Add to saved replays
        this.savedReplays.unshift(compressedReplay);
        
        // Limit saved replays
        if (this.savedReplays.length > this.maxSavedReplays) {
            this.savedReplays.pop();
        }
        
        // Persist to storage
        this.persistReplays();
        
        console.log('Saved replay:', this.currentReplay.metadata.name);
        return true;
    }
    
    /**
     * Compress replay data for storage
     */
    compressReplay(replay) {
        // Simple compression: reduce precision and remove redundant data
        const compressed = {
            metadata: { ...replay.metadata },
            frames: replay.frames.map((frame, index) => {
                // For most frames, only store changed values
                if (index === 0) return frame;
                
                const prevFrame = replay.frames[index - 1];
                const delta = {};
                
                // Only include time delta
                delta.dt = frame.t - prevFrame.t;
                
                // Player deltas
                if (frame.p.x !== prevFrame.p.x) delta.px = frame.p.x;
                if (frame.p.y !== prevFrame.p.y) delta.py = frame.p.y;
                if (frame.p.r !== prevFrame.p.r) delta.pr = frame.p.r;
                if (frame.p.s !== prevFrame.p.s) delta.ps = frame.p.s;
                if (frame.p.b !== prevFrame.p.b) delta.pb = frame.p.b;
                if (frame.p.i !== prevFrame.p.i) delta.pi = frame.p.i;
                if (frame.p.g !== prevFrame.p.g) delta.pg = frame.p.g;
                if (frame.p.n !== prevFrame.p.n) delta.pn = frame.p.n;
                
                // Camera deltas
                if (frame.c.z !== prevFrame.c.z) delta.cz = frame.c.z;
                if (frame.c.r !== prevFrame.c.r) delta.cr = frame.c.r;
                
                // Score deltas
                if (frame.sc.s !== prevFrame.sc.s) delta.ss = frame.sc.s;
                if (frame.sc.m !== prevFrame.sc.m) delta.sm = frame.sc.m;
                if (frame.sc.cb !== prevFrame.sc.cb) delta.scb = frame.sc.cb;
                
                // Events
                if (frame.e && frame.e.length > 0) delta.e = frame.e;
                
                return delta;
            }),
        };
        
        return compressed;
    }
    
    /**
     * Decompress replay data
     */
    decompressReplay(compressed) {
        const frames = [];
        let currentState = null;
        
        for (const frame of compressed.frames) {
            if (frame.t !== undefined) {
                // First frame - full data
                currentState = { ...frame };
                frames.push({ ...frame });
            } else {
                // Delta frame
                const newFrame = {
                    t: currentState.t + (frame.dt || 0),
                    p: { ...currentState.p },
                    c: { ...currentState.c },
                    sc: { ...currentState.sc },
                    i: currentState.i,
                    e: frame.e || [],
                };
                
                // Apply deltas
                if (frame.px !== undefined) newFrame.p.x = frame.px;
                if (frame.py !== undefined) newFrame.p.y = frame.py;
                if (frame.pr !== undefined) newFrame.p.r = frame.pr;
                if (frame.ps !== undefined) newFrame.p.s = frame.ps;
                if (frame.pb !== undefined) newFrame.p.b = frame.pb;
                if (frame.pi !== undefined) newFrame.p.i = frame.pi;
                if (frame.pg !== undefined) newFrame.p.g = frame.pg;
                if (frame.pn !== undefined) newFrame.p.n = frame.pn;
                
                if (frame.cz !== undefined) newFrame.c.z = frame.cz;
                if (frame.cr !== undefined) newFrame.c.r = frame.cr;
                
                if (frame.ss !== undefined) newFrame.sc.s = frame.ss;
                if (frame.sm !== undefined) newFrame.sc.m = frame.sm;
                if (frame.scb !== undefined) newFrame.sc.cb = frame.scb;
                
                currentState = newFrame;
                frames.push(newFrame);
            }
        }
        
        return {
            metadata: compressed.metadata,
            frames,
        };
    }
    
    /**
     * Load a replay for playback
     */
    loadReplay(replayId) {
        const compressed = this.savedReplays.find(r => r.metadata.id === replayId);
        if (!compressed) {
            console.error('Replay not found:', replayId);
            return false;
        }
        
        this.currentReplay = this.decompressReplay(compressed);
        this.frameIndex = 0;
        this.playbackTime = 0;
        
        console.log('Loaded replay:', this.currentReplay.metadata.name);
        return true;
    }
    
    /**
     * Start playback
     */
    startPlayback(speed = 1) {
        if (!this.currentReplay) {
            console.error('No replay loaded');
            return false;
        }
        
        this.isPlaying = true;
        this.isPaused = false;
        this.playbackSpeed = speed;
        this.frameIndex = 0;
        this.playbackTime = 0;
        
        console.log('Started playback at', speed, 'x speed');
        return true;
    }
    
    /**
     * Pause playback
     */
    pausePlayback() {
        this.isPaused = true;
    }
    
    /**
     * Resume playback
     */
    resumePlayback() {
        this.isPaused = false;
    }
    
    /**
     * Stop playback
     */
    stopPlayback() {
        this.isPlaying = false;
        this.isPaused = false;
    }
    
    /**
     * Set playback speed
     */
    setPlaybackSpeed(speed) {
        this.playbackSpeed = MathUtils.clamp(speed, 0.25, 4);
    }
    
    /**
     * Seek to a specific time
     */
    seekTo(time) {
        if (!this.currentReplay) return;
        
        // Find the frame at this time
        let targetIndex = 0;
        for (let i = 0; i < this.currentReplay.frames.length; i++) {
            if (this.currentReplay.frames[i].t <= time) {
                targetIndex = i;
            } else {
                break;
            }
        }
        
        this.frameIndex = targetIndex;
        this.playbackTime = time;
    }
    
    /**
     * Seek by percentage (0-1)
     */
    seekToPercent(percent) {
        if (!this.currentReplay) return;
        
        const duration = this.currentReplay.metadata.duration;
        this.seekTo(duration * percent);
    }
    
    /**
     * Update playback
     */
    update(deltaTime) {
        if (!this.isPlaying || this.isPaused || !this.currentReplay) return null;
        
        // Advance playback time
        this.playbackTime += deltaTime * this.playbackSpeed;
        
        // Find current frame
        while (this.frameIndex < this.currentReplay.frames.length - 1 &&
               this.currentReplay.frames[this.frameIndex + 1].t <= this.playbackTime) {
            this.frameIndex++;
        }
        
        // Check if playback complete
        if (this.frameIndex >= this.currentReplay.frames.length - 1) {
            this.stopPlayback();
            if (this.scene) {
                this.scene.events.emit('replayComplete');
            }
            return null;
        }
        
        // Get current and next frames
        const currentFrame = this.currentReplay.frames[this.frameIndex];
        const nextFrame = this.currentReplay.frames[this.frameIndex + 1];
        
        // Interpolate between frames
        const frameTime = nextFrame.t - currentFrame.t;
        const t = frameTime > 0 ? (this.playbackTime - currentFrame.t) / frameTime : 0;
        
        return this.interpolateFrames(currentFrame, nextFrame, t);
    }
    
    /**
     * Interpolate between two frames
     */
    interpolateFrames(frame1, frame2, t) {
        return {
            time: MathUtils.lerp(frame1.t, frame2.t, t),
            
            player: {
                x: MathUtils.lerp(frame1.p.x, frame2.p.x, t),
                y: MathUtils.lerp(frame1.p.y, frame2.p.y, t),
                rotation: MathUtils.lerp(frame1.p.r, frame2.p.r, t),
                speed: MathUtils.lerp(frame1.p.s, frame2.p.s, t),
                isBoosting: frame2.p.b === 1,
                isInvincible: frame2.p.i === 1,
                isGhost: frame2.p.g === 1,
                nitro: MathUtils.lerp(frame1.p.n, frame2.p.n, t),
            },
            
            camera: {
                z: MathUtils.lerp(frame1.c.z, frame2.c.z, t),
                rotation: MathUtils.lerp(frame1.c.r, frame2.c.r, t),
            },
            
            score: {
                score: frame2.sc.s,
                multiplier: frame2.sc.m,
                combo: frame2.sc.cb,
            },
            
            events: frame2.e || [],
        };
    }
    
    /**
     * Get playback progress (0-1)
     */
    getPlaybackProgress() {
        if (!this.currentReplay) return 0;
        return this.playbackTime / this.currentReplay.metadata.duration;
    }
    
    /**
     * Get current frame info
     */
    getCurrentFrameInfo() {
        if (!this.currentReplay) return null;
        
        return {
            currentFrame: this.frameIndex,
            totalFrames: this.currentReplay.frames.length,
            currentTime: this.playbackTime,
            totalTime: this.currentReplay.metadata.duration,
            progress: this.getPlaybackProgress(),
            isPaused: this.isPaused,
            speed: this.playbackSpeed,
        };
    }
    
    /**
     * Get list of saved replays
     */
    getSavedReplays() {
        return this.savedReplays.map(r => ({
            id: r.metadata.id,
            name: r.metadata.name,
            levelId: r.metadata.levelId,
            vehicleId: r.metadata.vehicleId,
            timestamp: r.metadata.timestamp,
            duration: r.metadata.duration,
            frameCount: r.metadata.frameCount,
            finalScore: r.metadata.finalScore,
            completed: r.metadata.completed,
            stars: r.metadata.stars,
        }));
    }
    
    /**
     * Delete a saved replay
     */
    deleteReplay(replayId) {
        const index = this.savedReplays.findIndex(r => r.metadata.id === replayId);
        if (index >= 0) {
            this.savedReplays.splice(index, 1);
            this.persistReplays();
            return true;
        }
        return false;
    }
    
    /**
     * Load saved replays from storage
     */
    loadSavedReplays() {
        try {
            const data = localStorage.getItem('gravshift_replays');
            if (data) {
                this.savedReplays = JSON.parse(data);
            }
        } catch (e) {
            console.warn('Could not load replays');
            this.savedReplays = [];
        }
    }
    
    /**
     * Save replays to storage
     */
    persistReplays() {
        try {
            // Only save metadata + compressed frames
            localStorage.setItem('gravshift_replays', JSON.stringify(this.savedReplays));
        } catch (e) {
            console.warn('Could not save replays - storage full?');
            // Try to remove oldest replay
            if (this.savedReplays.length > 1) {
                this.savedReplays.pop();
                this.persistReplays();
            }
        }
    }
    
    /**
     * Export replay to shareable format
     */
    exportReplay(replayId) {
        const replay = this.savedReplays.find(r => r.metadata.id === replayId);
        if (!replay) return null;
        
        return btoa(JSON.stringify(replay));
    }
    
    /**
     * Import replay from shareable format
     */
    importReplay(data) {
        try {
            const replay = JSON.parse(atob(data));
            
            // Validate
            if (!replay.metadata || !replay.frames) {
                console.error('Invalid replay data');
                return false;
            }
            
            // Generate new ID
            replay.metadata.id = Date.now().toString(36) + Math.random().toString(36).substr(2);
            replay.metadata.name = 'Imported: ' + (replay.metadata.name || 'Unknown');
            
            // Add to saved
            this.savedReplays.unshift(replay);
            
            // Limit
            if (this.savedReplays.length > this.maxSavedReplays) {
                this.savedReplays.pop();
            }
            
            this.persistReplays();
            return true;
        } catch (e) {
            console.error('Failed to import replay:', e);
            return false;
        }
    }
    
    /**
     * Get storage usage info
     */
    getStorageInfo() {
        const data = localStorage.getItem('gravshift_replays') || '';
        return {
            replayCount: this.savedReplays.length,
            storageUsed: data.length,
            storageUsedKB: Math.round(data.length / 1024 * 10) / 10,
        };
    }
    
    /**
     * Clear all saved replays
     */
    clearAllReplays() {
        this.savedReplays = [];
        this.persistReplays();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.ReplayManager = ReplayManager;
}
