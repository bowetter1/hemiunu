/**
 * GRAVSHIFT - Score Manager
 * Handles scoring, combos, multipliers, and highscores
 */

class ScoreManager {
    constructor(scene) {
        this.scene = scene;
        this.reset();
        this.loadHighscores();
    }
    
    reset() {
        this.score = 0;
        this.displayScore = 0;
        this.combo = 0;
        this.maxCombo = 0;
        this.multiplier = 1;
        this.comboTimer = 0;
        this.lastScoreTime = 0;
        this.distanceTraveled = 0;
        this.obstaclesDestroyed = 0;
        this.powerupsCollected = 0;
        this.nearMisses = 0;
        this.driftTime = 0;
        this.perfectLaps = 0;
        this.noHitRun = true;
        this.bonusQueue = [];
    }
    
    loadHighscores() {
        try {
            const data = localStorage.getItem(GAME_CONFIG.STORAGE.HIGHSCORE);
            this.highscores = data ? JSON.parse(data) : {};
        } catch (e) {
            this.highscores = {};
        }
    }
    
    saveHighscores() {
        try {
            localStorage.setItem(GAME_CONFIG.STORAGE.HIGHSCORE, JSON.stringify(this.highscores));
        } catch (e) {
            console.warn('Could not save highscores');
        }
    }
    
    getHighscore(levelId) {
        return this.highscores[levelId] || 0;
    }
    
    isNewHighscore(levelId) {
        return this.score > this.getHighscore(levelId);
    }
    
    updateHighscore(levelId) {
        if (this.isNewHighscore(levelId)) {
            this.highscores[levelId] = this.score;
            this.saveHighscores();
            return true;
        }
        return false;
    }
    
    /**
     * Add points to score
     */
    addScore(points, source = 'default') {
        const multipliedPoints = Math.floor(points * this.multiplier);
        this.score += multipliedPoints;
        this.lastScoreTime = Date.now();
        
        // Trigger visual feedback
        if (this.scene.events) {
            this.scene.events.emit('scoreAdded', {
                points: multipliedPoints,
                total: this.score,
                source: source,
                multiplier: this.multiplier,
            });
        }
        
        return multipliedPoints;
    }
    
    /**
     * Add bonus points with popup
     */
    addBonus(points, reason) {
        this.bonusQueue.push({ points, reason, time: Date.now() });
        return this.addScore(points, reason);
    }
    
    /**
     * Increment combo
     */
    incrementCombo() {
        this.combo++;
        this.comboTimer = GAME_CONFIG.SCORE.COMBO_DECAY_TIME;
        
        if (this.combo > this.maxCombo) {
            this.maxCombo = this.combo;
        }
        
        // Update multiplier based on combo
        this.multiplier = Math.min(
            1 + Math.floor(this.combo / 5) * 0.5,
            GAME_CONFIG.SCORE.COMBO_MULTIPLIER_MAX
        );
        
        if (this.scene.events) {
            this.scene.events.emit('comboChanged', {
                combo: this.combo,
                multiplier: this.multiplier,
            });
        }
    }
    
    /**
     * Break combo
     */
    breakCombo() {
        if (this.combo > 0) {
            const lostCombo = this.combo;
            this.combo = 0;
            this.multiplier = 1;
            
            if (this.scene.events) {
                this.scene.events.emit('comboBroken', { lostCombo });
            }
        }
    }
    
    /**
     * Record a hit (breaks no-hit run)
     */
    recordHit() {
        this.noHitRun = false;
        this.breakCombo();
    }
    
    /**
     * Record distance traveled
     */
    addDistance(distance) {
        this.distanceTraveled += distance;
        const points = Math.floor(distance * GAME_CONFIG.SCORE.DISTANCE_MULTIPLIER);
        if (points > 0) {
            this.addScore(points, 'distance');
        }
    }
    
    /**
     * Record near miss
     */
    recordNearMiss() {
        this.nearMisses++;
        this.incrementCombo();
        this.addBonus(GAME_CONFIG.SCORE.NEAR_MISS_BONUS, 'Near Miss!');
    }
    
    /**
     * Record drift
     */
    addDriftTime(deltaTime) {
        this.driftTime += deltaTime;
        // Award bonus every second of drifting
        if (Math.floor(this.driftTime / 1000) > Math.floor((this.driftTime - deltaTime) / 1000)) {
            this.addBonus(GAME_CONFIG.SCORE.DRIFT_BONUS, 'Drift!');
            this.incrementCombo();
        }
    }
    
    /**
     * Record checkpoint
     */
    recordCheckpoint() {
        this.addBonus(GAME_CONFIG.SCORE.CHECKPOINT_BONUS, 'Checkpoint!');
        this.incrementCombo();
    }
    
    /**
     * Record perfect lap
     */
    recordPerfectLap() {
        this.perfectLaps++;
        this.addBonus(GAME_CONFIG.SCORE.PERFECT_LAP_BONUS, 'Perfect Lap!');
    }
    
    /**
     * Record obstacle destroyed
     */
    recordObstacleDestroyed() {
        this.obstaclesDestroyed++;
        this.addScore(75, 'destroy');
        this.incrementCombo();
    }
    
    /**
     * Record powerup collected
     */
    recordPowerup() {
        this.powerupsCollected++;
        this.addScore(50, 'powerup');
        this.incrementCombo();
    }
    
    /**
     * Update combo decay
     */
    update(deltaTime) {
        // Decay combo timer
        if (this.combo > 0 && this.comboTimer > 0) {
            this.comboTimer -= deltaTime;
            if (this.comboTimer <= 0) {
                this.breakCombo();
            }
        }
        
        // Smooth display score animation
        if (this.displayScore < this.score) {
            const diff = this.score - this.displayScore;
            const increment = Math.max(1, Math.floor(diff * 0.1));
            this.displayScore = Math.min(this.displayScore + increment, this.score);
        }
        
        // Process bonus queue
        if (this.bonusQueue.length > 0) {
            const now = Date.now();
            this.bonusQueue = this.bonusQueue.filter(b => now - b.time < 2000);
        }
    }
    
    /**
     * Get combo time remaining (0-1)
     */
    getComboTimeRatio() {
        if (this.combo === 0) return 0;
        return this.comboTimer / GAME_CONFIG.SCORE.COMBO_DECAY_TIME;
    }
    
    /**
     * Get run statistics
     */
    getStats() {
        return {
            score: this.score,
            maxCombo: this.maxCombo,
            distance: Math.floor(this.distanceTraveled),
            obstaclesDestroyed: this.obstaclesDestroyed,
            powerupsCollected: this.powerupsCollected,
            nearMisses: this.nearMisses,
            driftTime: Math.floor(this.driftTime / 1000),
            perfectLaps: this.perfectLaps,
            noHitRun: this.noHitRun,
        };
    }
    
    /**
     * Calculate star rating
     */
    calculateStars(levelConfig) {
        if (!levelConfig || !levelConfig.stars) return 0;
        
        const { one, two, three } = levelConfig.stars;
        
        // Check three-star requirements
        if (this.score >= three.score) {
            if (three.noHits && !this.noHitRun) return 2;
            if (three.time && this.scene.gameTime > three.time) return 2;
            if (three.perfectRun && !this.noHitRun) return 2;
            return 3;
        }
        
        // Check two-star
        if (this.score >= two.score) return 2;
        
        // Check one-star
        if (this.score >= one.score) return 1;
        
        return 0;
    }
}

// Export
if (typeof window !== 'undefined') {
    window.ScoreManager = ScoreManager;
}
